# Peer Review Checklist — Automation Coverage Report

## Overview

This document maps every item from the Peer Review Form to its automation status in the Robot Framework testing suite. Each checklist item is categorized as:

- ✅ **Automated** — Fully covered by an existing test case
- 🔶 **Partially Automated** — Some aspects covered, others require manual review
- ❌ **Not Automated** — Requires manual review or future development
- 🔮 **Future (Pending API)** — Can be automated once SnapLogic exposes the required API

---

## Coverage Summary

| Category | Total Items | Automated | Partially | Not Automated | Future |
|---|:---:|:---:|:---:|:---:|:---:|
| Pipeline Naming | 2 | 2 | 0 | 0 | 0 |
| Snap Naming | 1 | 1 | 0 | 0 | 0 |
| Accounts | 4 | 3 | 0 | 1 | 0 |
| Pipeline Settings | 2 | 2 | 0 | 0 | 0 |
| Pipeline Info | 2 | 2 | 0 | 0 | 0 |
| Logging of Pipeline | 5 | 0 | 0 | 0 | 5 |
| Run Pipeline | 2 | 2 | 0 | 0 | 0 |
| Metadata | 1 | 0 | 0 | 1 | 0 |
| S3 Usage | 1 | 0 | 0 | 1 | 0 |
| Release Documentation | 3 | 0 | 0 | 3 | 0 |
| Data Applications Page | 3 | 0 | 0 | 3 | 0 |
| Metadata Validation | 1 | 0 | 0 | 1 | 0 |
| **TOTAL** | **27** | **12** | **0** | **10** | **5** |

**Automation Rate: 12 of 27 items (44%) fully automated**
**Automatable with future APIs: 17 of 27 items (63%)**

---

## Detailed Checklist Mapping

### 1. Pipeline Naming Standards

| # | Checklist Item | Status | Test Case | Doc |
|---|---|:---:|---|---|
| 1.1 | Pipelines need to include name of project (Ex. z_greenlight_acquisition) | ✅ | `Verify Pipeline Naming Convention` | [validate_pipeline_naming_convention.md](validate_pipeline_naming_convention.md) |
| 1.2 | Child pipeline — Need to start with z_ | ✅ | `Verify Child Pipeline Naming Convention` | [validate_child_pipeline_naming.md](validate_child_pipeline_naming.md) |

**How it works:**
- The pipeline name is read from `property_map.info.label.value` in the `.slp` file
- Check 1.1: Verifies the pipeline name **contains** the configured project name (substring match)
- Check 1.2: Verifies child pipeline names **start with** `z_` (child detection is based on pipeline name or manual flag)
- Auto-detection variant also available: `Verify Pipeline Naming With Auto Detection` — [validate_pipeline_naming_auto_detection.md](validate_pipeline_naming_auto_detection.md)

---

### 2. Snap Naming Standards

| # | Checklist Item | Status | Test Case | Doc |
|---|---|:---:|---|---|
| 2.1 | Snaps named so a casual observer understands their purpose | ✅ | `Verify Snap Naming Standards Are Followed` | [validate_snap_naming_standards.md](validate_snap_naming_standards.md) |
| 2.2 | No duplicate snap names | ✅ | `Verify No Duplicate Snap Names Exist` | [validate_no_duplicate_snap_names.md](validate_no_duplicate_snap_names.md) |

**How it works:**
- 5-layer detection for default names: hardcoded list → auto-derived from class_id → numbered defaults → type match → additional user-defined defaults
- Catches names like "Mapper", "Filter", "Oracle - Insert", "Mapper1", "Filter 2"
- Duplicate check flags any snap name appearing more than once in the pipeline

---

### 3. Accounts

| # | Checklist Item | Status | Test Case | Doc |
|---|---|:---:|---|---|
| 3.1 | Accounts need to be in shared folder | ✅ | `Verify Account References Use Shared Folder Format` | — |
| 3.2 | Account should have the "=" sign turned on | ✅ | `Verify Account References Are Not Hardcoded` | [validate_accounts_not_hardcoded.md](validate_accounts_not_hardcoded.md) |
| 3.3 | Account reference in format of ../shared/\<account\> | ✅ | `Verify Account References Use Shared Folder Format` | — |
| 3.4 | Accounts should never be hard coded | ✅ | `Verify Account References Are Not Hardcoded` | [validate_accounts_not_hardcoded.md](validate_accounts_not_hardcoded.md) |

