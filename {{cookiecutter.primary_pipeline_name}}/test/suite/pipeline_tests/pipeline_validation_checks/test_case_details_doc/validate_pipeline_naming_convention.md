# Validate Pipeline Naming Convention — Complete Reference

## Purpose

Every SnapLogic pipeline must follow naming conventions so that teams can identify which project a pipeline belongs to and whether it's a parent or child pipeline. This validation enforces those rules automatically by inspecting the pipeline name from the `.slp` file.

---

## The Problem

Without naming conventions, pipelines become unmanageable at scale:

```
❌ BAD (no naming convention — which project does each belong to?)

├── acquisition_pipeline
├── data_load
├── enrichment
├── daily_export
├── child_1
└── transform_data
```

```
✅ GOOD (naming convention — instantly know project and hierarchy)

├── greenlight_acquisition            ← parent, greenlight project (contains project name)
├── greenlight_data_load              ← parent, greenlight project (contains project name)
├── z_greenlight_enrichment           ← child, greenlight project (starts with z_)
├── rebate_daily_export               ← parent, rebate project (contains project name)
├── z_rebate_child_transform          ← child, rebate project (starts with z_)
└── rebate_validation                 ← parent, rebate project (contains project name)
```

---

## Peer Review Requirements

From the peer review form:

> *"Pipelines need to include name of project (Ex. z_greenlight_acquisition)"*
>
> *"Child pipeline — Need to start with z_"*

---

## The 3 Checks

`Validate Pipeline Naming Convention` runs **3 independent checks** on every pipeline. All 3 run regardless of each other — there is no early exit. A pipeline can fail multiple checks simultaneously.

```
For each pipeline:
│
├── Check 1: Is the pipeline name empty?
│   └── YES → FAIL
│
├── Check 2: Does the name contain the project name?
│   └── NO → FAIL (only if project_name is configured)
│
├── Check 3: Does the child pipeline start with z_?
│   └── NO → FAIL (only if is_child_pipeline is True)
│
└── All checks passed → ✅ PASS
```

**Important:** These are 3 independent `if` statements — NOT `if/elif/else`. Every check runs every time (when its condition applies).

---

## Check 1: Empty Name

**What it catches:** Pipelines with no name or a blank name.

**Logic:**
```python
if not name:
    violations.append("Pipeline name is empty")
```

**How the name is extracted:**
```python
# From the .slp JSON file:
{
    "property_map": {
        "info": {
            "label": {
                "value": "z_greenlight_acquisition"   ← this is the pipeline name
            }
        }
    }
}
```

**Examples:**

| Pipeline Name | Result | Reason |
|---------------|--------|--------|
| `""` (blank) | ❌ FAIL | Pipeline name is empty |
| `"z_greenlight_acquisition"` | — | Passes to Check 2 |

**Why it matters:** A pipeline without a name cannot be identified in the SnapLogic Manager, logs, or error messages. It's the most basic requirement.

---

## Check 2: Contains Project Name

**What it catches:** Pipelines that don't include the project name anywhere in their name.

**Logic:**
```python
if project_name and project_name not in name:
    violations.append(
        f"Pipeline name '{name}' does not contain required project name '{project_name}'"
    )
```

**Key behavior:** Uses `in` (contains) — NOT `startswith`. The project name can appear **anywhere** in the pipeline name.

**Examples with `project_name="z_greenlight"`:**

| Pipeline Name | Contains `z_greenlight`? | Result |
|---------------|:---:|--------|
| `z_greenlight_acquisition` | Yes (at start) | ✅ PASS |
| `acquisition_z_greenlight` | Yes (at end) | ✅ PASS |
| `my_z_greenlight_pipeline` | Yes (in middle) | ✅ PASS |
| `z_greenlight` | Yes (exact match) | ✅ PASS |
| `oracle_test` | No | ❌ FAIL |
| `greenlight_acquisition` | No (`z_greenlight` ≠ `greenlight`) | ❌ FAIL |
| `Z_GREENLIGHT_acquisition` | No (case-sensitive) | ❌ FAIL |

