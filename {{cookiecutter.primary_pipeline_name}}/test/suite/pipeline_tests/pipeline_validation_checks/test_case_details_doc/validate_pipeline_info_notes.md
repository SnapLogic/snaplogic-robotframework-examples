# Validate Pipeline Info Has Notes — Complete Reference

## Purpose

Ensures that the pipeline's **Notes** field in Pipeline Properties > Info is populated. When a pipeline is modified for a bug fix or enhancement, the ticket number should be recorded in Notes — creating a change history directly inside the pipeline.

---

## The Problem

Without notes, there is no change history inside the pipeline:

```
❌ NO NOTES — no record of changes

Pipeline: z_greenlight_acquisition
  Doc Link: https://jira.company.com/browse/GL-100  (original user story)
  Notes: (empty)

  The pipeline was modified 3 times for bug fixes.
  But there's no record of which tickets drove those changes.
  The Doc Link still points to the original story.
```

```
✅ NOTES PRESENT — full change history

Pipeline: z_greenlight_acquisition
  Doc Link: https://jira.company.com/browse/GL-100  (original user story)
  Notes: "GL-205: Added null handling for empty records
          GL-312: Fixed date format for international locales
          GL-418: Performance tuning — reduced batch size to 500"

  Every modification is tracked with its ticket number.
  Anyone can see what changed and why.
```

---

## Peer Review Requirement

From the peer review form:

> *"If the pipeline was modified for the ticket (bug fix or enhancement), and the Doc Link is already present, put the ticket number in the Notes section."*

---

## Where Notes Lives in the .slp File

The Notes field is stored in `property_map.info.notes`:

```json
{
    "property_map": {
        "info": {
            "label": {
                "value": "oracle2"
            },
            "author": {
                "value": "spothana@snaplogic.com"
            },
            "pipeline_doc_uri": {
                "value": null
            },
            "notes": {
                "value": null              ← THIS IS WHAT WE CHECK
            },
            "purpose": {
                "value": null
            }
        }
    }
}
```

---

## The Check — Single Rule

Is `notes.value` populated with a non-empty string?

```python
info = pipeline.get('property_map', {}).get('info', {})
notes = info.get('notes', {}).get('value', None)

if notes and str(notes).strip():
    status = 'PASS'
else:
    status = 'FAIL'
```

| `notes.value` | Result |
|---|---|
| `"GL-205: Added null handling for empty records"` | ✅ PASS |
| `"Bug fix for PROJ-5678"` | ✅ PASS |
| `"Updated schema mapping"` | ✅ PASS (any non-empty string) |
| `null` | ❌ FAIL |
| `""` | ❌ FAIL |
| `"   "` (whitespace only) | ❌ FAIL (stripped) |

**Note:** The check only verifies the field is **not empty**. It does not validate that the content contains a ticket number, follows a format, or is meaningful. Any non-empty, non-whitespace string passes.

---

## Complete Validation Flow

```
            Load Pipeline (.slp file)
                      │
                      ▼
        ┌──────────────────────────┐
        │  Read notes               │
        │                          │
        │  property_map →          │
        │    info →                │
        │      notes →             │
        │        value             │
        └────────────┬─────────────┘
                     │
                     ▼
           ┌──────────────────┐
           │  Is value present │
           │  and non-empty?   │
           └────────┬─────────┘
                    │
            ┌───────┴───────┐
            ▼               ▼
          Yes              No
           │            (null, "", "  ")
           ▼               │
     status = PASS         ▼
     message =        status = FAIL
     "Notes field     message =
      is populated"   "Pipeline Info >
                       Notes is empty.
                       Modified pipelines
                       should have the
                       ticket number
                       in Notes."
            │               │
            └───────┬───────┘
                    ▼
          ┌──────────────────┐
          │  Return result    │
          │                  │
          │  {status,        │
          │   notes,         │
          │   message}       │
          └──────────────────┘
```

---

## Return Value Structure

### When Notes Are Present (PASS)

```python
{
    "status": "PASS",
    "notes": "GL-205: Added null handling for empty records",
    "message": "Notes field is populated"
}
```

### When Notes Are Missing (FAIL)

```python
{
    "status": "FAIL",
    "notes": null,
    "message": "Pipeline Info > Notes is empty. Modified pipelines should have the ticket number in Notes."
}
```

| Field | Description |
|---|---|
| `status` | `"PASS"` if notes is populated, `"FAIL"` otherwise |
| `notes` | The actual value from the .slp file (string or null) |
| `message` | Human-readable description of the result |

---

## Code Architecture — 3 Layers

### Layer 1: Test Case (peer_review_tests.robot)

```robot
Verify Pipeline Info Has Notes
    [Documentation]    Validates that the pipeline Info > Notes section is populated.
    ...    Modified pipelines should have the ticket number in the Notes section.
    [Tags]    peer_review    documentation    static_analysis
    ${result}=    Verify Notes And Return Result    ${pipeline}
    Should Be Equal    ${result}[status]    PASS
    ...    msg=${result}[message]
```

**What it does:** Calls the resource keyword, asserts PASS. On failure, the error message is the human-readable `message` field.

### Layer 2: Resource Keyword (pipeline_inspector.resource)

```robot
Verify Notes And Return Result
    [Arguments]    ${pipeline}
    ${result}=    Validate Pipeline Info Has Notes    ${pipeline}
    IF    '${result}[status]' == 'FAIL'
        Log    ${result}[message]    WARN
    END
    RETURN    ${result}
```