**How it works:**
- Check 3.2/3.4: Reads `property_map.account.account_ref.expression` — must be `true` (= sign on)
- Check 3.1/3.3: Validates the resolved account path matches regex `\.\./shared/.+`
- For expression-based refs, resolves the pipeline parameter default value and checks the pattern

---

### 4. Pipeline Properties — Settings

| # | Checklist Item | Status | Test Case | Doc |
|---|---|:---:|---|---|
| 4.1 | Make sure all inputs are captured ("Capture" checkbox checked) | ✅ | `Verify All Parameters Have Capture Enabled` | [validate_parameters_have_capture_enabled.md](validate_parameters_have_capture_enabled.md) |
| 4.2 | All parameters prefixed with xx (except top layer pipelines) | ✅ | `Verify Parameters Follow Naming Convention` | [validate_parameters_have_prefix.md](validate_parameters_have_prefix.md) |

**How it works:**
- Check 4.1: Reads `capture.value` for each parameter in `param_table` — must be `true`
- Check 4.2: Checks each parameter name starts with `xx`. Parent pipelines are exempt (auto-detected from pipeline name: if name starts with `z_` → child → enforce prefix; otherwise → parent → skip prefix)

---

### 5. Pipeline Properties — Info

| # | Checklist Item | Status | Test Case | Doc |
|---|---|:---:|---|---|
| 5.1 | New pipelines: Original User Story URL in Doc Link | ✅ | `Verify Pipeline Info Has Documentation Link` | [validate_pipeline_info_doc_link.md](validate_pipeline_info_doc_link.md) |
| 5.2 | Modified pipelines: Ticket number in Notes section | ✅ | `Verify Pipeline Info Has Notes` | [validate_pipeline_info_notes.md](validate_pipeline_info_notes.md) |

**How it works:**
- Check 5.1: Reads `property_map.info.pipeline_doc_uri.value` — must be non-null and non-empty
- Check 5.2: Reads `property_map.info.notes.value` — must be non-null and non-empty
- Both checks verify the field is populated but do not validate content format

---

### 6. Logging of Pipeline ❌

| # | Checklist Item | Status | Why Not Automated | Path to Automation |
|---|---|:---:|---|---|
| 6.1 | Ensure entries in ABC log table (etlauditbalancecontrollog) | 🔮 | Requires pipeline execution + database query | Execute pipeline → query log table → verify entries exist |
| 6.2 | One entry per run per entity | 🔮 | Requires pipeline execution + database query | Query log table → group by run_id, entity → assert count = 1 |
| 6.3 | Status of jobs is Completed, not Active | 🔮 | Requires pipeline execution + monitoring API | Execute pipeline → query SnapLogic monitoring API or log table → assert status = 'Completed' |
| 6.4 | etljobenddatetime is filled in | 🔮 | Requires pipeline execution + database query | Query log table → assert etljobenddatetime IS NOT NULL |
| 6.5 | etl*rowcount are filled in where applicable | 🔮 | Requires pipeline execution + database query | Query log table → assert etl*rowcount > 0 or IS NOT NULL |

**Why not automated today:**
All logging checks require **running the pipeline first** and then querying the `etlauditbalancecontrollog` database table. The current peer review automation is **static analysis** — it inspects the `.slp` file without executing anything.

**What's needed:**
- Pipeline execution (already supported by the framework via triggered tasks)
- Database connection to the logging table (framework supports Oracle, PostgreSQL, etc.)
- Keywords to query and validate log entries

**Effort estimate:** Medium — the framework already has database query capabilities. Need to add keywords for log table validation.

---

### 7. Run Pipeline ✅

| # | Checklist Item | Status | Test Case | Test File |
|---|---|:---:|---|---|
| 7.1 | Make sure not take excessive amount of time | ✅ | `Execute Trigger Task Within Certain Time` | `sla/sla_pipeline.robot` |
| 7.2 | Results are expected | ✅ | `Verify Data In Oracle Table` + `Compare Actual vs Expected CSV Output` | `oracle/oracle_baseline_tests.robot` |