**When this check is skipped:**

| `project_name` | Behavior |
|-----------------|----------|
| `""` (empty — default) | Check skipped entirely — always passes |
| `"z_greenlight"` | Check runs — name must contain `z_greenlight` |
| `"z_rebate"` | Check runs — name must contain `z_rebate` |

**Why it matters:** When an organization has dozens of projects with hundreds of pipelines, the project name in the pipeline name is the primary way to identify ownership and group related pipelines together.

---

## Check 3: Child Pipeline z_ Prefix

**What it catches:** Child pipelines that don't start with `z_`.

**Logic:**
```python
if is_child_pipeline and not name.startswith('z_'):
    violations.append(
        f"Child pipeline name '{name}' must start with 'z_'"
    )
```

**Key behavior:** Uses `startswith` — the `z_` must be at the **beginning** of the name.

**Examples with `is_child_pipeline=True`:**

| Pipeline Name | Starts with `z_`? | Result |
|---------------|:---:|--------|
| `z_enrichment_child` | Yes | ✅ PASS |
| `z_greenlight_transform` | Yes | ✅ PASS |
| `z_` | Yes (technically) | ✅ PASS |
| `enrichment_child` | No | ❌ FAIL |
| `child_enrichment` | No (starts with `child_`, not `z_`) | ❌ FAIL |
| `Z_enrichment` | No (uppercase `Z`, case-sensitive) | ❌ FAIL |

**When this check is skipped:**

| `is_child_pipeline` | Behavior |
|----------------------|----------|
| `False` (default) | Check skipped — always passes |
| `True` | Check runs — name must start with `z_` |

**Why it matters:** The `z_` prefix is the team's convention to visually distinguish child pipelines from parent pipelines in the SnapLogic Manager. It also makes sorting and filtering easier.

---

## All Checks Are Independent

A single pipeline can fail **multiple checks at once**. Here's every possible combination:

### Parent Pipeline Scenarios (`is_child_pipeline=False`)

Check 3 is always skipped for parent pipelines.

| Pipeline Name | `project_name` | Check 1 | Check 2 | Check 3 | Violations |
|---|---|:---:|:---:|:---:|---|
| `z_greenlight_acq` | `z_greenlight` | ✅ | ✅ | skip | 0 |
| `oracle_test` | `z_greenlight` | ✅ | ❌ | skip | 1: missing project name |
| `oracle_test` | `""` | ✅ | skip | skip | 0 |
| `""` | `z_greenlight` | ❌ | ❌ | skip | 2: empty + missing project name |
| `""` | `""` | ❌ | skip | skip | 1: empty |

### Child Pipeline Scenarios (`is_child_pipeline=True`)

All 3 checks can run for child pipelines.

| Pipeline Name | `project_name` | Check 1 | Check 2 | Check 3 | Violations |
|---|---|:---:|:---:|:---:|---|
| `z_greenlight_child` | `z_greenlight` | ✅ | ✅ | ✅ | 0 |
| `z_other_child` | `z_greenlight` | ✅ | ❌ | ✅ | 1: missing project name |
| `greenlight_child` | `z_greenlight` | ✅ | ✅ | ❌ | 1: no z_ prefix |
| `random_child` | `z_greenlight` | ✅ | ❌ | ❌ | 2: missing project name + no z_ prefix |
| `z_greenlight_child` | `""` | ✅ | skip | ✅ | 0 |
| `random_child` | `""` | ✅ | skip | ❌ | 1: no z_ prefix |
| `""` | `z_greenlight` | ❌ | ❌ | ❌ | 3: empty + missing project name + no z_ prefix |
| `""` | `""` | ❌ | skip | ❌ | 2: empty + no z_ prefix |

---

## Flow Through the Framework

### Test Cases (peer_review_tests.robot)

There are **two separate test cases** that use this validation:

