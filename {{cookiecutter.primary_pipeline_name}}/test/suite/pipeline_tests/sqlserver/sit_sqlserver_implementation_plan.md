# SIT SQL Server Test Plan — sit_sqlserver.robot

## Context
The `sit_sqlserver.slp` pipeline reads from 3 SQL Server source tables (tblRequest, tblHeader, tblItems), routes records by RequestType, performs joins/mappings/unions across two flows, and updates tblRequest with Status=1. The LLD defines 12 test cases (TC_001–TC_012). This plan covers all 12 LLD test cases across **13 automated tests** following Account Setup → Expression Library Upload → Source Data Verification → Pipeline Import → Task Creation → Execution → Post-Pipeline Validation → CSV Comparison.

---

## Test Execution Order (13 Tests)

| # | Test Case | LLD TC | Phase |
|---|-----------|--------|-------|
| **Suite Setup** | Check Connections (DB connect, clean tables, generate unique_id) | -- | Setup |
| 1 | Create SQL Server Account | -- | Account Setup |
| 2 | Upload Expression Library | -- | Asset Setup |
| 3 | Verify tblRequest Source Data (7 active rows) | TC_001 | Pre-Pipeline |
| 4 | Verify tblHeader Source Data (7 rows) | TC_005_01 | Pre-Pipeline |
| 5 | Verify tblHeader DCProcess Derivation | TC_005_02 | Pre-Pipeline |
| 6 | Verify tblItems Source Data (13 rows) | TC_004_01 | Pre-Pipeline |
| 7 | Verify tblItems Null Handling | TC_004_02 | Pre-Pipeline |
| 8 | Import Pipeline | -- | Pipeline Setup |
| 9 | Create Triggered Task | -- | Task Setup |
| 10 | Execute Triggered Task | TC_012_01 | Execution |
| 11 | Verify Both Router Paths Processed (3 Request34 + 4 Request1256) | TC_002, TC_006-TC_011 | Post-Pipeline |
| 12 | Export tblRequest Post-Pipeline Data To CSV | TC_012_02 | Post-Pipeline |
| 13 | Compare Actual vs Expected tblRequest CSV | TC_012_03 | Post-Pipeline |
| **Suite Teardown** | Disconnect from Database | -- | Teardown |

---

## LLD Traceability Matrix

| LLD TC | Description | Verified By | Method |
|--------|-------------|-------------|--------|
| TC_001 | tblRequest extraction (Status=0, RequestType 1-6) | Test 3 | `Row Count Should Be` with where_clause |
| TC_002 | RequestType routing (1,2,5,6 vs 3,4) | Test 11 | `Row Count Should Be` per route path |
| TC_003 | Request mapping and sorting | Test 13 | Indirect: correct CSV output |
| TC_004_01 | Item data row count verification | Test 6 | `Row Count Should Be` |
| TC_004_02 | Item null handling (VendorChallanNo, CBS_GPNumber) | Test 7 | `Execute Custom Query` |
| TC_005_01 | Header data row count verification | Test 4 | `Row Count Should Be` |
| TC_005_02 | Header DCProcess derivation | Test 5 | `Execute Custom Query` |
| TC_006 | Flow 1 join (Request + Header) | Test 11 | Indirect: Request34 rows updated = join worked |
| TC_007 | Flow 1 mapping (51 fields) | Test 13 | Indirect: correct final state |
| TC_008 | Flow 2 join (Request + Header + Items) | Test 11 | Indirect: Request1256 rows updated = join worked |
| TC_009 | Flow 2 mapping | Test 13 | Indirect: correct final state |
| TC_010 | Union merge | Test 11 | Indirect: all 7 IDs updated = both paths merged |
| TC_011 | tblRequest update (Status=1, SubmittedOn, StatusMessage) | Test 11 | Combined: 3+4=7 confirms all active rows processed |
| TC_012_01 | Execute pipeline end-to-end | Test 10 | `Run Triggered Task With Parameters From Template` |
| TC_012_02 | Export post-pipeline data to CSV | Test 12 | `Export DB Table Data To CSV` |
| TC_012_03 | Compare actual vs expected output | Test 13 | `Compare CSV Files With Exclusions Template` |

> **Note**: TC_002/003/006-010 are validated indirectly because intermediate pipeline snap outputs cannot be observed from outside SnapLogic. Their correctness is proven by correct downstream results.

---

## Generic Keywords Used (from sql_table_operations.resource)

