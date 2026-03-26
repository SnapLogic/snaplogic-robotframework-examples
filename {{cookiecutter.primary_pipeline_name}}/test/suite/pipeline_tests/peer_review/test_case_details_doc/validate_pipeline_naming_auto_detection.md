# Validate Pipeline Naming With Auto Detection — Complete Reference

## Purpose

Automatically detects whether a pipeline is a **parent** or **child** by analyzing the `.slp` file structure — no manual flags needed. Then applies the appropriate naming checks based on the detected type.

This eliminates the need for users to pass `is_child_pipeline=True/False` manually, making peer review automation fully self-sufficient.

---

## The Problem With Manual Detection

The original `Validate Pipeline Naming Convention` requires the user to manually specify whether a pipeline is a child:

```robot
# Manual approach — user must know and set the flag
${result}=    Validate Pipeline Naming Convention    ${pipeline}
...    is_child_pipeline=True
```

This has issues:
- Users forget to set the flag
- Batch review applies the same flag to all pipelines
- New team members don't know which pipelines are children
- The `.slp` file already contains this information — why ask the user?

---

## How Auto-Detection Works

Every `.slp` file contains structural indicators that reveal the pipeline's role in the execution hierarchy.

### The Two Indicators

**Indicator 1: Pipeline Execute Snaps**

If a pipeline contains a `Pipeline Execute` snap (`com-snaplogic-snaps-flow-pipeexec`), it **calls other pipelines** — making it a parent (or middle child).

```json
// Found inside a parent pipeline's snap_map
{
    "class_id": "com-snaplogic-snaps-flow-pipeexec",
    "property_map": {
        "settings": {
            "pipeline": {"value": "_child_pipeline1"}
        }
    }
}
```

**Indicator 2: Pipeline-Level Input Views**

If a pipeline has entries in `property_map.input`, it **receives data from a parent** via the Pipeline Execute snap's input passing — making it a child.

```json
// Found inside a child pipeline's property_map
{
    "input": {
        "930e237e-9349-...": {
            "view_type": {"value": "document"},
            "label": {"value": "Copy - input0"}
        }
    }
}
```

### The Detection Matrix

| Has Pipeline Execute | Has Input Views | Detected Type | Description |
|:---:|:---:|---|---|
| No | No | **standalone** | Independent pipeline, triggered directly |
| Yes | No | **parent** | Calls children, triggered directly |
| No | Yes | **child** | Called by parent, no further children |
| Yes | Yes | **middle_child** | Called by parent AND calls its own children |

### How `is_parent` and `is_child` Are Derived

```python
is_parent = pipeline_type in ('parent', 'standalone')
is_child  = pipeline_type in ('child', 'middle_child')
```

- **standalone** is treated as parent — it's a top-level pipeline, so it gets parent-level checks
- **middle_child** is treated as child — it's called by another pipeline, so it must follow child naming rules

---

## Detection Results — Your Pipelines

These are the actual detection results from the `.slp` files in `src/pipelines/`:

| File | Pipeline Execute | Input Views | Detected Type |
|---|:---:|:---:|---|
| `parent_pipeline1.slp` | Yes (calls `_child_pipeline1`) | No | **parent** |
| `child_pipeline1.slp` | Yes (calls `_child_pipeline2`) | No | **parent** * |
| `child_pipeline2.slp` | No | Yes | **child** |
| `oracle.slp` | No | No | **standalone** |
| `oracle2.slp` | No | No | **standalone** |
| `snowflake_keypair.slp` | No | Yes | **child** |
| `filereader.slp` | No | Yes | **child** |
| `oracle_cms_rebate.slp` | No | Yes | **child** |
| All other pipelines | No | No | **standalone** |

