# Validate Child Pipeline Naming Convention — Complete Reference

## Purpose

Ensures that child pipelines follow the naming convention of starting with the `z_` prefix. This distinguishes child pipelines from parent/top-layer pipelines at a glance, making pipeline hierarchies immediately clear.

---

## The Problem

Without a naming convention, you cannot tell parent from child pipelines:

```
❌ BAD — which are parents, which are children?

├── acquisition_pipeline
├── data_load
├── enrichment
├── transform_data
├── validation_step
└── export_to_s3
```

```
✅ GOOD — z_ prefix instantly identifies children

├── greenlight_acquisition          ← parent (no z_)
├── greenlight_data_load            ← parent (no z_)
├── z_greenlight_enrichment         ← child (z_ prefix)
├── z_greenlight_transform          ← child (z_ prefix)
├── rebate_daily_export             ← parent (no z_)
└── z_rebate_validation_step        ← child (z_ prefix)
```

---

## Peer Review Requirement

From the peer review form:

> *"Child pipeline — Need to start with z_"*

---

## How This Test Case Works

### Test Case (peer_review_tests.robot)

```robot
Verify Child Pipeline Naming Convention
    [Documentation]    Validates that child pipelines start with z_ prefix.
    ...    Only runs when is_child_pipeline is set to True.
    ...    Skip this test for parent/top-layer pipelines.
    [Tags]    peer_review    pipeline_naming    child_pipeline    static_analysis
    Skip If    '${is_child_pipeline}' == 'False'    Not a child pipeline — skipping z_ prefix check.
    ${result}=    Verify Child Pipeline Naming And Return Result    ${pipeline}
    Should Be Equal    ${result}[status]    PASS
    ...    msg=Child pipeline must start with z_ prefix. Pipeline name: ${result}[pipeline_name]
```

### Step-by-Step Execution

```
Step 1: Check is_child_pipeline variable
        │
        ├── is_child_pipeline = 'False'
        │   └── SKIP — "Not a child pipeline — skipping z_ prefix check."
        │         (test shows as SKIP in the report, not FAIL)
        │
        └── is_child_pipeline = 'True'
            │
            ▼
Step 2: Get pipeline name from .slp file
        │
        │  Reads: property_map → info → label → value
        │  Example: "z_greenlight_enrichment"
        │
        ▼
Step 3: Check if name starts with 'z_'
        │
        │  Evaluate: 'z_greenlight_enrichment'.lower().startswith('z_')
        │
        ├── Starts with z_ → status = PASS
        │
        └── Does NOT start with z_ → status = FAIL
            │
            ▼
Step 4: Log result
        │
        ├── PASS → (no log, test passes silently)
        │
        └── FAIL → Log WARNING: "Child pipeline 'enrichment' does not start with z_ prefix."
        │
        ▼
Step 5: Assert result
        │
        ├── PASS → Test passes ✅
        │
        └── FAIL → Test fails with message:
            "Child pipeline must start with z_ prefix. Pipeline name: enrichment"
```

---

## The Check — Single Rule

This validation has **one check**: does the pipeline name start with `z_`?

```python
${starts_with_z}=    Evaluate    '${name}'.lower().startswith('z_')
```

The check is **case-insensitive** — both `z_` and `Z_` are accepted.

| Pipeline Name | `startswith('z_')` | Result |
|---|:---:|---|
| `z_greenlight_enrichment` | Yes | ✅ PASS |
| `Z_GREENLIGHT_ENRICHMENT` | Yes | ✅ PASS |
| `z_rebate_transform` | Yes | ✅ PASS |
| `enrichment` | No | ❌ FAIL |
| `TAPP102550_Asset_Brokerage` | No | ❌ FAIL |
| `child_pipeline1` | No | ❌ FAIL — `child_` is NOT `z_` |

---

## Where the Pipeline Name Comes From

The name is extracted from the `.slp` JSON file:

```json
{
    "property_map": {
        "info": {
            "label": {
                "value": "z_greenlight_enrichment"
            }
        }
    }
}
```

Python code:
```python
def get_pipeline_name(self, pipeline):
    return (
        pipeline.get('property_map', {}).get('info', {})
        .get('label', {}).get('value', '')
    ) or ''
```

**Important:** This is the pipeline's **display name** (label), not the filename. The filename might be `child_pipeline1.slp`, but the pipeline name inside the `.slp` could be `TAPP102550_Asset_Brokerage_Delay_Ack_Ingestion`.

---

## The Skip Logic

This test only runs when `is_child_pipeline` is set to `True`:

```robot
Skip If    '${is_child_pipeline}' == 'False'    Not a child pipeline — skipping z_ prefix check.
```

### How `is_child_pipeline` Gets Its Value

**Option 1: Default from test variables**

```robot
*** Variables ***
${is_child_pipeline}    False    # default — assumes parent pipeline
```

**Option 2: Override via command line**

```bash
make robot-run-tests TAGS="peer_review" EXTRA_ARGS="--variable is_child_pipeline:True"
```

**Option 3: Auto-detected in batch review**

In `Run Peer Review On All Pipeline Files`, the batch keyword auto-detects child status from the filename:

```robot
${is_child}=    Evaluate    '${entry}[file_name]'.startswith('z_') or '${entry}[file_name]'.startswith('child_')
```

### What SKIP Looks Like in the Report

```
Verify Child Pipeline Naming Convention :: Validates that child... | SKIP |
Not a child pipeline — skipping z_ prefix check.
```

This is intentional — a parent pipeline should not be penalized for not starting with `z_`. The SKIP makes it clear in the report that the check was deliberately skipped, not that it failed.

---

## Return Value Structure

```python
{
    "status": "FAIL",
    "pipeline_name": "TAPP102550_Asset_Brokerage_Delay_Ack_Ingestion"
}
```

| Field | Description |
|---|---|
| `status` | `"PASS"` if name starts with `z_`, `"FAIL"` otherwise |
| `pipeline_name` | The pipeline's display name from the .slp file |

---

## Code Architecture — 3 Layers

### Layer 1: Test Case (peer_review_tests.robot)

```robot
Verify Child Pipeline Naming Convention
    Skip If    '${is_child_pipeline}' == 'False'    Not a child pipeline...
    ${result}=    Verify Child Pipeline Naming And Return Result    ${pipeline}
    Should Be Equal    ${result}[status]    PASS
```

**What it does:** Skips if not a child, otherwise calls the resource keyword and asserts PASS.

### Layer 2: Resource Keyword (pipeline_inspector.resource)

```robot
Verify Child Pipeline Naming And Return Result
    [Arguments]    ${pipeline}
    ${name}=    Get Pipeline Name    ${pipeline}
    ${starts_with_z}=    Evaluate    '${name}'.lower().startswith('z_')
    ${status}=    Set Variable If    ${starts_with_z}    PASS    FAIL
    IF    '${status}' == 'FAIL'
        Log    Child pipeline '${name}' does not start with z_ prefix.    WARN
    END
    ${result}=    Create Dictionary    status=${status}    pipeline_name=${name}
    RETURN    ${result}
```

**What it does:** Gets the pipeline name, checks the z_ prefix, logs a warning on failure, returns the result dict.

### Layer 3: Python Library (PipelineInspectorLibrary.py)

```python
def get_pipeline_name(self, pipeline):
    return (
        pipeline.get('property_map', {}).get('info', {})
        .get('label', {}).get('value', '')
    ) or ''
```

**What it does:** Extracts the pipeline name from the .slp JSON. The z_ check itself is done in the resource layer, not in Python.

---

## Comparison: Manual vs Auto-Detection

This test case uses **manual detection** (`is_child_pipeline` variable). There is also an **auto-detection** test case:

| Aspect | This Test Case (Manual) | Auto-Detection Test Case |
|---|---|---|
| **Test name** | `Verify Child Pipeline Naming Convention` | `Verify Pipeline Naming With Auto Detection` |
| **How it knows child/parent** | `is_child_pipeline` variable (set by user or batch) | Reads .slp structure (Pipeline Execute snaps + Input Views) |
| **Checks performed** | z_ prefix only | Empty name + project name + z_ prefix |
| **Skip behavior** | Skips if `is_child_pipeline=False` | Never skips — auto-detects type |
| **When to use** | You know the pipeline type | Default for all scenarios |

Both exist because:
- **Manual** is simpler and gives explicit control
- **Auto-detection** is smarter but has [caveats](validate_pipeline_naming_auto_detection.md#caveats) (e.g., parameter-only children)

---

## Real Examples From Your Pipelines

### child_pipeline2.slp — FAIL ❌

```
Pipeline Name: "TAPP102550_Asset_Brokerage_Delay_Ack_Ingestion"
is_child_pipeline: True

Check: starts with z_? → "TAPP102550_..." → NO
Result: FAIL — "Child pipeline must start with z_ prefix"
```

### oracle2.slp — SKIP ⏭️

```
Pipeline Name: "oracle2"
is_child_pipeline: False

Result: SKIP — "Not a child pipeline — skipping z_ prefix check."
```

### Hypothetical z_ child — PASS ✅

```
Pipeline Name: "z_greenlight_enrichment"
is_child_pipeline: True

Check: starts with z_? → "z_greenlight_..." → YES
Result: PASS
```

---

## How to Fix Violations

In SnapLogic Designer:

1. Open the child pipeline
2. Go to **Pipeline Properties** (gear icon)
3. In the **Info** tab, change the pipeline **Label** to start with `z_`
4. Example: rename `enrichment` to `z_greenlight_enrichment`
5. Save the pipeline

---

## Related Documentation

| Document | Description |
|---|---|
| [Validate Pipeline Naming Convention](validate_pipeline_naming_convention.md) | Full naming checks (empty name, project name, z_ prefix) |
| [Validate Pipeline Naming Auto Detection](validate_pipeline_naming_auto_detection.md) | Auto-detect parent/child from .slp content |
| [Validate Parameters Have Capture Enabled](validate_parameters_have_capture_enabled.md) | Parameter capture checkbox validation |
| [Peer Review Automation](peer_review_automation.md) | Full peer review automation overview |
