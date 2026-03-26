# Validate Parameters Have Capture Enabled — Complete Reference

## Purpose

Ensures every pipeline parameter has the **"Capture" checkbox enabled** in SnapLogic Designer. When Capture is enabled, the parameter value is recorded in the pipeline execution logs, making it possible to trace what values were used during each run.

---

## The Problem

When Capture is disabled, parameter values are **invisible** in execution logs:

```
❌ Capture DISABLED — you see this in execution logs:

Pipeline: oracle2
  Parameters used: (not captured)
  Result: 7 rows inserted

  Something went wrong? Good luck figuring out which
  schema_name, table_name, or account was used.
```

```
✅ Capture ENABLED — you see this in execution logs:

Pipeline: oracle2
  Parameters:
    expression_library = ../shared/expression_lib
    schema_name        = HR_SCHEMA
    table_name         = EMPLOYEES
    actual_output      = file:///opt/snaplogic/test_data/actual/oracle/table1.csv
    oracle_acct        = ../shared/oracle_acct
  Result: 7 rows inserted

  Exact values used are visible for debugging.
```

---

## Peer Review Requirement

From the peer review form:

> *"Pipeline Properties – Settings: Make sure all inputs are captured. (The 'Capture' checkbox should be checked.)"*

---

## Where Capture Lives in the .slp File

Every pipeline parameter is stored in `property_map.settings.param_table.value` as an array of objects. Each parameter has a `capture` field:

```json
{
  "property_map": {
    "settings": {
      "param_table": {
        "value": [
          {
            "key": {"value": "schema_name"},
            "value": {"value": "HR_SCHEMA"},
            "capture": {"value": true},        ← THIS IS WHAT WE CHECK
            "required": {"value": false},
            "data_type": {"value": "string"},
            "description": {"value": null}
          },
          {
            "key": {"value": "table_name"},
            "value": {"value": "EMPLOYEES"},
            "capture": {"value": false},       ← VIOLATION — not captured
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

---

## The Check — Single Rule

This validation has **one simple check**: for every parameter, is `capture.value` set to `true`?

```python
for param in params:
    if not param['capture']:
        violations.append(...)
```

| Parameter | `capture.value` | Result |
|---|:---:|---|
| `schema_name` | `true` | ✅ PASS |
| `table_name` | `true` | ✅ PASS |
| `oracle_acct` | `false` | ❌ FAIL — "does not have Capture enabled" |

There are no exceptions, no skip conditions, no special cases. **Every parameter must have Capture enabled. Period.**

---

## Complete Validation Flow

```
                Load Pipeline (.slp file)
                          │
                          ▼
            ┌──────────────────────────┐
            │  Get Pipeline Parameters  │
            │                          │
            │  Extract param_table     │
            │  from property_map →     │
            │  settings → param_table  │
            │  → value                 │
            └────────────┬─────────────┘
                         │
                         ▼
              ┌────────────────────┐
              │  For each parameter │
              └─────────┬──────────┘
                        │
                ┌───────┴───────┐
                ▼               ▼
          capture=true    capture=false
               │               │
               ▼               ▼
            (skip)      Add to violations:
                        "Parameter 'X' does
                         not have Capture
                         enabled"
                               │
                        ┌──────┘
                        ▼
              ┌──────────────────────┐
              │  All params checked   │
              │                      │
              │  violations empty?   │
              │  YES → status: PASS  │
              │  NO  → status: FAIL  │
              └──────────────────────┘
```

---

## What Gets Extracted Per Parameter

The `Get Pipeline Parameters` method extracts 6 fields from each parameter entry:

| Field | Source in .slp JSON | Example Value |
|---|---|---|
| `name` | `key.value` | `"schema_name"` |
| `value` | `value.value` | `"HR_SCHEMA"` |
| `capture` | `capture.value` | `true` or `false` |
| `required` | `required.value` | `true` or `false` |
| `data_type` | `data_type.value` | `"string"` |
| `description` | `description.value` | `"Schema to use"` or `null` |

Only the `capture` field is checked by this validation. The other fields are extracted for reporting and potential use by other checks.

---

## Return Value Structure

```python
{
    "status": "FAIL",
    "violations": [
        {
            "parameter_name": "snowflake_acct",
            "capture_value": False,
            "reason": "Parameter 'snowflake_acct' does not have Capture enabled"
        },
        {
            "parameter_name": "actual_output",
            "capture_value": False,
            "reason": "Parameter 'actual_output' does not have Capture enabled"
        }
    ],
    "total_params": 5,
    "total_violations": 2
}
```

| Field | Description |
|---|---|
| `status` | `"PASS"` if all parameters have capture enabled, `"FAIL"` otherwise |
| `violations` | List of parameter objects that failed the check |
| `total_params` | Total number of parameters in the pipeline |
| `total_violations` | Number of parameters without capture enabled |

---

## Code Architecture — 3 Layers

### Layer 1: Test Case (peer_review_tests.robot)

```robot
Verify All Parameters Have Capture Enabled
    [Documentation]    Validates that all pipeline parameters have the "Capture" checkbox checked.
    ...    This ensures variables are being passed through the pipeline correctly.
    [Tags]    peer_review    parameters    static_analysis
    Pipeline Parameters Should Have Capture Enabled    ${pipeline}