*Note: `child_pipeline1.slp` is detected as **parent** because it has a Pipeline Execute snap but no input views. Despite its filename suggesting "child", the `.slp` content shows it calls another pipeline without receiving pipeline-level input. This is a known limitation — see [Caveats](#caveats) section.

---

## The 3 Checks

`Validate Pipeline Naming With Auto Detection` runs **3 checks** sequentially. All checks are independent — a pipeline can fail multiple checks at once.

### Check 1: Pipeline Name Is Not Empty

**Applies to:** All pipeline types (parent, child, middle_child, standalone)

```python
if not name:
    violations.append("Pipeline name is empty")
```

| Pipeline Name | Result |
|---|---|
| `""` (empty) | FAIL — "Pipeline name is empty" |
| `"oracle2"` | PASS — moves to Check 2 |

### Check 2: Pipeline Name Contains Project Name

**Applies to:** All pipeline types, but **only if `project_name` is configured**

```python
if project_name and project_name not in name:
    violations.append(f"does not contain required project name '{project_name}'")
```

This checks if the project name appears **anywhere** in the pipeline name (not just at the start).

| Pipeline Name | `project_name` | Result |
|---|---|---|
| `z_greenlight_acquisition` | `greenlight` | PASS — contains "greenlight" |
| `my_greenlight_pipeline` | `greenlight` | PASS — contains "greenlight" |
| `greenlight_export` | `greenlight` | PASS — contains "greenlight" |
| `oracle_test` | `greenlight` | FAIL — does not contain "greenlight" |
| `anything` | `""` (not set) | PASS — check skipped entirely |

**Important:** The check uses Python's `in` operator — it's a substring match, not a prefix match. The project name can appear anywhere in the pipeline name.

### Check 3: Child Pipeline Must Start With z_

**Applies to:** Only `child` and `middle_child` types (auto-detected)

```python
if type_info['is_child'] and not name.startswith('z_'):
    violations.append(
        f"Child pipeline name '{name}' must start with 'z_' "
        f"(auto-detected as '{type_info['pipeline_type']}' — has pipeline-level input views)"
    )
```

| Pipeline Name | Detected Type | Result |
|---|---|---|
| `z_enrichment_child` | child | PASS |
| `z_greenlight_transform` | middle_child | PASS |
| `enrichment_child` | child | FAIL — "must start with 'z_'" |
| `TAPP102550_Asset_Brokerage` | child | FAIL — "must start with 'z_'" |
| `oracle2` | standalone | PASS — check skipped (not a child) |
| `parent_pipeline1` | parent | PASS — check skipped (not a child) |

---

## Complete Validation Flow

```
                    Load Pipeline (.slp file)
                              │
                              ▼
                 ┌─────────────────────────┐
                 │   Detect Pipeline Type   │
                 │                         │
                 │  Check for:             │
                 │  1. Pipeline Execute    │
                 │     snaps in snap_map   │
                 │  2. Input views in      │
                 │     property_map.input  │
                 └────────────┬────────────┘
                              │
              ┌───────────────┼───────────────┐
              ▼               ▼               ▼
         ┌─────────┐   ┌──────────┐   ┌────────────┐
         │ parent   │   │  child   │   │ standalone │
         │ or       │   │  or      │   │            │
         │ middle   │   │ middle   │   │            │
         └────┬────┘   └────┬─────┘   └─────┬──────┘
              │              │               │
              ▼              ▼               ▼
        ┌─────────────────────────────────────────┐
        │         Check 1: Name Not Empty          │
        │         (all types)                      │
        └─────────────────┬───────────────────────┘
                          │
                          ▼
        ┌─────────────────────────────────────────┐
        │  Check 2: Contains Project Name          │
        │  (all types, if project_name configured) │
        └─────────────────┬───────────────────────┘
                          │
                          ▼
        ┌─────────────────────────────────────────┐
        │  Check 3: Starts With z_                 │
        │  (child and middle_child ONLY)           │
        └─────────────────┬───────────────────────┘
                          │
                          ▼
              ┌───────────────────────┐
              │   Return Result       │
              │                       │
              │  status: PASS/FAIL    │
              │  pipeline_type: ...   │
              │  violations: [...]    │
              └───────────────────────┘
```

---

## Return Value Structure

```python
{
    "status": "FAIL",
    "pipeline_name": "TAPP102550_Asset_Brokerage",
    "pipeline_type": "child",
    "detected_type_info": {
        "pipeline_type": "child",
        "has_pipeline_execute": False,
        "has_input_views": True,
        "is_parent": False,
        "is_child": True,
        "pipeline_execute_targets": []
    },
    "violations": [
        "Child pipeline name 'TAPP102550_Asset_Brokerage' must start with 'z_' (auto-detected as 'child' — has pipeline-level input views)"
    ],
    "total_violations": 1
}
```

---

## Code Architecture — 3 Layers

### Layer 1: Test Case (peer_review_tests.robot)

```robot
Verify Pipeline Naming With Auto Detection
    [Tags]    peer_review    pipeline_naming    auto_detect    static_analysis
    ${result}=    Verify Pipeline Naming With Auto Detection And Return Result
    ...    ${pipeline}
    ...    project_name=${project_name}
    Should Be Equal    ${result}[status]    PASS
    ...    msg=Pipeline naming violations (detected as ${result}[pipeline_type]): ${result}[violations]
```

**What it does:** Calls the resource keyword, asserts PASS/FAIL. That's all.

### Layer 2: Resource Keyword (pipeline_inspector.resource)

```robot
Verify Pipeline Naming With Auto Detection And Return Result
    [Arguments]    ${pipeline}    ${project_name}=
    ${result}=    Validate Pipeline Naming With Auto Detection
    ...    ${pipeline}
    ...    project_name=${project_name}
    Log    Detected pipeline type: ${result}[pipeline_type]    console=True
    IF    ${result}[total_violations] > 0
        Log    Pipeline name: ${result}[pipeline_name] (type: ${result}[pipeline_type])    WARN
        FOR    ${violation}    IN    @{result}[violations]
            Log    Violation: ${violation}    WARN
        END
    ELSE
        Log    Pipeline '${result}[pipeline_name]' naming is valid (type: ${result}[pipeline_type])    console=True
    END
    RETURN    ${result}
```

**What it does:** Calls the Python library, logs the detected type and any violations as warnings, returns the result without asserting.

### Layer 3: Python Library (PipelineInspectorLibrary.py)

Two methods work together:

**`detect_pipeline_type()`** — The detection engine:
```python
def detect_pipeline_type(self, pipeline):
    # Scan snap_map for Pipeline Execute snaps
    # Check property_map.input for input views
    # Apply the detection matrix
    # Return type_info dict
```

**`validate_pipeline_naming_with_auto_detection()`** — The validation engine:
```python
def validate_pipeline_naming_with_auto_detection(self, pipeline, project_name=''):
    name = self.get_pipeline_name(pipeline)
    type_info = self.detect_pipeline_type(pipeline)

    # Check 1: Name not empty (all)
    # Check 2: Contains project name (all, if configured)
    # Check 3: Starts with z_ (child/middle_child only)

    return {status, pipeline_name, pipeline_type, violations, ...}
```

---

## Comparison: Manual vs Auto-Detection

| Aspect | Manual (`Validate Pipeline Naming Convention`) | Auto-Detect (`Validate Pipeline Naming With Auto Detection`) |
|---|---|---|
| Child detection | User passes `is_child_pipeline=True/False` | Reads `.slp` structure automatically |
| User effort | Must know pipeline hierarchy | Zero — fully automated |
| Batch review | Same flag applied to all files | Per-file detection |
| Accuracy | Depends on user knowledge | Based on actual pipeline content |
| Use case | When you know the pipeline type | Default for all scenarios |

---

## How It Runs in Batch Review

In `Run Peer Review On All Pipeline Files`, each pipeline is auto-detected individually:

```
src/pipelines/
├── parent_pipeline1.slp   → Detect: parent     → Checks 1, 2 only
├── child_pipeline2.slp    → Detect: child      → Checks 1, 2, 3 (z_ required)
├── oracle2.slp            → Detect: standalone  → Checks 1, 2 only
├── snowflake_keypair.slp  → Detect: child      → Checks 1, 2, 3 (z_ required)
└── kafka.slp              → Detect: standalone  → Checks 1, 2 only
```

Each file gets its own detection — no blanket `is_child_pipeline` flag applied across all files.

---

## Example Scenarios — Pass and Fail

### Scenario 1: Standalone Pipeline (PASS)

```
File: oracle2.slp
Pipeline Name: "greenlight_oracle2"
project_name: "greenlight"
```

```
Detection: standalone (no Pipeline Execute, no Input Views)
Check 1: Name not empty → "greenlight_oracle2" → PASS
Check 2: Contains "greenlight" → PASS
Check 3: Skipped (not a child)
Result: PASS
```

### Scenario 2: Child Pipeline Missing z_ (FAIL)

```
File: child_pipeline2.slp
Pipeline Name: "TAPP102550_Asset_Brokerage_Delay_Ack_Ingestion"
project_name: ""
```

```
Detection: child (has Input Views, no Pipeline Execute)
Check 1: Name not empty → PASS
Check 2: Skipped (project_name not configured)
Check 3: Starts with z_? → "TAPP102550_..." → FAIL
Result: FAIL — "must start with 'z_' (auto-detected as 'child' — has pipeline-level input views)"
```

### Scenario 3: Child Pipeline Missing Both (FAIL — 2 violations)

```
File: some_child.slp
Pipeline Name: "data_transform"
project_name: "greenlight"
```

```
Detection: child (has Input Views)
Check 1: Name not empty → PASS
Check 2: Contains "greenlight"? → "data_transform" → FAIL
Check 3: Starts with z_? → "data_transform" → FAIL
Result: FAIL — 2 violations
```

### Scenario 4: Parent Pipeline (PASS)

```
File: parent_pipeline1.slp
Pipeline Name: "greenlight_kafka_snowflake_parent"
project_name: "greenlight"
```

```
Detection: parent (has Pipeline Execute, no Input Views)
Check 1: Name not empty → PASS
Check 2: Contains "greenlight" → PASS
Check 3: Skipped (not a child)
Result: PASS
```

### Scenario 5: Middle Child (FAIL)

```
File: middle_pipeline.slp
Pipeline Name: "enrichment_layer"
project_name: "greenlight"
```

```
Detection: middle_child (has Pipeline Execute AND Input Views)
Check 1: Name not empty → PASS
Check 2: Contains "greenlight"? → FAIL
Check 3: Starts with z_? → FAIL
Result: FAIL — 2 violations
```

---

## Caveats

### Caveat 1: Parameter-Only Child Pipelines

A pipeline can be called by a parent via `Pipeline Execute` but receive data **only through parameters** (not pipeline-level input views). In this case:

- The child has **no input views** → detected as `standalone`
- The z_ prefix check is **skipped**
- The pipeline could be a child that doesn't follow naming rules

**Mitigation:** This is uncommon. Most child pipelines that receive data use input views. For the rare parameter-only children, use the manual `Validate Pipeline Naming Convention` with `is_child_pipeline=True`.

### Caveat 2: Filename vs Content

The filename (e.g., `child_pipeline1.slp`) may suggest a child, but the `.slp` content determines the actual type. The auto-detection trusts the **content**, not the filename.

### Caveat 3: Cannot Detect Cross-File Relationships

Auto-detection looks at a **single** `.slp` file. It cannot determine if another pipeline calls this one via Pipeline Execute. The detection relies solely on what's inside the file being inspected.

---

## Related Documentation

| Document | Description |
|---|---|
| [Validate Pipeline Naming Convention](validate_pipeline_naming_convention.md) | Manual naming checks (requires user to set flags) |
| [Validate Snap Naming Standards](validate_snap_naming_standards.md) | Snap-level naming checks |
| [Validate No Duplicate Snap Names](validate_no_duplicate_snap_names.md) | Duplicate snap name detection |
| [Peer Review Automation](peer_review_automation.md) | Full peer review automation overview |