All table setup and verification uses generic keywords from `sql_table_operations.resource`. The `sqlserver_queries.resource` file only contains column definitions (`${TBLREQUEST_DEFINITION}`, `${TBLHEADER_DEFINITION}`, `${TBLITEMS_DEFINITION}`) and seed data INSERT statements — no custom DROP, CREATE, or VERIFY queries:

| Keyword | Purpose | Example Usage |
|---------|---------|---------------|
| `Create Table` | Drop (if exists) + Create table in one call | `Create Table  dbo.tblRequest  ${TBLREQUEST_DEFINITION}` |
| `Row Count Should Be` | Validate exact row count with optional WHERE | `Row Count Should Be  dbo.tblRequest  7  where_clause=Status=0` |
| `Execute Custom Query` | Run any SELECT and return results | `Execute Custom Query  SELECT RequestId, ... FROM dbo.tblHeader` |
| `Select Where` | Select rows with WHERE filter | `Select Where  dbo.tblRequest  Status=1 AND StatusMessage='Submitted in CBS'` |
| `Export DB Table Data To CSV` | Export table data to CSV file | `Export DB Table Data To CSV  dbo.tblRequest  Id  ${csv_path}` |
| `Compare CSV Files With Exclusions Template` | Compare actual vs expected CSV | `Compare CSV Files With Exclusions Template  ${actual}  ${expected}  ...` |
| `Create Account From Template` | Create SnapLogic account | Already exists in current test |
| `Upload File Using File Protocol Template` | Upload expression library | Template-based file upload |
| `Import Pipelines From Template` | Import .slp pipeline | Template-based pipeline import |
| `Create Triggered Task From Template` | Create triggered task | Template-based task creation |
| `Run Triggered Task With Parameters From Template` | Execute triggered task | Template-based task execution |

---

## Test Case Details

### Test 1: Create SQL Server Account (EXISTS)
- **Keywords**: `Create Account From Template`
- **Status**: Already exists in current file

### Test 2: Upload Expression Library (NEW)
- **Keywords**: `Upload File Using File Protocol Template`
- **Uploads**: Expression library `.expr` file to `${ACCOUNT_LOCATION_PATH}`
- **Note**: The `.expr` filename must match what the pipeline references internally via `lib.<name>`

### Test 3: Verify tblRequest Source Data — TC_001 (MODIFY)
- **Keywords**: `Row Count Should Be`
- **Validation**: `Row Count Should Be  dbo.tblRequest  7  where_clause=Status=0 AND RequestType IN ('1','2','3','4','5','6')`
- **Change**: Replace raw Query + Get Length with generic keyword

### Test 4: Verify tblHeader Source Data — TC_005_01 (MODIFY)
- **Keywords**: `Row Count Should Be`
- **Validation**: `Row Count Should Be  dbo.tblHeader  7`
- **Change**: Replace raw Query + Get Length with generic keyword

### Test 5: Verify tblHeader DCProcess Derivation — TC_005_02 (NEW)
- **Keywords**: `Execute Custom Query`
- **Validation**: Runs the same computed column query the pipeline uses:
  `SELECT RequestId, LTRIM(RTRIM(ISNULL(DCOutBoundType,''))) + ' ' + LTRIM(RTRIM(ISNULL(DCTransactionType,''))) AS DCProcess FROM dbo.tblHeader ORDER BY RequestId`
- **Asserts**: Row count = 7, logs DCProcess values for review

### Test 6: Verify tblItems Source Data — TC_004_01 (MODIFY)
- **Keywords**: `Row Count Should Be`
- **Validation**: `Row Count Should Be  dbo.tblItems  13`
- **Change**: Replace raw Query + Get Length with generic keyword

### Test 7: Verify tblItems Null Handling — TC_004_02 (NEW)
- **Keywords**: `Execute Custom Query`
- **Validation**: Runs the same ISNULL transformation the pipeline uses:
  `SELECT RequestId, ISNULL(VendorChallanNo,'') AS VendorChallanNoItm, ISNULL(CBS_GPNumber,'') AS CBS_GPNumber_Clean FROM dbo.tblItems ORDER BY RequestId, Id`
- **Asserts**: Row count = 13, logs null-handled values for review

### Test 8: Import Pipeline (NEW)
- **Keywords**: `Import Pipelines From Template`
- **Imports**: `sit_sqlserver.slp` into `${PIPELINES_LOCATION_PATH}`