**How 7.1 works (SLA / Execution Time):**
- The test case `Execute Trigger Task Within Certain Time` executes a triggered task with a **configurable time limit**
- Uses `Run Triggered Task In Certain Time` keyword with arguments:
  - `timeout` — maximum allowed execution time (e.g., `30 Sec`)
  - `retry_interval` — how often to check status (e.g., `5 Sec`)
- If the pipeline exceeds the time limit → test **FAILS**
- If the pipeline fails during execution → detailed error is captured including failed snap info, runtime state, and resolution message

```robot
# Example: Pipeline must complete within 30 seconds
Execute Trigger Task Within Certain Time
    Run Triggered Task In Certain Time
    ...    30 Sec    5 Sec
    ...    ${ORG_NAME}/${PIPELINES_LOCATION_PATH}
    ...    ${pipeline_name}_${task1}_${unique_id}
```

**How 7.2 works (Expected Results):**
Three-step verification in `oracle_baseline_tests.robot`:

| Step | Test Case | What It Does |
|---|---|---|
| 1 | `Verify Data In Oracle Table` | Queries DB → asserts expected row count (e.g., 2 records) |
| 2 | `Export Oracle Data To CSV` | Exports DB table data to a CSV file for comparison |
| 3 | `Compare Actual vs Expected CSV Output` | Compares actual CSV vs expected CSV → asserts **IDENTICAL** |

```robot
# Step 1: Verify row count
Capture And Verify Number of records From DB Table
    ...    DEMO.TEST_TABLE1    DEMO    DCEVENTHEADERS_USERID    2

# Step 2: Export actual data to CSV
Export DB Table Data To CSV
    ...    DEMO.TEST_TABLE1    DCEVENTHEADERS_USERID    ${actual_output_file1_path}

# Step 3: Compare actual vs expected
Compare CSV Files With Exclusions Template
    ...    ${actual_output_file1_path}    ${expected_output_file1_path}    ${FALSE}    ${TRUE}    IDENTICAL
```

**Note:** These are **post-execution** tests — they require the pipeline to be executed first. They are not part of the static `.slp` file analysis (peer_review tag). They run as part of the pipeline-specific test suites (e.g., `oracle`, `sla_pipeline` tags).

---

### 8. Metadata ❌

| # | Checklist Item | Status | Why Not Automated | Path to Automation |
|---|---|:---:|---|---|
| 8.1 | Run the repo checker — no errors or warnings | ❌ | External tool — not part of .slp file | Would need to invoke the repo checker tool via API or CLI and parse its output |

**Why not automated today:**
The repo checker is a separate tool with its own interface. The peer review automation focuses on `.slp` file inspection.

**Path to automation:**
If the repo checker has a CLI or API interface, it could be invoked from a Robot Framework keyword and its output parsed for errors/warnings.

---

### 9. S3 Usage ❌

| # | Checklist Item | Status | Why Not Automated | Path to Automation |
|---|---|:---:|---|---|
| 9.1 | Follow "How We Use S3" guidelines | ❌ | Context-specific — requires understanding of S3 usage patterns | Would need codified rules (e.g., bucket naming, path conventions) that can be checked against snap configurations |

**Why not automated today:**
The "How We Use S3" document defines organizational conventions that would need to be translated into specific, checkable rules. Without knowing the exact rules, the framework cannot validate compliance.

**Path to automation:**
If the S3 rules can be codified (e.g., "S3 paths must start with `s3://company-bucket/`", "S3 snaps must use a specific account"), these could be checked by inspecting S3 snap configurations in the `.slp` file.

---

### 10. Release Documentation ❌

| # | Checklist Item | Status | Why Not Automated | Path to Automation |
|---|---|:---:|---|---|
| 10.1 | Review DE_Release Documentation — is it complete? | ❌ | External document review | Would need the document to be in a machine-readable format with required fields |
| 10.2 | Any special instructions needed? | ❌ | Human judgment required | Cannot be automated — requires understanding of deployment context |
| 10.3 | MetaData Validation — Run all steps | ❌ | External process | Would need the metadata validation steps exposed as an API or CLI |

