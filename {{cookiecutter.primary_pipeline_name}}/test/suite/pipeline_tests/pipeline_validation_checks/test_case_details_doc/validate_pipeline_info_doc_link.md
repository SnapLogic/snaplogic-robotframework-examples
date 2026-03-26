# Validate Pipeline Info Has Documentation Link — Complete Reference

## Purpose

Ensures every pipeline has the **Original User Story URL** linked in the Pipeline Properties > Info > Doc Link field. This creates a traceable connection between the pipeline and the business requirement that drove its creation.

---

## The Problem

Without a documentation link, there is no way to trace a pipeline back to its requirements:

```
❌ NO DOC LINK — who built this? why does it exist?

Pipeline: oracle2
  Author: spothana@snaplogic.com
  Doc Link: (empty)
  Notes: (empty)

  6 months later...
  "What does this pipeline do?"
  "Which user story was this for?"
  "Is this still needed?"
  Nobody knows.
```

```
✅ DOC LINK PRESENT — full traceability

Pipeline: z_greenlight_acquisition
  Author: spothana@snaplogic.com
  Doc Link: https://jira.company.com/browse/PROJ-1234
  Notes: "Bug fix for PROJ-5678 — added null handling for empty records"

  6 months later...
  Click the link → full context in Jira.
  Read the notes → know what changed and why.
```

---

## Peer Review Requirements

From the peer review form:

> *"Pipeline Properties – Info. This applies to the 'topmost' pipeline that was created for, or modified for, a ticket."*
>
> *"If the pipeline was created for the ticket, the Original User Story URL needs to be linked in the Pipeline Properties > Info > Doc Link"*

---

## Where Doc Link Lives in the .slp File