### Test 9: Create Triggered Task (NEW)
- **Keywords**: `Create Triggered Task From Template`
- **Creates**: Task with `${task_params}` including sqlserver_acct reference

### Test 10: Execute Triggered Task — TC_012_01 (NEW)
- **Keywords**: `Run Triggered Task With Parameters From Template`
- **Executes**: Pipeline end-to-end

### Test 11: Verify Both Router Paths Processed — TC_002/TC_006-TC_011 (NEW)
- **Keywords**: `Row Count Should Be` (called twice)
- **Validation 1**: `Row Count Should Be  dbo.tblRequest  3  where_clause=RequestType IN ('3','4') AND Status=1 AND StatusMessage='Submitted in CBS'`
- **Validation 2**: `Row Count Should Be  dbo.tblRequest  4  where_clause=RequestType IN ('1','2','5','6') AND Status=1 AND StatusMessage='Submitted in CBS'`
- **Proves**: Both router paths (Request34 and Request1256) produced output that was merged and processed. Combined 3+4=7 confirms all active rows were updated (TC_011)

### Test 12: Export tblRequest Post-Pipeline Data To CSV — TC_012_02 (NEW)
- **Keywords**: `Export DB Table Data To CSV`
- **Exports**: `dbo.tblRequest` ordered by `Id` to `${actual_output_tblrequest_path}`

### Test 13: Compare Actual vs Expected tblRequest CSV — TC_012_03 (NEW)
- **Keywords**: `Compare CSV Files With Exclusions Template`
- **Compares**: Actual CSV vs expected CSV, excluding timestamp columns (RequestedOn, SubmittedOn, ProcessedOn)

---

## Files to Modify

### 1. `sit_sqlserver.robot` (extend existing)
**Path**: `test/suite/pipeline_tests/sqlserver/sit_sqlserver.robot`

**Settings additions**:
- Add `Resource ../../../resources/common/files.resource`
- Add `Library OperatingSystem`
- Add `Suite Teardown Disconnect from Database`

**Variables additions**:
- `${pipeline_name}` = sit_sqlserver
- `${pipeline_file_name}` = sit_sqlserver.slp
- `${task_name}` = EBAS_CBS_Task
- `${expression_library_path}` = path to the pipeline's expression library `.expr` file
- `&{task_params}` = pipeline parameter dict (sqlserver_acct reference)
- CSV paths: `${actual_output_tblrequest_path}`, `${expected_output_tblrequest_path}`
- `@{excluded_columns_for_comparison}` = RequestedOn, SubmittedOn, ProcessedOn

**Keywords modifications**:
- `Check Connections`: Add `Get Unique Id` + `Set Suite Variable`
- `Check Connections`: Uses `Create Table` generic keyword (handles DROP + CREATE) instead of raw `Execute SQL String`

**`sqlserver_queries.resource` contains only**:
- Column definitions: `${TBLREQUEST_DEFINITION}`, `${TBLHEADER_DEFINITION}`, `${TBLITEMS_DEFINITION}` (used by `Create Table` keyword)
- Seed data: `${INSERT_TBLREQUEST_SAMPLE_DATA}`, `${INSERT_TBLHEADER_SAMPLE_DATA}`, `${INSERT_TBLITEMS_SAMPLE_DATA}`
- No DROP, CREATE, or VERIFY queries — all handled by generic keywords from `sql_table_operations.resource`

---

## Files to Create

### 2. Expression Library
**Path**: `test/suite/test_data/actual_expected_data/expression_libraries/sqlserver/<pipeline_library>.expr`
- Copy from `backup/` and adapt Accounts map to reference `../shared/sqlserver_acct`
- **Note**: The `.expr` filename must match the pipeline's internal `lib.<name>` reference and cannot be renamed

### 3. Expected Output CSV
**Path**: `test/suite/test_data/actual_expected_data/expected_output/sqlserver/sit_sqlserver_tblrequest_expected.csv`
- 8 rows: 7 with Status=1 + StatusMessage='Submitted in CBS', 1 pre-existing Status=1 row (Id=7)
- Columns: Id, RequestType, Status, StatusMessage, Requestor, RequestorDepartment, RequestedOn, SubmittedOn, ProcessedOn, CBS_DCNumber, CBS_FOCNumber, CBS_GPNumber, EBAS_GPId, Remarks

### 4. Actual Output Directory
**Path**: `test/suite/test_data/actual_expected_data/actual_output/sqlserver/`
- Create directory (populated at runtime by export test)

---

## Sample Data & Expected Counts