**Test Case 1: General Pipeline Naming**
```robot
Verify Pipeline Naming Convention
    [Tags]    peer_review    pipeline_naming    static_analysis
    ${result}=    Verify Pipeline Naming And Return Result
    ...    ${pipeline}
    ...    project_name=${project_name}
    Should Be Equal    ${result}[status]    PASS
    ...    msg=Pipeline naming violations: ${result}[violations]
```

**Test Case 2: Child Pipeline z_ Prefix**
```robot
Verify Child Pipeline Naming Convention
    [Tags]    peer_review    pipeline_naming    child_pipeline    static_analysis
    Skip If    '${is_child_pipeline}' == 'False'    Not a child pipeline — skipping z_ prefix check.
    ${result}=    Verify Child Pipeline Naming And Return Result    ${pipeline}
    Should Be Equal    ${result}[status]    PASS
    ...    msg=Child pipeline must start with z_ prefix. Pipeline name: ${result}[pipeline_name]
```

### Resource Keyword (pipeline_inspector.resource)

```robot
Verify Pipeline Naming And Return Result
    [Arguments]    ${pipeline}    ${project_name}=    ${is_child_pipeline}=False
    ${result}=    Validate Pipeline Naming Convention
    ...    ${pipeline}
    ...    project_name=${project_name}
    ...    is_child_pipeline=${is_child_pipeline}
    IF    ${result}[total_violations] > 0
        Log    Pipeline name: ${result}[pipeline_name]    WARN
        FOR    ${violation}    IN    @{result}[violations]
            Log    Violation: ${violation}    WARN
        END
    END
    RETURN    ${result}
```

The resource keyword:
1. Calls the Python method
2. If violations found → logs pipeline name and each violation as WARNING
3. Returns the result dict (does NOT assert pass/fail — that's the test case's job)

### Python Engine (PipelineInspectorLibrary.py)

```python
def validate_pipeline_naming_convention(self, pipeline, project_name='', is_child_pipeline=False):
    name = self.get_pipeline_name(pipeline)
    violations = []

    if not name:                                          # Check 1
        violations.append("Pipeline name is empty")

    if project_name and project_name not in name:         # Check 2
        violations.append(f"does not contain required project name '{project_name}'")

    if is_child_pipeline and not name.startswith('z_'):   # Check 3
        violations.append(f"must start with 'z_'")

    status = 'PASS' if not violations else 'FAIL'
    return {'status': status, 'pipeline_name': name, 'violations': violations, 'total_violations': len(violations)}
```

### Visual Flow

```
peer_review_tests.robot
│
├── Verify Pipeline Naming Convention (test case)
│   │
│   └── Calls: Verify Pipeline Naming And Return Result (resource keyword)
│              │
│              ├── Calls: Validate Pipeline Naming Convention (Python)
│              │   ├── Check 1: name is empty?
│              │   ├── Check 2: name contains project_name?
│              │   └── Check 3: child starts with z_?
│              │
│              ├── IF violations > 0:
│              │   ├── Log pipeline name (WARN)
│              │   └── Log each violation (WARN)
│              │
│              └── RETURN result
│
│   └── Should Be Equal ${result}[status] PASS
│
├── Verify Child Pipeline Naming Convention (test case)
│   │
│   ├── Skip If is_child_pipeline == False
│   │
│   └── Calls: Verify Child Pipeline Naming And Return Result (resource keyword)
│              │
│              ├── Get Pipeline Name
│              ├── Check: starts with z_?
│              ├── IF FAIL → Log warning
│              └── RETURN {status, pipeline_name}
│
│   └── Should Be Equal ${result}[status] PASS
```

---

## In Batch Review

The batch review auto-detects child vs parent per file:

```python
${is_child}=    Evaluate    '${entry}[file_name]'.startswith('z_') or '${entry}[file_name]'.startswith('child_')
```

| File Name | `is_child` | Check 2 (project name) | Check 3 (z_ prefix) |
|---|---|---|---|
| `oracle2.slp` | False | Runs if configured | Skipped |
| `z_greenlight.slp` | True | Runs if configured | Enforced |
| `child_pipeline1.slp` | True | Runs if configured | Enforced |
| `snowflake.slp` | False | Runs if configured | Skipped |

