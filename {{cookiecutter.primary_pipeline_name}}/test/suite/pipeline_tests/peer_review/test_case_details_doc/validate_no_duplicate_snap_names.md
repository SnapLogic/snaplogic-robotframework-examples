# Validate No Duplicate Snap Names — Complete Reference

## Purpose

Every snap in a SnapLogic pipeline must have a **unique name**. When multiple snaps share the same name, error tracing becomes impossible — you can't tell which snap caused a failure.

This validation counts the occurrences of each snap name and flags any name that appears more than once.

---

## The Problem

Snaps with duplicate names make debugging a nightmare:

```
ERROR: Snap 'Extract Customer Fields' failed at row 4,521
```

If 3 snaps are all named "Extract Customer Fields", you have no idea which one caused the error. The pipeline log points to a name, not a position — so duplicate names eliminate your ability to trace failures.

```
❌ BAD (duplicate names — which "Mapper" failed?)

[Mapper] → [Mapper] → [Mapper] → [Filter] → [Oracle - Insert]
   ?          ?          ?

ERROR: Snap 'Mapper' failed — but which one?
```

```
✅ GOOD (unique names — immediately know where the error is)

[Map Customer Fields] → [Map Address Data] → [Map Order Totals] → [Filter Inactive] → [Insert Into Customers]

ERROR: Snap 'Map Address Data' failed — found it!
```

---

## How It Differs from Validate Snap Naming Standards

These are two **separate, independent** checks:

| Check | Question It Answers | Example |
|-------|--------------------| --------|
| **Validate Snap Naming Standards** | Is the name a **default/generic** name? | `"Mapper"` → FAIL (default name) |
| **Validate No Duplicate Snap Names** | Is the name **unique** in the pipeline? | `"Extract Fields"` appearing 3 times → FAIL (duplicate) |

A pipeline can pass one and fail the other:

### Scenario 1: Good names but duplicated

```
Pipeline snaps:
├── "Extract Customer Fields"     ← good name, but...
├── "Extract Customer Fields"     ← DUPLICATE ❌
├── "Remove Inactive Records"     ← unique ✅
└── "Load To Oracle"              ← unique ✅

Snap Naming Standards: PASS ✅ (no defaults)
Duplicate Snap Names:  FAIL ❌ ("Extract Customer Fields" appears 2 times)
```

### Scenario 2: Default names but all unique

```
Pipeline snaps:
├── "Mapper"                      ← default name, but unique
├── "Filter"                      ← default name, but unique
├── "Router"                      ← default name, but unique
└── "Join"                        ← default name, but unique

Snap Naming Standards: FAIL ❌ (4 default names)
Duplicate Snap Names:  PASS ✅ (all unique)
```

### Scenario 3: Both fail

```
Pipeline snaps:
├── "Mapper"                      ← default AND...
├── "Mapper"                      ← DUPLICATE
├── "Mapper"                      ← DUPLICATE
└── "Filter"                      ← default name

Snap Naming Standards: FAIL ❌ (4 default names)
Duplicate Snap Names:  FAIL ❌ ("Mapper" appears 3 times)
```

---

## Code Logic — Step by Step

### Step 1: Extract All Snap Names

```python
snaps = self.get_all_snap_names(pipeline)
```

Parses the pipeline's `snap_map` JSON and extracts each snap's details:

```python
# Input: pipeline JSON (from .slp file)
{
    "snap_map": {
        "abc123": {
            "class_id": "com-snaplogic-snaps-transform-datatransform",
            "property_map": {
                "info": {
                    "label": {"value": "Extract Customer Fields"}
                }
            }
        },
        "def456": {
            "class_id": "com-snaplogic-snaps-flow-filter",
            "property_map": {
                "info": {
                    "label": {"value": "Extract Customer Fields"}   # duplicate!
                }
            }
        },
        "ghi789": {
            "class_id": "com-snaplogic-snaps-oracle-insert",
            "property_map": {
                "info": {
                    "label": {"value": "Insert Into Customers"}
                }
            }
        }
    }
}

# Output: list of snap info dicts
[
    {"id": "abc123", "name": "Extract Customer Fields", "class_id": "...", "simple_type": "datatransform"},
    {"id": "def456", "name": "Extract Customer Fields", "class_id": "...", "simple_type": "filter"},
    {"id": "ghi789", "name": "Insert Into Customers",  "class_id": "...", "simple_type": "oracle-insert"}
]
```

### Step 2: Count Name Occurrences

```python
name_counts: Dict[str, List[str]] = {}

for snap in snaps:
    name = snap['name'].strip()
    if name:    # skip empty names (handled by snap naming standards check)
        name_counts.setdefault(name, []).append(snap['id'])
```

Builds a dictionary mapping each name to the list of snap IDs that use it:

```python
{
    "Extract Customer Fields": ["abc123", "def456"],   # 2 snaps share this name
    "Insert Into Customers":   ["ghi789"]              # unique
}
```

**Important:** Empty names are **skipped** — they are not counted as duplicates. Empty names are handled separately by the `Validate Snap Naming Standards` check.

### Step 3: Identify Duplicates

```python
duplicates = []
for name, ids in name_counts.items():
    if len(ids) > 1:
        duplicates.append({
            'snap_name': name,
            'count': len(ids),
            'snap_ids': ids
        })
```

Filters for names with more than one occurrence:

```python
[
    {
        "snap_name": "Extract Customer Fields",
        "count": 2,
        "snap_ids": ["abc123", "def456"]
    }
]
```

### Step 4: Determine Status and Return

```python
status = 'PASS' if not duplicates else 'FAIL'
result = {
    'status': status,
    'duplicates': duplicates,
    'total_violations': len(duplicates)
}
```

---

## Detection Rules

### What Gets Flagged

| Rule | Description |
|------|-------------|
| **Same name, any type** | Two snaps named "Mapper" — even if one is a Mapper and the other is a Filter with a bad name |
| **Case-sensitive** | "Mapper" and "mapper" are treated as different names (names are stripped but not lowercased) |
| **2+ occurrences** | A name must appear at least twice to be flagged |
| **All duplicates reported** | If a name appears 5 times, it's reported once with `count: 5` |

### What Does NOT Get Flagged

| Rule | Description |
|------|-------------|
| **Empty names** | Skipped — handled by Validate Snap Naming Standards |
| **Similar but different names** | "Mapper 1" and "Mapper 2" are unique — no violation |
| **Default names that are unique** | "Mapper" appearing once is NOT a duplicate (but it IS a naming standards violation) |

---

## Examples

### Example 1: All Unique Names — PASS

```
Pipeline snaps:
├── "CDC Data Generator"
├── "Extract Customer Fields"
├── "Enrichment & Map"
├── "Remove Inactive Records"
├── "Insert Into Customers Table"
└── "Write Audit Log CSV"
```

```python
Result: {
    "status": "PASS",
    "duplicates": [],
    "total_violations": 0
}
```

### Example 2: One Duplicate — FAIL

```
Pipeline snaps:
├── "Extract Fields"          ← snap ID: abc123
├── "Map Customer Data"
├── "Extract Fields"          ← snap ID: def456 (DUPLICATE)
├── "Filter Inactive"
└── "Load To Oracle"
```

```python
Result: {
    "status": "FAIL",
    "duplicates": [
        {
            "snap_name": "Extract Fields",
            "count": 2,
            "snap_ids": ["abc123", "def456"]
        }
    ],
    "total_violations": 1
}
```

### Example 3: Multiple Duplicates — FAIL

```
Pipeline snaps:
├── "Mapper"                  ← snap ID: snap1
├── "Mapper"                  ← snap ID: snap2 (DUPLICATE)
├── "Mapper"                  ← snap ID: snap3 (DUPLICATE)
├── "Filter"                  ← snap ID: snap4
├── "Filter"                  ← snap ID: snap5 (DUPLICATE)
├── "Load Data"               ← unique
└── "Write Output"            ← unique
```

```python
Result: {
    "status": "FAIL",
    "duplicates": [
        {
            "snap_name": "Mapper",
            "count": 3,
            "snap_ids": ["snap1", "snap2", "snap3"]
        },
        {
            "snap_name": "Filter",
            "count": 2,
            "snap_ids": ["snap4", "snap5"]
        }
    ],
    "total_violations": 2
}
```

### Example 4: Empty Names — Not Counted as Duplicates

```
Pipeline snaps:
├── ""                        ← empty — SKIPPED (not counted)
├── ""                        ← empty — SKIPPED (not counted)
├── "Extract Fields"          ← unique
├── "Load Data"               ← unique
```

```python
Result: {
    "status": "PASS",
    "duplicates": [],
    "total_violations": 0
}
```

The two empty names are **not** flagged as duplicates. They will be caught by the `Validate Snap Naming Standards` check instead (Layer 1: Empty Name Check).

---

## Flow Through the Framework

### Test Case (peer_review_tests.robot)

```robot
Verify No Duplicate Snap Names Exist
    [Documentation]    Validates that all snap names in the pipeline are unique.
    ...    Duplicate names make it difficult to trace errors to specific snaps.
    [Tags]    peer_review    snap_naming    static_analysis
    Pipeline Should Have No Duplicate Snap Names    ${pipeline}
```

### Assertion Keyword (pipeline_inspector.resource)

```robot
Pipeline Should Have No Duplicate Snap Names
    [Arguments]    ${pipeline}
    ${result}=    Validate No Duplicate Snap Names    ${pipeline}
    Should Be Equal    ${result}[status]    PASS
    ...    msg=Duplicate snap names found: ${result}[duplicates]
```

