# Validate Parameters Follow Naming Convention (xx Prefix) — Complete Reference

## Purpose

Ensures every pipeline parameter name starts with the `xx` prefix. This is a defensive pattern called **"Poisoning Pipeline Inputs"** — it guarantees that parameter values are explicitly passed when child pipelines are called, rather than silently inheriting incorrect values from the environment.

---

## The Problem

SnapLogic pipeline parameters can accidentally inherit values from the calling environment. Without the `xx` prefix, a parameter named `schema_name` in a child pipeline could pick up a `schema_name` value from the parent — even if the parent meant to pass a different value.

### How the "Poisoning" Pattern Works

```
❌ WITHOUT xx prefix — silent value inheritance

Parent Pipeline
├── Parameter: schema_name = "HR_SCHEMA"
│
└── Pipeline Execute → Child Pipeline
    └── Parameter: schema_name = ???
        The child might inherit "HR_SCHEMA" from the parent
        even if the parent didn't explicitly pass it.
        This is the WRONG schema for this child.
```

```
✅ WITH xx prefix — forces explicit passing

Parent Pipeline
├── Parameter: schema_name = "HR_SCHEMA"
│
└── Pipeline Execute → Child Pipeline
    └── Parameter: xx_schema_name = ???
        "xx_schema_name" does NOT exist in the parent,
        so it can NEVER be inherited by accident.
        The parent MUST explicitly map schema_name → xx_schema_name.
        If it forgets, the value is empty — an obvious error.
```

The `xx` prefix "poisons" the parameter name so it cannot accidentally match any real environment variable or parent parameter. If the value isn't explicitly passed, it's empty — which causes an obvious, immediate failure rather than a silent, hard-to-debug data corruption.

---

## Peer Review Requirement

From the peer review form:

> *"Make all parameters prefixed with xx to ensure variables are being passed through the pipeline correctly. With the exception of top layer pipelines. See Poisoning Pipeline Inputs with xx."*

---

## The 2 Checks

### Check 1: Is This a Parent/Top-Layer Pipeline? → SKIP

```python
if is_parent_pipeline:
    return {'status': 'SKIP', 'message': 'Top-layer pipelines are exempt...'}
```

Parent/top-layer pipelines are **exempt** from this requirement because:
- They receive inputs directly from the user or a triggered task
- There is no "parent" to accidentally inherit values from
- Their parameters use natural, descriptive names (e.g., `schema_name`, `table_name`)

| `is_parent_pipeline` | Result |
|:---:|---|
| `True` | **SKIP** — check not performed, not counted as pass or fail |
| `False` | Proceed to Check 2 |

### Check 2: Does Each Parameter Name Start With the Prefix?

```python
for param in params:
    name = param['name']
    if name and not name.startswith(prefix):
        violations.append(...)
```

| Parameter Name | `prefix` | `startswith('xx')` | Result |
|---|---|:---:|---|
| `xx_schema_name` | `xx` | Yes | ✅ PASS |
| `xx_table_name` | `xx` | Yes | ✅ PASS |
| `xx_oracle_acct` | `xx` | Yes | ✅ PASS |
| `schema_name` | `xx` | No | ❌ FAIL |
| `table_name` | `xx` | No | ❌ FAIL |
| `USER` | `xx` | No | ❌ FAIL |
| `""` (empty name) | `xx` | Skipped | ✅ PASS (empty names are ignored) |

**Note:** The prefix check is **case-sensitive**. `xx_schema` passes, but `XX_schema` does not. The default prefix is `xx` but it's configurable.

---

## Complete Validation Flow

```
                    Load Pipeline (.slp file)
                              │
                              ▼
                ┌──────────────────────────┐
                │  is_parent_pipeline?      │
                │                          │
                ├── True                   │
                │   └── Return SKIP        │
                │       "Top-layer exempt" │
                │                          │
                └── False                  │
                    │                      │
                    ▼                      │
          ┌─────────────────────┐          │
          │  Get Pipeline       │          │
          │  Parameters         │          │
          │                     │          │
          │  Extract param_table│          │
          │  from .slp JSON     │          │
          └─────────┬───────────┘          │
                    │                      │
                    ▼                      │
          ┌─────────────────────┐          │
          │  For each parameter  │          │
          └─────────┬───────────┘          │
                    │                      │
            ┌───────┴───────┐              │
            ▼               ▼              │
     name is empty   name has value        │
         │               │                 │
         ▼               ▼                 │
      (skip it)   starts with 'xx'?        │
                    │          │            │
                    ▼          ▼            │
                  Yes         No           │
                   │           │            │
                   ▼           ▼            │
               (skip)    Add violation:    │
                         "Parameter 'X'    │
                          does not start   │
                          with 'xx'"       │
                                           │
                    ┌──────────────────────┘
                    ▼
          ┌─────────────────────┐
          │  All params checked  │
          │                     │
          │  violations empty?  │
          │  YES → PASS         │
          │  NO  → FAIL         │
          └─────────────────────┘
```