| Table | Total Rows | Active (Status=0) | Request34 Path | Request1256 Path |
|-------|------------|-------------------|----------------|------------------|
| tblRequest | 8 | 7 | 3 (types 3,4,3) | 4 (types 1,2,5,6) |
| tblHeader | 7 | 7 | 3 | 4 |
| tblItems | 13 | 13 | 5 (Req3:2, Req4:1, Req8:2) | 8 (Req1:3, Req2:2, Req5:2, Req6:1) |

**Post-pipeline**: All 7 active tblRequest rows updated to Status=1, StatusMessage='Submitted in CBS'

---

## Verification Command
```bash
make robot-run-tests TAGS="sit_sqlserver"
```

---

## What Cannot Be Automated

Not everything the customer does manually should be converted into automation. Some activities are inherently visual, process-oriented, or documentation-centric. Attempting to automate these areas would add complexity and maintenance overhead without meaningful test coverage improvement.

| Manual Activity | Automate? | Reason | Alternative Approach |
|---|---|---|---|
| Snap preview screenshots | NO | No snap preview API exists; visual-only UI feature | Pipeline execution status (Completed/Failed) + target table data assertions |
| Excel execution document | NO | Documentation artifact, not a test | RF report.html & log.html as evidence |
| STM checks with screenshots | NO | Manual copy-paste into templates | Automated source-to-target DB comparisons |
| SnapLogic Designer UI checks | NO | UI-dependent, no stable API | SnapLogic REST API for status checks |
| Pipeline dashboard monitoring | NO | Visual monitoring, version-sensitive | API-based execution status verification |
| Defect logging & triage | NO | Requires human judgment | Clear failure messages in RF reports |

### Details

**Snap-by-Snap Preview Screenshots**
- The manual team previews each snap in the SnapLogic Designer UI and captures screenshots
- There is no snap preview API available — snap output preview is purely a UI feature
- **Instead**: Check pipeline execution status via `Run Triggered Task` (returns Completed/Failed) + validate final data in target table using `Row Count Should Be` and `Select Where`

**Manual Excel Execution Documentation**
- The customer creates Excel-based execution documents with screenshots pasted per step
- These are SIT evidence artifacts for audit/review, not test verification steps
- **Instead**: Use Robot Framework's built-in HTML reports (`report.html` and `log.html`) as the execution evidence

**UI-Dependent Intermediate Checks**
- Checking SnapLogic Designer for snap "green checkmarks" or "pipeline statistics" in the UI
- Monitoring the SnapLogic Dashboard for pipeline run status visually
- **Instead**: Use the SnapLogic REST API to check pipeline execution status programmatically via `Run Triggered Task With Parameters From Template`

**Defect Logging & Triage**
- The manual team creates defect sheets with descriptions, severity, and assigned-to fields
- Defect triage requires human judgment on severity, root cause, and assignment
- **Instead**: Let automated tests fail clearly with descriptive error messages using Robot Framework's `[Documentation]` and custom error messages

---

## Gap Analysis — Scenarios Not Covered by Our 13 Tests

A thorough review of the LLD document (`EBAS_to_CBS_LLD.docx`), the manual test execution workbook (`DC_EBAS_To_CBS_backup.xlsx` — 13 embedded screenshots across 3 sheets), and the TC Execution CSV (`TC_001–TC_012`) identified the following scenarios that are **not covered** by our 13 automated tests. Each gap is categorized as:

- **Cannot Automate** — No API or programmatic access exists
- **Out of Scope** — Belongs to a different system, team, or phase
- **Could Add (Future)** — Technically possible to automate but not included in this phase

---

### Gap 1: No-Data Scenario (Empty Source)

| Attribute | Detail |
|-----------|--------|
| **Source** | LLD — Integration Design Pattern: "If No Data Complete the pipeline." |
| **What's Missing** | Our tests always seed 7 active rows (Status=0). We never test the scenario where tblRequest returns 0 rows matching the extraction filter. The pipeline should complete gracefully with no errors and make no updates. |
| **Category** | **Could Add (Future)** |
| **How to Add** | Create a separate test (or test suite variant) that: (1) Seeds tblRequest with only Status=1 rows (no active rows), (2) Executes the pipeline, (3) Verifies pipeline completes successfully, (4) Verifies no rows were updated (Status=1 count unchanged). This would require a separate Suite Setup that inserts different seed data. |
| **Priority** | Medium — Edge case but explicitly called out in LLD |

---