```

**What it does:** Calls the resource keyword, which asserts PASS/FAIL. That's it — one line.

### Layer 2: Resource Keyword (pipeline_inspector.resource)

```robot
Pipeline Parameters Should Have Capture Enabled
    [Arguments]    ${pipeline}
    ${result}=    Validate Parameters Have Capture Enabled    ${pipeline}
    Should Be Equal    ${result}[status]    PASS
    ...    msg=Parameters without Capture enabled: ${result}[violations]
```

**What it does:** Calls the Python library, asserts the status is PASS. If FAIL, the violation list is included in the error message.

### Layer 3: Python Library (PipelineInspectorLibrary.py)

Two methods work together:

**`get_pipeline_parameters()`** — Extracts all parameters from the .slp JSON:
```python
def get_pipeline_parameters(self, pipeline):
    param_table = (
        pipeline.get('property_map', {}).get('settings', {})
        .get('param_table', {}).get('value', [])
    )
    params = []
    for param in param_table:
        params.append({
            'name': param.get('key', {}).get('value', ''),
            'value': param.get('value', {}).get('value', ''),
            'capture': param.get('capture', {}).get('value', False),
            'required': param.get('required', {}).get('value', False),
            'data_type': param.get('data_type', {}).get('value', ''),
            'description': param.get('description', {}).get('value', '')
        })
    return params
```

**`validate_parameters_have_capture_enabled()`** — Checks each parameter:
```python
def validate_parameters_have_capture_enabled(self, pipeline):
    params = self.get_pipeline_parameters(pipeline)
    violations = []
    for param in params:
        if not param['capture']:
            violations.append({
                'parameter_name': param['name'],
                'capture_value': param['capture'],
                'reason': f"Parameter '{param['name']}' does not have Capture enabled"
            })
    status = 'PASS' if not violations else 'FAIL'
    return {
        'status': status,
        'violations': violations,
        'total_params': len(params),
        'total_violations': len(violations)
    }
```

---

## Real Examples From Your Pipelines

### oracle2.slp — ALL PASS ✅

```
Parameter                  Capture    Result
─────────────────────────────────────────────
expression_library         true       ✅ PASS
schema_name                true       ✅ PASS
table_name                 true       ✅ PASS
actual_output              true       ✅ PASS
oracle_acct                true       ✅ PASS

Total: 5 params | 0 violations | Status: PASS
```

### snowflake.slp — ALL FAIL ❌

```
Parameter                  Capture    Result
─────────────────────────────────────────────
snowflake_acct             false      ❌ FAIL
actual_output              false      ❌ FAIL
schema_name                false      ❌ FAIL
table_name                 false      ❌ FAIL
expression_library         false      ❌ FAIL

Total: 5 params | 5 violations | Status: FAIL
```

### snowflake_keypair.slp — MIXED ❌

```
Parameter                  Capture    Result
─────────────────────────────────────────────
destination_hint           false      ❌ FAIL
schema                     false      ❌ FAIL
table                      false      ❌ FAIL
isTest                     false      ❌ FAIL
test_input_file            false      ❌ FAIL
snowflake_acct             false      ❌ FAIL

Total: 6 params | 6 violations | Status: FAIL
```

---

## Edge Cases

### Pipeline With No Parameters

If a pipeline has no parameters at all, the check **passes** — there's nothing to validate.

```python
params = []           # empty list
violations = []       # no violations possible
status = 'PASS'       # vacuously true
total_params = 0
total_violations = 0
```

### Parameter With Missing capture Field

If the `.slp` JSON is malformed and a parameter has no `capture` field, the code defaults to `False`:

```python
'capture': param.get('capture', {}).get('value', False)
#                                                 ^^^^^ default
```

This means missing capture fields are treated as violations — which is the safe default.

---

## How to Fix Violations

In SnapLogic Designer:

1. Open the pipeline
2. Go to **Pipeline Properties** (gear icon in the toolbar)
3. Click the **Settings** tab
4. For each parameter, check the **Capture** checkbox
5. Save the pipeline

Or in the `.slp` JSON directly, change `capture.value` from `false` to `true`:

```json
// Before (violation)
"capture": {"value": false}

// After (fixed)
"capture": {"value": true}
```

---

## Why This Matters

| Without Capture | With Capture |
|---|---|
| Cannot trace parameter values in execution logs | Full audit trail of every parameter value |
| Debugging requires re-running the pipeline | Can inspect historical runs |
| Cannot verify if correct values were passed to child pipelines | Parameter passing is traceable end-to-end |
| Compliance/audit gaps | Complete execution record |

For enterprises like those with strict audit requirements, Capture must be enabled on every parameter — no exceptions.

---

## Related Documentation

| Document | Description |
|---|---|
| [Validate Parameters Have Prefix](validate_parameters_have_prefix.md) | Parameter naming convention (xx prefix) |
| [Validate Pipeline Naming Auto Detection](validate_pipeline_naming_auto_detection.md) | Auto-detect parent/child and apply naming rules |
| [Peer Review Automation](peer_review_automation.md) | Full peer review automation overview |