---

## Where Parameters Live in the .slp File

```json
{
    "property_map": {
        "settings": {
            "param_table": {
                "value": [
                    {
                        "key": {"value": "schema_name"},     ← THIS IS THE NAME WE CHECK
                        "value": {"value": "HR_SCHEMA"},
                        "capture": {"value": true},
                        "required": {"value": false},
                        "data_type": {"value": "string"},
                        "description": {"value": null}
                    }
                ]
            }
        }
    }
}
```

The check reads `key.value` for each parameter and checks if it starts with the configured prefix.

---

## Return Value Structure

### When Check Runs (child pipeline)

```python
{
    "status": "FAIL",
    "violations": [
        {
            "parameter_name": "schema_name",
            "expected_prefix": "xx",
            "reason": "Parameter 'schema_name' does not start with 'xx'"
        },
        {
            "parameter_name": "oracle_acct",
            "expected_prefix": "xx",
            "reason": "Parameter 'oracle_acct' does not start with 'xx'"
        }
    ],
    "total_params": 5,
    "total_violations": 2
}
```

### When Check Is Skipped (parent pipeline)

```python
{
    "status": "SKIP",
    "violations": [],
    "total_params": 0,
    "total_violations": 0,
    "message": "Top-layer pipelines are exempt from parameter prefix requirement"
}
```

| Field | Description |
|---|---|
| `status` | `"PASS"`, `"FAIL"`, or `"SKIP"` |
| `violations` | List of parameters that failed the prefix check |
| `total_params` | Number of parameters checked (0 if skipped) |
| `total_violations` | Number of parameters without the prefix |
| `message` | Present only when status is SKIP |

---

## Code Architecture — 3 Layers

### Layer 1: Test Case (peer_review_tests.robot)

```robot
Verify Parameters Follow Naming Convention
    [Documentation]    Validates that all parameters are prefixed with '${param_prefix}'.
    ...    Top-layer pipelines are exempt from this requirement.
    ...    See: "Poisoning Pipeline Inputs with xx"
    [Tags]    peer_review    parameters    static_analysis
    Pipeline Parameters Should Have Prefix    ${pipeline}    prefix=${param_prefix}    is_parent_pipeline=${is_parent_pipeline}
```

**What it does:** Calls the resource keyword with the configured prefix and parent flag. One line.

### Layer 2: Resource Keyword (pipeline_inspector.resource)

```robot
Pipeline Parameters Should Have Prefix
    [Arguments]    ${pipeline}    ${prefix}=xx    ${is_parent_pipeline}=False
    ${result}=    Validate Parameters Have Prefix    ${pipeline}    prefix=${prefix}    is_parent_pipeline=${is_parent_pipeline}
    IF    '${result}[status]' != 'SKIP'
        Should Be Equal    ${result}[status]    PASS
        ...    msg=Parameters without '${prefix}' prefix: ${result}[violations]
    END
```

**What it does:** Calls the Python library. If the result is SKIP (parent pipeline), it does NOT assert — the test passes silently. If the result is PASS or FAIL, it asserts PASS.

### Layer 3: Python Library (PipelineInspectorLibrary.py)

```python
def validate_parameters_have_prefix(self, pipeline, prefix='xx', is_parent_pipeline=False):
    # Check 1: Skip for parent pipelines
    if is_parent_pipeline:
        return {'status': 'SKIP', ...}

    # Check 2: Verify each parameter name starts with prefix
    params = self.get_pipeline_parameters(pipeline)
    violations = []
    for param in params:
        name = param['name']
        if name and not name.startswith(prefix):
            violations.append({
                'parameter_name': name,
                'expected_prefix': prefix,
                'reason': f"Parameter '{name}' does not start with '{prefix}'"
            })

    status = 'PASS' if not violations else 'FAIL'
    return {'status': status, 'violations': violations, ...}
```

---

## Real Examples From Your Pipelines

### oracle2.slp (Child Pipeline) — FAIL ❌

```
is_parent_pipeline: False
prefix: xx

Parameter                  Starts with xx?    Result
──────────────────────────────────────────────────────
expression_library         No                 ❌ FAIL
schema_name                No                 ❌ FAIL
table_name                 No                 ❌ FAIL
actual_output              No                 ❌ FAIL
oracle_acct                No                 ❌ FAIL

Total: 5 params | 5 violations | Status: FAIL
```