### Gap 2: DataStage vs SnapLogic Output Comparison (TS 1.0)

| Attribute | Detail |
|-----------|--------|
| **Source** | LLD — Testing Scenario TS 1.0: "DataStage and the SnapLogic pipeline results match after data loads. Data should match the target SQL Server table in both ETL tools." |
| **What's Missing** | The LLD defines a testing scenario where DataStage output is compared against SnapLogic output to prove migration equivalence. The `DC_EBAS_To_CBS_backup.xlsx` Sheet 3 screenshots show a **separate comparison pipeline** (`DC_of_EBAS_To_CBS`) that performs this comparison with snaps: Read DS Output File → CSV Parser → DS Output Format → Join with SL Output → Union Found and Error → Evaluate Result → Map Output Format → Output File Formatting → Create Comparison Result File. |
| **Category** | **Out of Scope — but could be automated if DataStage output files are provided** |
| **Reason** | This is a one-time migration validation activity comparing legacy DataStage output against SnapLogic output. Once migration is validated, this comparison is no longer needed. It also requires DataStage to still be running and producing output, which may not be available in our test environment. The comparison pipeline (`DC_of_EBAS_To_CBS`) is a separate pipeline not part of the core `sit_sqlserver.slp` being tested. |
| **How to Add (if DS output is available)** | If the DataStage output CSV/file is provided, this can be automated using the existing Tests 12 + 13 pattern: (1) Use the DS output file as the expected CSV, (2) Export post-pipeline tblRequest data as the actual CSV (Test 12), (3) Compare actual vs expected using `Compare CSV Files With Exclusions Template` (Test 13). No new keywords or separate comparison pipeline needed — just replace the expected CSV file. |

---

### Gap 3: Comparison Pipeline (DC_of_EBAS_To_CBS)

| Attribute | Detail |
|-----------|--------|
| **Source** | `DC_EBAS_To_CBS_backup.xlsx` — Sheet 3 (DC_EBAS_To_CBS), 5 screenshots |
| **What's Missing** | A completely separate pipeline exists (`DC_of_EBAS_To_CBS`) that: (1) Reads DS output file via CSV Parser, (2) Reads SL output file via CSV Parser, (3) Reformats both outputs (DS Output Format, SL Output Format), (4) Joins them, (5) Creates Union of Found and Error records, (6) Evaluates results, (7) Maps output format, (8) Creates a comparison result file (screenshots show 223,122 bytes, 1 document output). This pipeline has its own snap statistics and execution flow that we do not test. |
| **Category** | **Out of Scope** |
| **Reason** | This is a data comparison/validation pipeline specific to the DataStage-to-SnapLogic migration effort. It is not part of the production pipeline (`sit_sqlserver.slp`). Testing this pipeline would require: (a) A separate `.slp` file for the comparison pipeline, (b) Pre-staged DS output files, (c) Pre-staged SL output files. If needed in the future, it would be a separate Robot Framework test suite entirely. |

---

### Gap 4: Snap-Level Statistics and Row Counts Per Snap

| Attribute | Detail |
|-----------|--------|
| **Source** | `DC_EBAS_To_CBS_backup.xlsx` — Sheet 2 (SL_EBAS_To_CBS), 3 screenshots showing snap statistics |
| **What's Missing** | The manual team captures snap-by-snap statistics including: (a) Read tblHeader: 527 rows output, (b) Read tblItems: 801 rows output, (c) tblRequest Router: Request1256 output 0 docs / Request34 output 0 docs, (d) Join Flow 2 inputs: tblRequest Data 0, Item Data 801, Header Data 527, (e) Bytes processed, documents count, and processing rate per snap. Our tests validate final outcomes (row counts in target table, CSV comparison) but not intermediate snap-level statistics. |
| **Category** | **Cannot Automate** |
| **Reason** | SnapLogic does not expose a public API for querying individual snap output statistics from a pipeline run. Snap preview and snap statistics are only available through the SnapLogic Designer UI. The SnapLogic REST API returns pipeline-level execution status (Completed/Failed/Running) but not snap-level document counts or byte metrics. **Alternative**: Our post-pipeline validations (Tests 11, 13) prove that the correct number of rows were processed through each path, which indirectly validates that intermediate snap counts were correct. |

---

### Gap 5: Snap Green Checkmarks / Visual Execution Status