### Python Engine (PipelineInspectorLibrary.py)

```python
def validate_no_duplicate_snap_names(self, pipeline):
    snaps = self.get_all_snap_names(pipeline)       # Step 1: Extract
    name_counts = {}
    for snap in snaps:
        name = snap['name'].strip()
        if name:
            name_counts.setdefault(name, []).append(snap['id'])  # Step 2: Count

    duplicates = []
    for name, ids in name_counts.items():
        if len(ids) > 1:
            duplicates.append({...})                # Step 3: Identify

    status = 'PASS' if not duplicates else 'FAIL'   # Step 4: Return
    return {'status': status, 'duplicates': duplicates, ...}
```

### Visual Flow

```
peer_review_tests.robot
│
├── Calls: Pipeline Should Have No Duplicate Snap Names
│          │
│          ├── Calls: Validate No Duplicate Snap Names (Python)
│          │          │
│          │          ├── get_all_snap_names() → extracts all snap names from JSON
│          │          ├── Counts occurrences of each name
│          │          ├── Filters names with count > 1
│          │          └── Returns {status, duplicates, total_violations}
│          │
│          └── Should Be Equal ${result}[status] PASS
│              └── If FAIL → msg: "Duplicate snap names found: [{'snap_name': 'Mapper', 'count': 3}]"
│
└── Test result: PASS or FAIL
```

---

## How to Run

### Run This Check Only

```bash
make robot-run-tests TAGS="snap_naming"
```

This runs both snap naming checks (standards + duplicates) since they share the `snap_naming` tag.

### Run All Peer Review Checks

```bash
make robot-run-tests TAGS="peer_review"
```

### Override Pipeline File

```bash
make robot-run-tests TAGS="snap_naming" EXTRA_ARGS="--variable pipeline_file:/app/src/pipelines/snowflake.slp"
```

---

## Report Output

### Console Output (during execution)

When duplicates are found, the test fails with a message like:

```
FAIL: Duplicate snap names found: [{'snap_name': 'Mapper', 'count': 3, 'snap_ids': ['snap1', 'snap2', 'snap3']}, {'snap_name': 'Filter', 'count': 2, 'snap_ids': ['snap4', 'snap5']}]
```

### HTML Report (log-*.html)

The detailed log shows:
- Total snaps analyzed
- Each duplicate name with occurrence count
- The snap IDs involved (for tracing in Designer)

### In Batch Review

When running batch review across all pipelines, the duplicate check is included in each pipeline's report:

```
======================================================================
  PEER REVIEW REPORT: oracle2
  File: oracle2.slp
======================================================================
  Overall: FAIL  |  Passed: 5  |  Failed: 4  |  Skipped: 1
----------------------------------------------------------------------
  [FAIL] Snap Naming (6 violation(s))
  [PASS] Duplicate Snap Names                    ← This check
  [PASS] Pipeline Naming
  ...
======================================================================
```

---

## Return Value Structure

```python
# When duplicates exist (FAIL)
{
    "status": "FAIL",
    "total_violations": 2,
    "duplicates": [
        {
            "snap_name": "Mapper",
            "count": 3,
            "snap_ids": ["abc123-def456", "ghi789-jkl012", "mno345-pqr678"]
        },
        {
            "snap_name": "Filter",
            "count": 2,
            "snap_ids": ["stu901-vwx234", "yza567-bcd890"]
        }
    ]
}

# When no duplicates (PASS)
{
    "status": "PASS",
    "total_violations": 0,
    "duplicates": []
}
```

---

## Relationship to Other Checks

| Check | Catches | This Check Catches |
|-------|---------|-------------------|
| Validate Snap Naming Standards | Default names: `"Mapper"`, `"Filter"` | — |
| Validate Snap Naming Standards | Numbered defaults: `"Mapper1"`, `"Filter 2"` | — |
| Validate Snap Naming Standards | Empty names: `""` | — |
| **Validate No Duplicate Snap Names** | — | Same name on multiple snaps |

Both checks together ensure snap names are:
1. **Descriptive** — not default or generic (Snap Naming Standards)
2. **Unique** — no two snaps share the same name (This check)

---

## Summary

| Aspect | Detail |
|--------|--------|
| **What it checks** | Every snap name appears at most once in the pipeline |
| **How it works** | Counts occurrences per name, flags any with count > 1 |
| **Empty names** | Skipped — not counted as duplicates |
| **Case sensitivity** | Case-sensitive (`"Mapper"` ≠ `"mapper"`) |
| **Tag** | `snap_naming` |
| **Python method** | `validate_no_duplicate_snap_names()` |
| **Resource keyword** | `Pipeline Should Have No Duplicate Snap Names` |
| **Returns** | `{status, duplicates: [{snap_name, count, snap_ids}], total_violations}` |