### sqlserver.slp (Child Pipeline) — FAIL ❌

```
is_parent_pipeline: False
prefix: xx

Parameter                  Starts with xx?    Result
──────────────────────────────────────────────────────
USER                       No                 ❌ FAIL
NAME_CD_1                  No                 ❌ FAIL
NAME_CD_2                  No                 ❌ FAIL
DOMAIN_NAME                No                 ❌ FAIL
M_CURR_DATE                No                 ❌ FAIL
SQLServer_Slim_Account     No                 ❌ FAIL

Total: 6 params | 6 violations | Status: FAIL
```

### parent_pipeline1.slp (Parent Pipeline) — SKIP ⏭️

```
is_parent_pipeline: True

Status: SKIP
Message: "Top-layer pipelines are exempt from parameter prefix requirement"
```

### Hypothetical Correct Child — PASS ✅

```
is_parent_pipeline: False
prefix: xx

Parameter                  Starts with xx?    Result
──────────────────────────────────────────────────────
xx_schema_name             Yes                ✅ PASS
xx_table_name              Yes                ✅ PASS
xx_oracle_acct             Yes                ✅ PASS
xx_actual_output           Yes                ✅ PASS

Total: 4 params | 0 violations | Status: PASS
```

---

## Configurable Variables

| Variable | Default | Where Set | Description |
|---|---|---|---|
| `${param_prefix}` | `xx` | `peer_review_tests.robot` Variables section | The required prefix string |
| `${is_parent_pipeline}` | `False` | `peer_review_tests.robot` Variables section or CLI | Whether to skip the check |

### Override via Command Line

```bash
# Run as parent pipeline (skip prefix check)
make robot-run-tests TAGS="peer_review" EXTRA_ARGS="--variable is_parent_pipeline:True"

# Use a different prefix
make robot-run-tests TAGS="peer_review" EXTRA_ARGS="--variable param_prefix:sl_"
```

---

## Edge Cases

### Pipeline With No Parameters

If a pipeline has zero parameters, the check **passes** — there's nothing to validate.

```python
params = []           # empty list
violations = []       # no violations possible
status = 'PASS'
total_params = 0
```

### Parameter With Empty Name

Parameters with empty names are **skipped** (not flagged):

```python
if name and not name.startswith(prefix):
#  ^^^^ empty string is falsy, so the check is skipped
```

### Custom Prefix

While the default is `xx`, the prefix is configurable. A team could use `sl_`, `prj_`, or any other prefix:

```robot
Pipeline Parameters Should Have Prefix    ${pipeline}    prefix=sl_
```

---

## How to Fix Violations

In SnapLogic Designer:

1. Open the child pipeline
2. Go to **Pipeline Properties** (gear icon)
3. Click the **Settings** tab
4. For each parameter, rename it to add the `xx` prefix:
   - `schema_name` → `xx_schema_name`
   - `table_name` → `xx_table_name`
   - `oracle_acct` → `xx_oracle_acct`
5. **Important:** Also update every reference to the renamed parameter throughout the pipeline expressions
6. **Important:** Update the parent pipeline's `Pipeline Execute` snap to map to the new parameter names
7. Save the pipeline

### Before and After

```
Before (child pipeline):
  Parameters: schema_name, table_name, oracle_acct

After (child pipeline):
  Parameters: xx_schema_name, xx_table_name, xx_oracle_acct

Parent Pipeline Execute snap mapping:
  schema_name     → xx_schema_name
  table_name      → xx_table_name
  oracle_acct     → xx_oracle_acct
```

---

## Why Top-Layer Pipelines Are Exempt

Top-layer (parent) pipelines:
- Are triggered directly by users, scheduled tasks, or API calls
- Receive inputs from external sources (not from another pipeline)
- Have no risk of accidental value inheritance from a parent pipeline
- Should use natural, descriptive parameter names for clarity

The `xx` prefix only solves the **inheritance problem**, which only exists in child pipelines.

---

## Related Documentation

| Document | Description |
|---|---|
| [Validate Parameters Have Capture Enabled](validate_parameters_have_capture_enabled.md) | Parameter capture checkbox validation |
| [Validate Pipeline Naming Auto Detection](validate_pipeline_naming_auto_detection.md) | Auto-detect parent/child (affects is_parent_pipeline) |
| [Validate Child Pipeline Naming](validate_child_pipeline_naming.md) | Child pipeline z_ prefix check |
| [Peer Review Automation](peer_review_automation.md) | Full peer review automation overview |