The Doc Link is stored in `property_map.info.pipeline_doc_uri`:

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
                "value": null              ← THIS IS WHAT WE CHECK
            },
            "notes": {
                "value": null
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

Is `pipeline_doc_uri.value` populated with a non-empty string?

```python
info = pipeline.get('property_map', {}).get('info', {})
doc_link = info.get('pipeline_doc_uri', {}).get('value', None)

if doc_link and str(doc_link).strip():
    status = 'PASS'
else:
    status = 'FAIL'
```

| `pipeline_doc_uri.value` | Result |
|---|---|
| `"https://jira.company.com/browse/PROJ-1234"` | ✅ PASS |
| `"https://confluence.company.com/page/12345"` | ✅ PASS |
| `"PROJ-1234"` | ✅ PASS (any non-empty string) |
| `null` | ❌ FAIL |
| `""` | ❌ FAIL |
| `"   "` (whitespace only) | ❌ FAIL (stripped) |

**Note:** The check only verifies the field is **not empty**. It does not validate that the value is a valid URL or that the URL is reachable. Any non-empty, non-whitespace string passes.

---

## Complete Validation Flow

```
            Load Pipeline (.slp file)
                      │
                      ▼
        ┌──────────────────────────┐
        │  Read pipeline_doc_uri    │
        │                          │
        │  property_map →          │
        │    info →                │
        │      pipeline_doc_uri →  │
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
     "Doc link is     message =
      present: URL"   "Pipeline Info >
                       Doc Link is empty.
                       New pipelines must
                       have the User Story
                       URL linked."
            │               │
            └───────┬───────┘
                    ▼
          ┌──────────────────┐
          │  Return result    │
          │                  │
          │  {status,        │
          │   doc_link,      │
          │   message}       │
          └──────────────────┘
```

---

## Return Value Structure

### When Doc Link Is Present (PASS)

```python
{
    "status": "PASS",
    "doc_link": "https://jira.company.com/browse/PROJ-1234",
    "message": "Doc link is present: https://jira.company.com/browse/PROJ-1234"
}
```

### When Doc Link Is Missing (FAIL)

```python
{
    "status": "FAIL",
    "doc_link": null,
    "message": "Pipeline Info > Doc Link is empty. New pipelines must have the User Story URL linked."
}
```

| Field | Description |
|---|---|
| `status` | `"PASS"` if doc link is populated, `"FAIL"` otherwise |
| `doc_link` | The actual value from the .slp file (string or null) |
| `message` | Human-readable description of the result |

---

## Code Architecture — 3 Layers

### Layer 1: Test Case (peer_review_tests.robot)

```robot
Verify Pipeline Info Has Documentation Link
    [Documentation]    Validates that the pipeline has a Doc Link in Pipeline Properties > Info.
    ...    New pipelines must have the Original User Story URL linked.
    [Tags]    peer_review    documentation    static_analysis
    ${result}=    Verify Doc Link And Return Result    ${pipeline}
    Should Be Equal    ${result}[status]    PASS
    ...    msg=${result}[message]
```

**What it does:** Calls the resource keyword, asserts PASS. On failure, the error message is the human-readable `message` field from the result.

### Layer 2: Resource Keyword (pipeline_inspector.resource)

```robot
Verify Doc Link And Return Result
    [Arguments]    ${pipeline}
    ${result}=    Validate Pipeline Info Has Doc Link    ${pipeline}
    IF    '${result}[status]' == 'FAIL'
        Log    ${result}[message]    WARN
    END
    RETURN    ${result}
```

**What it does:** Calls the Python library. If FAIL, logs the message as a WARNING (visible in log.html as yellow). Returns the result without asserting — the test case handles the assertion.

### Layer 3: Python Library (PipelineInspectorLibrary.py)

```python
def validate_pipeline_info_has_doc_link(self, pipeline):
    info = pipeline.get('property_map', {}).get('info', {})
    doc_link = info.get('pipeline_doc_uri', {}).get('value', None)

    if doc_link and str(doc_link).strip():
        status = 'PASS'
        message = f"Doc link is present: {doc_link}"
    else:
        status = 'FAIL'
        message = "Pipeline Info > Doc Link is empty. New pipelines must have the User Story URL linked."

    return {'status': status, 'doc_link': doc_link, 'message': message}
```

**What it does:** Reads the `pipeline_doc_uri` from the info section, checks if it's non-empty, returns the result.

---

## Real Examples From Your Pipelines

### ALL Pipelines — FAIL ❌

Every pipeline in your `src/pipelines/` directory currently has `pipeline_doc_uri: null`:

| Pipeline | Doc Link | Status |
|---|---|---|
| oracle2.slp | `null` | ❌ FAIL |
| snowflake.slp | `null` | ❌ FAIL |
| sit_sqlserver.slp | `null` | ❌ FAIL |
| parent_pipeline1.slp | `null` | ❌ FAIL |
| salesforce.slp | `null` | ❌ FAIL |
| kafka.slp | `null` | ❌ FAIL |

This is expected — these are test/example pipelines, not production pipelines created from user stories.

### Hypothetical PASS Example

```json
{
    "property_map": {
        "info": {
            "label": {"value": "z_greenlight_acquisition"},
            "pipeline_doc_uri": {
                "value": "https://jira.company.com/browse/GL-1234"
            }
        }
    }
}
```

```
Status: PASS
Message: "Doc link is present: https://jira.company.com/browse/GL-1234"
```

---

## The Full Info Section

The `.slp` info section contains 5 fields. This check only examines `pipeline_doc_uri`:

| Field | .slp Key | What It Contains | Checked By |
|---|---|---|---|
| **Label** | `label.value` | Pipeline display name | Pipeline naming checks |
| **Author** | `author.value` | Creator's email | Not checked |
| **Doc Link** | `pipeline_doc_uri.value` | User Story / requirement URL | **This check** |
| **Notes** | `notes.value` | Free-text notes | Separate check (Verify Pipeline Info Has Notes) |
| **Purpose** | `purpose.value` | Pipeline description | Not checked |

---

## Edge Cases

### Doc Link Is Whitespace Only

```json
"pipeline_doc_uri": {"value": "   "}
```

Result: **FAIL** — the `.strip()` call removes whitespace, leaving an empty string.

### Doc Link Is Not a URL

```json
"pipeline_doc_uri": {"value": "see Jira ticket PROJ-1234"}
```

Result: **PASS** — any non-empty string passes. The check does not validate URL format.

### Info Section Is Missing Entirely

```json
{
    "property_map": {}
}
```

Result: **FAIL** — the nested `.get()` calls return `None` all the way down, which triggers the FAIL path.

### pipeline_doc_uri Key Is Missing

```json
{
    "property_map": {
        "info": {
            "label": {"value": "oracle2"}
        }
    }
}
```

Result: **FAIL** — `info.get('pipeline_doc_uri', {}).get('value', None)` returns `None`.

---

## How to Fix Violations

In SnapLogic Designer:

1. Open the pipeline
2. Click the **gear icon** (Pipeline Properties) in the toolbar
3. Go to the **Info** tab
4. In the **Doc Link** field, paste the User Story URL
   - Example: `https://jira.company.com/browse/PROJ-1234`
   - Example: `https://confluence.company.com/display/TEAM/Feature+Spec`
5. Save the pipeline

Or in the `.slp` JSON directly:

```json
// Before (violation)
"pipeline_doc_uri": {
    "value": null
}

// After (fixed)
"pipeline_doc_uri": {
    "value": "https://jira.company.com/browse/PROJ-1234"
}
```

---

## Relationship to Notes Check

Doc Link and Notes serve different purposes and are separate test cases:

| Test Case | Field | When Required |
|---|---|---|
| **Verify Pipeline Info Has Documentation Link** (this doc) | `pipeline_doc_uri` | When a pipeline is **created** for a ticket |
| **Verify Pipeline Info Has Notes** | `notes` | When a pipeline is **modified** for a ticket (and Doc Link already exists) |

From the peer review form:

> *"If the pipeline was created for the ticket, the Original User Story URL needs to be linked in Doc Link"*
>
> *"If the pipeline was modified for the ticket (bug fix or enhancement), and the Doc Link is already present, put the ticket number in the Notes section."*

Both checks run independently. A pipeline can fail one, both, or neither.

---

## Related Documentation

| Document | Description |
|---|---|
| [Validate Pipeline Info Has Notes](validate_pipeline_info_notes.md) | Notes section validation |
| [Validate Accounts Not Hardcoded](validate_accounts_not_hardcoded.md) | Account reference check |
| [Validate Parameters Have Capture Enabled](validate_parameters_have_capture_enabled.md) | Parameter capture check |
| [Peer Review Automation](peer_review_automation.md) | Full peer review automation overview |