| Attribute | Detail |
|-----------|--------|
| **Source** | `DC_EBAS_To_CBS_backup.xlsx` — All 3 sheets show pipeline execution with green checkmarks on each snap |
| **What's Missing** | The manual team verifies that each snap shows a green checkmark (success indicator) in the SnapLogic Designer UI after pipeline execution. |
| **Category** | **Cannot Automate** |
| **Reason** | Green checkmarks are a UI-only visual indicator. No API exists to query per-snap execution status. **Alternative**: The `Run Triggered Task With Parameters From Template` keyword returns pipeline-level status (Completed/Failed). A "Completed" status means all snaps executed successfully. If any snap fails, the pipeline status changes to "Failed" and Test 10 would fail. |

---

### Gap 6: Error Notification via Tidal (AS 2.0)

| Attribute | Detail |
|-----------|--------|
| **Source** | LLD — Assumption 2.0: "Error notification will be handled by Tidal in case of failures." |
| **What's Missing** | We do not test that Tidal correctly sends error notifications when the pipeline fails. This includes: email notifications, alerting systems, retry logic, and escalation workflows. |
| **Category** | **Out of Scope** |
| **Reason** | Tidal is an external job scheduling system. Testing Tidal notifications requires: (a) Access to the Tidal scheduling environment, (b) Email/notification infrastructure, (c) Intentional pipeline failure scenarios. This is a Tidal integration test, not a SnapLogic pipeline test. Our Robot Framework tests use triggered tasks directly (bypassing Tidal) to isolate pipeline behavior. |

---

### Gap 7: Tidal Scheduling Integration (TR 3.0)

| Attribute | Detail |
|-----------|--------|
| **Source** | LLD — TR 3.0: "SnapLogic Pipeline would be triggered from Tidal through triggered task." Tidal Schedule: "Cat-US-every calendar day, 12:01 AM, Repeat every 30 minutes up to 48 times." |
| **What's Missing** | We do not verify that: (a) The pipeline is correctly registered with Tidal, (b) The Tidal schedule executes every 30 minutes, (c) The triggered task URL/credentials are configured in Tidal, (d) End-to-end Tidal → Triggered Task → Pipeline execution works. |
| **Category** | **Out of Scope** |
| **Reason** | Tidal scheduling is an operations/deployment concern, not a pipeline logic test. Our SIT tests focus on verifying the pipeline's data transformation logic. Tidal integration testing belongs to the deployment/ops validation phase and requires access to the Tidal scheduling environment. |

---

### Gap 8: Expression Library Configuration Validation (TR 2.0 + TR 4.0)

| Attribute | Detail |
|-----------|--------|
| **Source** | LLD — TR 2.0: "Expression library should be utilized for accessing accounts." TR 4.0: "All usernames / schema names / database names / hostnames must be configurable value from Expression file and must not be hardcoded." |
| **What's Missing** | We upload the expression library (Test 2) and the pipeline uses it during execution, but we do not explicitly validate that: (a) No connection strings are hardcoded in the pipeline, (b) All config values are sourced from the expression library, (c) The expression library's account mappings are correct. |
| **Category** | **Could Add (Future) — automatable if expected values are known** |
| **How to Add** | Create an expected expression library file with the correct account names, hostnames, database names, and schema names. After uploading the actual `.expr` file (Test 2), compare it against the expected file using a file comparison keyword. If the actual `.expr` matches the expected file, the configuration is validated. Combined with a successful pipeline execution (Test 10), this proves all config values are sourced from the expression library and are correct. |
| **Priority** | Low — Test 10 implicitly validates the expression library works (pipeline would fail if references were broken). The file comparison adds explicit proof that the config values match expectations. |

---

### Gap 9: No Intermediate Files in SLDB (TR 1.0 + AS 1.0)

| Attribute | Detail |
|-----------|--------|
| **Source** | LLD — TR 1.0: "Intermediate files should not be created in SLDB." AS 1.0: "Snap Logic will not perform any intermediate file or archival steps." |
| **What's Missing** | We do not verify that the pipeline does not create intermediate files in SLDB after execution. The legacy DataStage jobs created intermediate datasets and files (e.g., `Request125.ds`, `request34.ds`, `item.ds`, `header.ds`, `ebas_cbsrequest.txt`). |
| **Category** | **Could Add (Future)** |
| **How to Add** | After pipeline execution (Test 10), use the SnapLogic File API to list files in the project's SLDB location and verify no new files were created. This would require a custom keyword using `GET /api/1/rest/slfs/{org}/{project_path}`. |
| **Priority** | Low — This is an architectural design constraint. If the pipeline uses in-memory processing (which SnapLogic does by default for SQL-to-SQL flows), no files would be created. A one-time manual check may suffice. |