**Why not automated today:**
These are reviews of external documents and processes that exist outside the `.slp` file and SnapLogic platform.

---

### 11. Data Applications Page ❌

| # | Checklist Item | Status | Why Not Automated | Path to Automation |
|---|---|:---:|---|---|
| 11.1 | Was the template used? | ❌ | External document review | Would need template compliance rules codified |
| 11.2 | Is it complete? | ❌ | External document review | Would need required fields defined |
| 11.3 | Are pipeline rerun instructions included? | ❌ | External document review | Could check for a "rerun" section in a structured document |

**Why not automated today:**
The Data Applications Page is an external document/wiki page. Its completeness requires human review.

---

## Visual Coverage Map

```
Peer Review Form                              Automation Status
════════════════                              ═════════════════

Logging of Pipeline                           🔮 Future (requires execution + DB)
├── ABC log table entries                     🔮
├── One entry per run per entity              🔮
├── Status = Completed                        🔮
├── etljobenddatetime filled                  🔮
└── etl*rowcount filled                       🔮

Run Pipeline                                  ✅ FULLY AUTOMATED
├── Not excessive time                        ✅ Execute Trigger Task Within Certain Time (sla_pipeline.robot)
└── Results expected                          ✅ Verify Data In Oracle Table + Compare CSV (oracle_baseline_tests.robot)

Metadata                                      ❌ Not Automated
└── Repo checker                              ❌

Pipeline Naming Standards                     ✅ FULLY AUTOMATED
├── Include project name                      ✅ Verify Pipeline Naming Convention
└── Child starts with z_                      ✅ Verify Child Pipeline Naming Convention

S3 Usage                                      ❌ Not Automated
└── Follow S3 guidelines                      ❌

Accounts                                      ✅ FULLY AUTOMATED
├── In shared folder                          ✅ Verify Account References Use Shared Folder Format
├── "=" sign turned on                        ✅ Verify Account References Are Not Hardcoded
├── ../shared/<account> format                ✅ Verify Account References Use Shared Folder Format
└── Never hard coded                          ✅ Verify Account References Are Not Hardcoded

Pipeline Settings                             ✅ FULLY AUTOMATED
├── Capture checkbox checked                  ✅ Verify All Parameters Have Capture Enabled
└── xx prefix (except top layer)              ✅ Verify Parameters Follow Naming Convention

Snap Naming Standards                         ✅ FULLY AUTOMATED
├── Descriptive names                         ✅ Verify Snap Naming Standards Are Followed
└── No duplicates                             ✅ Verify No Duplicate Snap Names Exist

Pipeline Info                                 ✅ FULLY AUTOMATED
├── Doc Link (new pipelines)                  ✅ Verify Pipeline Info Has Documentation Link
└── Notes (modified pipelines)                ✅ Verify Pipeline Info Has Notes

Release Documentation                        ❌ Not Automated
├── Complete?                                 ❌
├── Special instructions?                     ❌
└── Metadata validation steps                 ❌

Data Applications Page                        ❌ Not Automated
├── Template used?                            ❌
├── Complete?                                 ❌
└── Rerun instructions?                       ❌
```

---

## Priority Roadmap for Remaining Items

### High Priority — Can Automate with Current Framework

| Item | Effort | What's Needed |
|---|---|---|
| 6.1-6.5 Logging checks | Medium | Add keywords to query `etlauditbalancecontrollog` after pipeline execution. Need table structure from customer. |

### Medium Priority — Requires Additional Integration

| Item | Effort | What's Needed |
|---|---|---|
| 8.1 Repo checker | Medium | CLI/API integration with the repo checker tool |
| 9.1 S3 usage | Medium | Codify S3 rules into checkable patterns |

### Low Priority — Difficult to Automate

| Item | Effort | What's Needed |
|---|---|---|
| 10.1-10.3 Release docs | High | Structured document format + compliance rules |
| 11.1-11.3 Data apps page | High | Structured document format + required fields |

---

## How to Run the Automated Checks

### Single Pipeline
```bash
make robot-run-tests TAGS="peer_review"
```

### All Pipelines in Directory (Batch)
```bash
make robot-run-tests TAGS="batch_review"
```