**What it does:** Calls the Python library. If FAIL, logs the message as a WARNING (visible in log.html as yellow). Returns the result without asserting.

### Layer 3: Python Library (PipelineInspectorLibrary.py)

```python
def validate_pipeline_info_has_notes(self, pipeline):
    info = pipeline.get('property_map', {}).get('info', {})
    notes = info.get('notes', {}).get('value', None)

    if notes and str(notes).strip():
        status = 'PASS'
        message = "Notes field is populated"
    else:
        status = 'FAIL'
        message = "Pipeline Info > Notes is empty. Modified pipelines should have the ticket number in Notes."

    return {'status': status, 'notes': notes, 'message': message}
```

**What it does:** Reads the `notes` field from the info section, checks if it's non-empty, returns the result.

---

## Real Examples From Your Pipelines

### ALL Pipelines — FAIL ❌

Every pipeline in `src/pipelines/` currently has `notes: null`:

| Pipeline | Notes | Status |
|---|---|---|
| oracle2.slp | `null` | ❌ FAIL |
| snowflake.slp | `null` | ❌ FAIL |
| sit_sqlserver.slp | `null` | ❌ FAIL |
| parent_pipeline1.slp | `null` | ❌ FAIL |
| salesforce.slp | `null` | ❌ FAIL |

This is expected — these are test/example pipelines, not production pipelines with modification history.

### Hypothetical PASS Example

```json
{
    "property_map": {
        "info": {
            "label": {"value": "z_greenlight_acquisition"},
            "pipeline_doc_uri": {
                "value": "https://jira.company.com/browse/GL-100"
            },
            "notes": {
                "value": "GL-205: Added null handling for empty records\nGL-312: Fixed date format"
            }
        }
    }
}
```

```
Status: PASS
Message: "Notes field is populated"
```

---

## Edge Cases

### Notes Is Whitespace Only

```json
"notes": {"value": "   "}
```

Result: **FAIL** — the `.strip()` call removes whitespace, leaving an empty string.

### Notes Contains Just a Ticket Number

```json
"notes": {"value": "PROJ-1234"}
```

Result: **PASS** — any non-empty string passes. The check does not validate format.

### Info Section Is Missing Entirely

```json
{
    "property_map": {}
}
```

Result: **FAIL** — the nested `.get()` calls return `None` all the way down.

### Notes Key Is Missing From Info

```json
{
    "property_map": {
        "info": {
            "label": {"value": "oracle2"}
        }
    }
}
```

Result: **FAIL** — `info.get('notes', {}).get('value', None)` returns `None`.

---

## How to Fix Violations

In SnapLogic Designer:

1. Open the pipeline
2. Click the **gear icon** (Pipeline Properties) in the toolbar
3. Go to the **Info** tab
4. In the **Notes** field, add the ticket number and a brief description of the change:
   - Example: `GL-205: Added null handling for empty records`
   - Example: `PROJ-5678: Bug fix — corrected join key for customer table`
5. Save the pipeline

Or in the `.slp` JSON directly:

```json
// Before (violation)
"notes": {
    "value": null
}

// After (fixed)
"notes": {
    "value": "GL-205: Added null handling for empty records"
}
```

---

## Relationship to Doc Link Check

Doc Link and Notes serve **different purposes** in the peer review workflow:

| Scenario | Doc Link | Notes |
|---|---|---|
| **New pipeline** created for a ticket | Required — link the User Story URL | Optional (nice to have) |
| **Modified pipeline** (bug fix/enhancement) | Already present from creation | Required — add the ticket number |

From the peer review form:

> *"If the pipeline was created for the ticket → Original User Story URL in Doc Link"*
>
> *"If the pipeline was modified for the ticket, and the Doc Link is already present → ticket number in Notes"*

Both checks run independently. The framework currently checks each field in isolation — it does not enforce the conditional logic ("Notes required only if Doc Link already exists and this is a modification"). Both are always required to pass.

---

## Comparison: Doc Link vs Notes

| Aspect | Doc Link | Notes |
|---|---|---|
| **Test case** | Verify Pipeline Info Has Documentation Link | Verify Pipeline Info Has Notes |
| **.slp field** | `pipeline_doc_uri.value` | `notes.value` |
| **Purpose** | Link to the original requirement | Log of subsequent changes |
| **Content** | A URL (typically Jira/Confluence) | Ticket numbers + descriptions |
| **When populated** | At pipeline creation | At each modification |
| **Accumulates over time** | No — stays as the original URL | Yes — new entries appended |

---

## The Full Info Section

The `.slp` info section contains 5 fields:

| Field | .slp Key | Checked By |
|---|---|---|
| Label | `label.value` | Pipeline naming checks |
| Author | `author.value` | Not checked |
| Doc Link | `pipeline_doc_uri.value` | Verify Pipeline Info Has Documentation Link |
| **Notes** | **`notes.value`** | **This check** |
| Purpose | `purpose.value` | Not checked |

---

## Related Documentation

| Document | Description |
|---|---|
| [Validate Pipeline Info Has Doc Link](validate_pipeline_info_doc_link.md) | Doc Link validation |
| [Validate Accounts Not Hardcoded](validate_accounts_not_hardcoded.md) | Account reference check |
| [Validate Parameters Have Prefix](validate_parameters_have_prefix.md) | Parameter xx prefix check |
| [Peer Review Automation](peer_review_automation.md) | Full peer review automation overview |