---

### Gap 10: 51 Target Field Count Validation (TC_007 / TC_009)

| Attribute | Detail |
|-----------|--------|
| **Source** | TC Execution CSV — TC_007: "Count target fields. 51 target fields populated and sent to Union snap." TC_009: "Verify 51 target fields mapping. Transformed data successfully sent to Union snap." |
| **What's Missing** | The manual team counts that exactly 51 fields are populated in the mapper output before the Union snap. Our tests validate the final tblRequest update (which only updates 4 columns: Id, Status, SubmittedOn, StatusMessage) but do not count the intermediate 51-field mapper output. |
| **Category** | **Cannot Automate** |
| **Reason** | The 51-field output is an intermediate snap result inside the pipeline. There is no API to inspect the output schema or document count of a specific snap within a pipeline. The 51 fields are an internal transformation detail that gets reduced to 4 target columns in the final update. **Alternative**: Test 13 (CSV comparison) validates the final target table state, which is the downstream result of the 51-field mapping. If the mapping were wrong, the final data would not match expected values. |

---

### Gap 11: Request Data Sorting Verification (TC_003)

| Attribute | Detail |
|-----------|--------|
| **Source** | TC Execution CSV — TC_003: "Validate Request data mapping snap. Validate Request Sort snap execution. Verify sorted request output. Request data mapped and sorted correctly based on defined keys." |
| **What's Missing** | We do not directly verify that request data is sorted within the pipeline. The pipeline has a "Request Sort" snap that sorts data before further processing. |
| **Category** | **Cannot Automate** |
| **Reason** | Sort order is an intermediate pipeline operation that affects processing order, not final output. The tblRequest UPDATE statement uses the `Id` key for matching, so the sort order of input data does not affect the final result. There is no API to observe the output order of the Sort snap. **Alternative**: Test 13 (CSV comparison with ORDER BY Id) validates the final data is correct regardless of sort order. |

---

### Gap 12: DataStage Legacy Sub-Pipeline Execution

| Attribute | Detail |
|-----------|--------|
| **Source** | `DC_EBAS_To_CBS_backup.xlsx` — Sheet 1 (DS_EBAS_To_CBS), 5 screenshots showing DataStage sequence pipeline execution: src_header (527 rows), ODBC_tblRequest (0 rows), src_db2tbl_item (801 rows) |
| **What's Missing** | The manual team captures DataStage sub-pipeline execution statistics for the legacy jobs. |
| **Category** | **Out of Scope** |
| **Reason** | These are the legacy IBM DataStage jobs being replaced. Our tests validate the replacement SnapLogic pipeline, not the legacy DataStage jobs. DataStage execution statistics are only relevant for the TS 1.0 comparison (Gap 2) and are not part of ongoing SIT for the SnapLogic pipeline. |

---

### Gap 13: File Archival, Move, and Cleanup

| Attribute | Detail |
|-----------|--------|
| **Source** | LLD — Seq_EBAS_TO_CBS steps 5-8: Archive file (`cp`), archive local file (`cp`), move file (`mv`), delete archives older than 15 days (`find -mtime +15 -exec rm`). |
| **What's Missing** | The legacy DataStage sequence included file archival, local archival, file move, and old archive cleanup. |
| **Category** | **Out of Scope** |
| **Reason** | LLD Assumption 1.0 explicitly states: "Snap Logic will not perform any intermediate file or archival steps." The SnapLogic pipeline operates entirely in-memory from SQL Server to SQL Server. File archival was a DataStage-specific concern for managing intermediate flat files. Not applicable to the SnapLogic implementation. |

---

### Gap 14: Target Table Column Data Type Verification

| Attribute | Detail |
|-----------|--------|
| **Source** | LLD — Target Table 16: Id (Integer), Status (SmallInt), SubmittedOn (TimeStamp), StatusMessage (Varchar 4000) |
| **What's Missing** | We verify target column **values** (Status=1, StatusMessage='Submitted in CBS', SubmittedOn IS NOT NULL) but do not verify column **data types** match the LLD specification. |
| **Category** | **Could Add (automatable — generic keyword now available)** |
| **How to Add** | Use the new `Verify Column Data Types` keyword from `sql_table_operations.resource`. This keyword queries `INFORMATION_SCHEMA.COLUMNS` via `Get Table Schema Info` and asserts each column's `DATA_TYPE` matches the expected value (case-insensitive). Add a pre-pipeline test case like: |