### With Project Name Enforcement
```bash
make robot-run-tests TAGS="peer_review" EXTRA_ARGS="--variable project_name:greenlight"
```

---

## Test Cases Reference

### Static Analysis (No Pipeline Execution Required)

| # | Test Case | Tags | Test File | What It Checks |
|---|---|---|---|---|
| 1 | Verify Snap Naming Standards Are Followed | `peer_review`, `snap_naming` | `peer_review_tests.robot` | No default/generic snap names |
| 2 | Verify No Duplicate Snap Names Exist | `peer_review`, `snap_naming` | `peer_review_tests.robot` | All snap names unique |
| 3 | Verify Pipeline Naming Convention | `peer_review`, `pipeline_naming` | `peer_review_tests.robot` | Contains project name |
| 4 | Verify Child Pipeline Naming Convention | `peer_review`, `child_pipeline` | `peer_review_tests.robot` | Starts with z_ |
| 5 | Verify Pipeline Naming With Auto Detection | `peer_review`, `auto_detect` | `peer_review_tests.robot` | Auto-detect parent/child + naming |
| 6 | Verify All Parameters Have Capture Enabled | `peer_review`, `parameters` | `peer_review_tests.robot` | Capture checkbox on |
| 7 | Verify Parameters Follow Naming Convention | `peer_review`, `parameters` | `peer_review_tests.robot` | xx prefix (parent exempt) |
| 8 | Verify Account References Are Not Hardcoded | `peer_review`, `accounts` | `peer_review_tests.robot` | Expression mode on |
| 9 | Verify Account References Use Shared Folder Format | `peer_review`, `accounts` | `peer_review_tests.robot` | ../shared/ pattern |
| 10 | Verify Pipeline Info Has Documentation Link | `peer_review`, `documentation` | `peer_review_tests.robot` | Doc Link populated |
| 11 | Verify Pipeline Info Has Notes | `peer_review`, `documentation` | `peer_review_tests.robot` | Notes populated |
| 12 | Batch Review All Pipeline Files In Directory | `batch_review` | `peer_review_tests.robot` | All checks on all .slp files |

### Post-Execution (Requires Pipeline Execution)

| # | Test Case | Tags | Test File | What It Checks |
|---|---|---|---|---|
| 13 | Execute Trigger Task Within Certain Time | `sla_pipeline` | `sla/sla_pipeline.robot` | Pipeline completes within time limit (e.g., 30 sec) |
| 14 | Verify Data In Oracle Table | `oracle` | `oracle/oracle_baseline_tests.robot` | Expected row count in target table after execution |
| 15 | Export Oracle Data To CSV | `oracle` | `oracle/oracle_baseline_tests.robot` | Export DB table to CSV for comparison |
| 16 | Compare Actual vs Expected CSV Output | `oracle` | `oracle/oracle_baseline_tests.robot` | Actual CSV matches expected CSV (IDENTICAL) |

---

## Documentation Index

| Document | Description |
|---|---|
| [validate_snap_naming_standards.md](validate_snap_naming_standards.md) | Snap naming — 5-layer default detection |
| [validate_no_duplicate_snap_names.md](validate_no_duplicate_snap_names.md) | Duplicate snap name detection |
| [validate_pipeline_naming_convention.md](validate_pipeline_naming_convention.md) | Pipeline naming — project name + z_ prefix |
| [validate_child_pipeline_naming.md](validate_child_pipeline_naming.md) | Child pipeline z_ prefix check |
| [validate_pipeline_naming_auto_detection.md](validate_pipeline_naming_auto_detection.md) | Auto-detect parent/child from .slp content |
| [validate_parameters_have_capture_enabled.md](validate_parameters_have_capture_enabled.md) | Parameter capture checkbox |
| [validate_parameters_have_prefix.md](validate_parameters_have_prefix.md) | Parameter xx prefix convention |
| [validate_accounts_not_hardcoded.md](validate_accounts_not_hardcoded.md) | Account expression vs hardcoded |
| [validate_pipeline_info_doc_link.md](validate_pipeline_info_doc_link.md) | Doc Link validation |
| [validate_pipeline_info_notes.md](validate_pipeline_info_notes.md) | Notes validation |
| [peer_review_automation.md](peer_review_automation.md) | Full automation overview |