In the batch report:

```
[PASS] Pipeline Naming
[SKIP] Child Pipeline Naming - Not a child pipeline — z_ prefix check skipped
```

or for child pipelines:

```
[PASS] Pipeline Naming
[PASS] Child Pipeline Naming
```

or if failing:

```
[FAIL] Pipeline Naming - Pipeline name 'oracle_test' does not contain required project name 'z_greenlight'
[FAIL] Child Pipeline Naming - Child pipeline 'oracle_test' must start with 'z_'
```

---

## Report Output

### Console (during execution)

When violations exist:
```
WARN: Pipeline name: oracle_test
WARN: Violation: Pipeline name 'oracle_test' does not contain required project name 'z_greenlight'
```

### HTML Log (log-*.html)

The detailed log shows each violation with WARNING level, making them easy to spot in the yellow-highlighted log entries.

### Failure Message (in report-*.html)

```
FAIL: Pipeline naming violations: ["Pipeline name 'oracle_test' does not contain required project name 'z_greenlight'"]
```

---

## How to Run

### Run Pipeline Naming Checks Only

```bash
make robot-run-tests TAGS="pipeline_naming"
```

This runs both test cases:
- Verify Pipeline Naming Convention
- Verify Child Pipeline Naming Convention

### Run Child Pipeline Check Only

```bash
make robot-run-tests TAGS="child_pipeline"
```

### Override Variables

```bash
# Set project name to check for
make robot-run-tests TAGS="pipeline_naming" EXTRA_ARGS="--variable project_name:z_greenlight"

# Mark as child pipeline
make robot-run-tests TAGS="pipeline_naming" EXTRA_ARGS="--variable is_child_pipeline:True"

# Both
make robot-run-tests TAGS="pipeline_naming" EXTRA_ARGS="--variable project_name:z_greenlight --variable is_child_pipeline:True"

# Specify a different pipeline file
make robot-run-tests TAGS="pipeline_naming" EXTRA_ARGS="--variable pipeline_file:/app/src/pipelines/z_greenlight_child.slp --variable is_child_pipeline:True --variable project_name:z_greenlight"
```

---

## Return Value Structure

```python
# All checks pass
{
    "status": "PASS",
    "pipeline_name": "z_greenlight_acquisition",
    "violations": [],
    "total_violations": 0
}

# One check fails
{
    "status": "FAIL",
    "pipeline_name": "oracle_test",
    "violations": [
        "Pipeline name 'oracle_test' does not contain required project name 'z_greenlight'"
    ],
    "total_violations": 1
}

# Multiple checks fail (child pipeline, empty name)
{
    "status": "FAIL",
    "pipeline_name": "",
    "violations": [
        "Pipeline name is empty",
        "Pipeline name '' does not contain required project name 'z_greenlight'",
        "Child pipeline name '' must start with 'z_'"
    ],
    "total_violations": 3
}
```

---

## Configurable Variables

| Variable | Default | Purpose | Where Set |
|----------|---------|---------|-----------|
| `${project_name}` | `${EMPTY}` | Project name that must appear in pipeline name | `peer_review_tests.robot` or command line |
| `${is_child_pipeline}` | `False` | Whether to enforce z_ prefix | `peer_review_tests.robot` or command line |

When `project_name` is empty (default), Check 2 is skipped — the pipeline name can be anything.
When `is_child_pipeline` is False (default), Check 3 is skipped — no z_ prefix requirement.

---

## Summary

| Check | What It Validates | When It Runs | Operator |
|-------|-------------------|--------------|----------|
| **1. Empty Name** | Pipeline has a name | Always | `not name` |
| **2. Contains Project Name** | Name includes the project identifier | Only when `project_name` is configured | `project_name not in name` |
| **3. Child z_ Prefix** | Child pipeline starts with `z_` | Only when `is_child_pipeline=True` | `not name.startswith('z_')` |

All 3 checks run independently. A pipeline can fail 0, 1, 2, or all 3 checks in a single run.