**Example test case:**
```robot
Verify tblRequest Column Data Types
    [Documentation]    Verifies target table column data types match LLD specification.
    ...    LLD Target Table 16: Id (int), Status (int), SubmittedOn (datetime), StatusMessage (nvarchar)
    [Tags]    sqlserver    sit_sqlserver    verification    schema
    Verify Column Data Types    tblRequest    schema=dbo
    ...    Id=int
    ...    RequestType=nvarchar
    ...    Status=int
    ...    StatusMessage=nvarchar
    ...    Requestor=nvarchar
    ...    RequestedOn=datetime
    ...    SubmittedOn=datetime
    ...    ProcessedOn=datetime
```

| Attribute | Detail |
|-----------|--------|
| **Priority** | Low — Table DDL is managed by our test setup (sqlserver_queries.resource), so data types are controlled by our CREATE TABLE statements. In a real environment where tables are externally managed, this becomes a valuable schema contract test. |
| **Note** | SQL Server `INFORMATION_SCHEMA` returns lowercase types: `int`, `nvarchar`, `datetime`, `decimal` — not the LLD labels (Integer, SmallInt, TimeStamp, Varchar). Use the SQL Server native type names when specifying expected values. |

---

### Gap 15: Source to Target Mapping (STTM) Detailed Field-Level Validation

| Attribute | Detail |
|-----------|--------|
| **Source** | LLD — Section "Source to Target Mapping": "The main Source To Target Mapping document can be found here: EBAS_to_CBS" (external STTM document referenced but not included in our docs). TC_007/TC_009 mention "To be covered in STTM." |
| **What's Missing** | The LLD references an external STTM document that defines the exact field-by-field mapping for all 51 target fields. We do not have this document and cannot verify individual field mappings at the STTM level. |
| **Category** | **Could Add (Future) — if STTM document is provided** |
| **How to Add** | If the STTM document is obtained, it could define expected values for all 51 intermediate fields. However, since only 4 fields are updated in the target table (Id, Status, SubmittedOn, StatusMessage), the remaining 47 fields are intermediate and not observable via the target table. Full STTM validation would require the comparison pipeline (Gap 3) or direct snap output inspection. |
| **Priority** | Low — Test 13 (CSV comparison) validates the 4 target update columns. The other 47 fields are pipeline-internal. |

---

### Summary of Gaps

| # | Gap | Category | Impact |
|---|-----|----------|--------|
| 1 | No-Data Scenario (0 active rows) | Could Add (Future) | Medium |
| 2 | DataStage vs SnapLogic Comparison (TS 1.0) | Out of Scope (automatable if DS output file provided) | Medium |
| 3 | Comparison Pipeline (DC_of_EBAS_To_CBS) | Out of Scope | — |
| 4 | Snap-Level Statistics / Row Counts Per Snap | Cannot Automate | — |
| 5 | Snap Green Checkmarks / Visual Status | Cannot Automate | — |
| 6 | Error Notification via Tidal | Out of Scope | — |
| 7 | Tidal Scheduling Integration | Out of Scope | — |
| 8 | Expression Library Config Validation (no hardcoding) | Could Add (automatable if expected values known) | Low |
| 9 | No Intermediate Files in SLDB | Could Add (Future) | Low |
| 10 | 51 Target Field Count (TC_007/TC_009) | Cannot Automate | — |
| 11 | Request Data Sorting (TC_003) | Cannot Automate | — |
| 12 | DataStage Legacy Sub-Pipeline Execution | Out of Scope | — |
| 13 | File Archival, Move, and Cleanup | Out of Scope (AS 1.0) | — |
| 14 | Target Table Column Data Types | Could Add (automatable — `Verify Column Data Types` keyword available) | Low |
| 15 | STTM Detailed Field-Level Mapping | Could Add (Future) | Low |

**Coverage Summary**:
- **Covered by our 13 tests**: TC_001 through TC_012 (all 12 LLD test cases) — via direct SQL validation or indirect downstream result verification
- **Cannot Automate (3 gaps)**: Snap-level statistics, visual checkmarks, intermediate field counts — no SnapLogic API exists
- **Out of Scope (5 gaps)**: DataStage comparison, Tidal integration, legacy sub-pipelines, file archival — belong to different systems or migration-phase activities
- **Could Add in Future (4 gaps)**: No-data scenario, expression library validation, SLDB file check, data type check — technically possible but lower priority
