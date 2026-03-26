# Pipeline Validation — Batch Review Report

**Generated:** 2026-03-26 18:49:05
**Pipelines Reviewed:** 26
**Passed:** 0
**Failed:** 26

---

## Summary

| # | Pipeline | File | Status | Failed Checks |
|---|---|---|:---:|---|
| 1 | kafka_snowflake_child_pipeline2_20251110203439149700 | child_pipeline1.slp | FAIL | snap_naming, pipeline_naming, parameter_capture, doc_link, notes |
| 2 | TAPP102550_Asset_Brokerage_Delay_Ack_Ingestion | child_pipeline2.slp | FAIL | snap_naming, pipeline_naming, parameter_capture, doc_link, notes |
| 3 | db2 | db2.slp | FAIL | snap_naming, pipeline_naming, parameter_capture, doc_link, notes |
| 4 | mail_slp | email.slp | FAIL | snap_naming, pipeline_naming, parameter_capture, doc_link, notes |
| 5 | filereader_20251126013733600655 | filereader.slp | FAIL | snap_naming, pipeline_naming, parameter_capture, doc_link, notes |
| 6 | Mount_Or_Snaplex_folder_poc | filereader_writer_mount_files.slp | FAIL | snap_naming, pipeline_naming, doc_link, notes |
| 7 | jmsconsumer_20250627194741286086 | jmsconsumer.slp | FAIL | snap_naming, pipeline_naming, parameter_capture, doc_link, notes |
| 8 | Kafka | kafka.slp | FAIL | snap_naming, pipeline_naming, parameter_capture, doc_link, notes |
| 9 | mysql_20251009150554245743 | mysql.slp | FAIL | snap_naming, pipeline_naming, parameter_capture, doc_link, notes |
| 10 | oracle_20251008063112437816 | oracle.slp | FAIL | snap_naming, duplicate_snap_names, pipeline_naming, parameter_capture, doc_link, notes |
| 11 | oracle2 | oracle2.slp | FAIL | snap_naming, pipeline_naming, doc_link, notes |
| 12 | 2CMS Rebate Extract Pipeline2 | oracle_cms_rebate.slp | FAIL | snap_naming, pipeline_naming, parameter_capture, doc_link, notes |
| 13 | kafka_snowflake_parent_pl_20251110203439149700 | parent_pipeline1.slp | FAIL | snap_naming, duplicate_snap_names, pipeline_naming, parameter_capture, doc_link, notes |
| 14 | postgres_s3_csv_20250605003727074993 | postgres_oracle.slp | FAIL | snap_naming, pipeline_naming, parameter_capture, doc_link, notes |
| 15 | postgres_s3_20250603153223127531 | postgres_to_s3_csv.slp | FAIL | snap_naming, pipeline_naming, parameter_capture, doc_link, notes |
| 16 | postgres_s3_json_20250605003727074993 | postgres_to_s3_json.slp | FAIL | snap_naming, pipeline_naming, parameter_capture, doc_link, notes |
| 17 | sfdc | salesforce.slp | FAIL | snap_naming, pipeline_naming, parameter_capture, account_reference_format, doc_link, notes |
| 18 | salesforce_accounts_20260225235923397284 | salesforce_accounts.slp | FAIL | snap_naming, pipeline_naming, parameter_capture, doc_link, notes |
| 19 | sit_pipeline | sit_sqlserver.slp | FAIL | snap_naming, pipeline_naming, doc_link, notes |
| 20 | Basic Use Case - Script Snap(Working) | sla_pipeline.slp | FAIL | snap_naming, pipeline_naming, doc_link, notes |
| 21 | snowflake_20251006194710436694 | snowflake.slp | FAIL | snap_naming, pipeline_naming, parameter_capture, doc_link, notes |
| 22 | snowflake_20251007065035853459 | snowflake1.slp | FAIL | snap_naming, pipeline_naming, parameter_capture, doc_link, notes |
| 23 | snowflake_20251007065035853459 | snowflake2.slp | FAIL | snap_naming, pipeline_naming, parameter_capture, doc_link, notes |
| 24 | snowflake_keypair_20251126183711459164 | snowflake_keypair.slp | FAIL | snap_naming, pipeline_naming, parameter_capture, doc_link, notes |
| 25 | snowflake_user_password_auth_20251125201248568545 | snowflake_user_password_auth.slp | FAIL | snap_naming, pipeline_naming, parameter_capture, doc_link, notes |
| 26 | sqlserver_20250731192144680328 | sqlserver.slp | FAIL | snap_naming, pipeline_naming, parameter_capture, doc_link, notes |

---

## Detailed Results

### kafka_snowflake_child_pipeline2_20251110203439149700 (`child_pipeline1.slp`)

**Overall Status:** FAIL

| Passed | Failed | Skipped |
|:---:|:---:|:---:|
| 3 | 5 | 2 |

| Check | Status | Details |
|---|:---:|---|
| Snap Naming | FAIL | Snap name 'Pipeline Execute' is a known default name |
| Duplicate Snap Names | PASS | — |
| Pipeline Naming | FAIL | Pipeline name 'kafka_snowflake_child_pipeline2_20251110203439149700' does not contain required project name 'sl_project' |
| Child Pipeline Naming | SKIP | Not a child pipeline — z_ prefix check skipped |
| Parameter Capture | FAIL | Parameter 'snf_rsa_private_key' does not have Capture enabled; Parameter 'snf_rsa_passphrase' does not have Capture enabled; Parameter 'msk_cross_account_iam' does not have Capture enabled; Parameter 'msk_cross_account_external_key' does not have Capture enabled; Parameter 'DDP_Email_Secret_ID' does not have Capture enabled; ... and 2 more |
| Parameter Prefix | SKIP | Parent pipelines are exempt from parameter prefix requirement |
| Accounts Not Hardcoded | PASS | — |
| Account Reference Format | PASS | — |
| Doc Link | FAIL | Pipeline Info > Doc Link is empty. New pipelines must have the User Story URL linked. |
| Notes | FAIL | Pipeline Info > Notes is empty. Modified pipelines should have the ticket number in Notes. |

---

### TAPP102550_Asset_Brokerage_Delay_Ack_Ingestion (`child_pipeline2.slp`)

**Overall Status:** FAIL

| Passed | Failed | Skipped |
|:---:|:---:|:---:|
| 3 | 5 | 2 |

| Check | Status | Details |
|---|:---:|---|
| Snap Naming | FAIL | Snap name 'JSON Splitter' is a known default name; Snap name 'Copy' is a known default name; Snap name 'Join' is a known default name; Snap name 'JSON Splitter2' appears to be a numbered default; Snap name 'Mapper1' appears to be a numbered default; ... and 5 more |
| Duplicate Snap Names | PASS | — |
| Pipeline Naming | FAIL | Pipeline name 'TAPP102550_Asset_Brokerage_Delay_Ack_Ingestion' does not contain required project name 'sl_project' |
| Child Pipeline Naming | SKIP | Not a child pipeline — z_ prefix check skipped |
| Parameter Capture | FAIL | Parameter 'snf_rsa_private_key' does not have Capture enabled; Parameter 'snf_rsa_passphrase' does not have Capture enabled |
| Parameter Prefix | SKIP | Parent pipelines are exempt from parameter prefix requirement |
| Accounts Not Hardcoded | PASS | — |
| Account Reference Format | PASS | — |
| Doc Link | FAIL | Pipeline Info > Doc Link is empty. New pipelines must have the User Story URL linked. |
| Notes | FAIL | Pipeline Info > Notes is empty. Modified pipelines should have the ticket number in Notes. |

---

### db2 (`db2.slp`)

**Overall Status:** FAIL

| Passed | Failed | Skipped |
|:---:|:---:|:---:|
| 3 | 5 | 2 |

| Check | Status | Details |
|---|:---:|---|
| Snap Naming | FAIL | Snap name 'Generic JDBC - Select' is a known default name; Snap name 'CSV Formatter' is a known default name; Snap name 'File Writer' is a known default name |
| Duplicate Snap Names | PASS | — |
| Pipeline Naming | FAIL | Pipeline name 'db2' does not contain required project name 'sl_project' |
| Child Pipeline Naming | SKIP | Not a child pipeline — z_ prefix check skipped |
| Parameter Capture | FAIL | Parameter 'db2_acct' does not have Capture enabled; Parameter 'schema_name' does not have Capture enabled; Parameter 'table_name' does not have Capture enabled |
| Parameter Prefix | SKIP | Parent pipelines are exempt from parameter prefix requirement |
| Accounts Not Hardcoded | PASS | — |
| Account Reference Format | PASS | — |
| Doc Link | FAIL | Pipeline Info > Doc Link is empty. New pipelines must have the User Story URL linked. |
| Notes | FAIL | Pipeline Info > Notes is empty. Modified pipelines should have the ticket number in Notes. |

---

### mail_slp (`email.slp`)

**Overall Status:** FAIL

| Passed | Failed | Skipped |
|:---:|:---:|:---:|
| 3 | 5 | 2 |

| Check | Status | Details |
|---|:---:|---|
| Snap Naming | FAIL | Snap name 'Email Sender' is a known default name |
| Duplicate Snap Names | PASS | — |
| Pipeline Naming | FAIL | Pipeline name 'mail_slp' does not contain required project name 'sl_project' |
| Child Pipeline Naming | SKIP | Not a child pipeline — z_ prefix check skipped |
| Parameter Capture | FAIL | Parameter 'EMAIL_ACCT' does not have Capture enabled; Parameter 'TEST_FROM_EMAIL' does not have Capture enabled; Parameter 'TEST_TO_EMAIL' does not have Capture enabled; Parameter 'TEST_CC_EMAIL' does not have Capture enabled; Parameter 'TEST_BCC_EMAIL' does not have Capture enabled; ... and 2 more |
| Parameter Prefix | SKIP | Parent pipelines are exempt from parameter prefix requirement |
| Accounts Not Hardcoded | PASS | — |
| Account Reference Format | PASS | — |
| Doc Link | FAIL | Pipeline Info > Doc Link is empty. New pipelines must have the User Story URL linked. |
| Notes | FAIL | Pipeline Info > Notes is empty. Modified pipelines should have the ticket number in Notes. |

---

### filereader_20251126013733600655 (`filereader.slp`)

**Overall Status:** FAIL

| Passed | Failed | Skipped |
|:---:|:---:|:---:|
| 3 | 5 | 2 |

| Check | Status | Details |
|---|:---:|---|
| Snap Naming | FAIL | Snap name 'File Reader' is a known default name |
| Duplicate Snap Names | PASS | — |
| Pipeline Naming | FAIL | Pipeline name 'filereader_20251126013733600655' does not contain required project name 'sl_project' |
| Child Pipeline Naming | SKIP | Not a child pipeline — z_ prefix check skipped |
| Parameter Capture | FAIL | Parameter 'test_json_file' does not have Capture enabled |
| Parameter Prefix | SKIP | Parent pipelines are exempt from parameter prefix requirement |
| Accounts Not Hardcoded | PASS | — |
| Account Reference Format | PASS | — |
| Doc Link | FAIL | Pipeline Info > Doc Link is empty. New pipelines must have the User Story URL linked. |
| Notes | FAIL | Pipeline Info > Notes is empty. Modified pipelines should have the ticket number in Notes. |

---

### Mount_Or_Snaplex_folder_poc (`filereader_writer_mount_files.slp`)

**Overall Status:** FAIL

| Passed | Failed | Skipped |
|:---:|:---:|:---:|
| 4 | 4 | 2 |

| Check | Status | Details |
|---|:---:|---|
| Snap Naming | FAIL | Snap name 'File Reader' is a known default name; Snap name 'File Writer' is a known default name |
| Duplicate Snap Names | PASS | — |
| Pipeline Naming | FAIL | Pipeline name 'Mount_Or_Snaplex_folder_poc' does not contain required project name 'sl_project' |
| Child Pipeline Naming | SKIP | Not a child pipeline — z_ prefix check skipped |
| Parameter Capture | PASS | — |
| Parameter Prefix | SKIP | Parent pipelines are exempt from parameter prefix requirement |
| Accounts Not Hardcoded | PASS | — |
| Account Reference Format | PASS | — |
| Doc Link | FAIL | Pipeline Info > Doc Link is empty. New pipelines must have the User Story URL linked. |
| Notes | FAIL | Pipeline Info > Notes is empty. Modified pipelines should have the ticket number in Notes. |

---

### jmsconsumer_20250627194741286086 (`jmsconsumer.slp`)

**Overall Status:** FAIL

| Passed | Failed | Skipped |
|:---:|:---:|:---:|
| 3 | 5 | 2 |

| Check | Status | Details |
|---|:---:|---|
| Snap Naming | FAIL | Snap name 'JMS Consumer' is a known default name; Snap name 'File Writer' is a known default name; Snap name 'JSON Parser' is a known default name; Snap name 'JSON Formatter' is a known default name |
| Duplicate Snap Names | PASS | — |
| Pipeline Naming | FAIL | Pipeline name 'jmsconsumer_20250627194741286086' does not contain required project name 'sl_project' |
| Child Pipeline Naming | SKIP | Not a child pipeline — z_ prefix check skipped |
| Parameter Capture | FAIL | Parameter 'JMS_Slim_Account' does not have Capture enabled; Parameter 'M_CURR_DATE' does not have Capture enabled; Parameter 'DOMAIN_NAME' does not have Capture enabled |
| Parameter Prefix | SKIP | Parent pipelines are exempt from parameter prefix requirement |
| Accounts Not Hardcoded | PASS | — |
| Account Reference Format | PASS | — |
| Doc Link | FAIL | Pipeline Info > Doc Link is empty. New pipelines must have the User Story URL linked. |
| Notes | FAIL | Pipeline Info > Notes is empty. Modified pipelines should have the ticket number in Notes. |

---

### Kafka (`kafka.slp`)

**Overall Status:** FAIL

| Passed | Failed | Skipped |
|:---:|:---:|:---:|
| 3 | 5 | 2 |

| Check | Status | Details |
|---|:---:|---|
| Snap Naming | FAIL | Snap name 'Kafka Producer' is a known default name; Snap name 'JSON Generator' is a known default name |
| Duplicate Snap Names | PASS | — |
| Pipeline Naming | FAIL | Pipeline name 'Kafka' does not contain required project name 'sl_project' |
| Child Pipeline Naming | SKIP | Not a child pipeline — z_ prefix check skipped |
| Parameter Capture | FAIL | Parameter 'kafka_acct' does not have Capture enabled; Parameter 'topic' does not have Capture enabled; Parameter 'partition_number' does not have Capture enabled; Parameter 'botstrap_server' does not have Capture enabled; Parameter 'message_key' does not have Capture enabled; ... and 1 more |
| Parameter Prefix | SKIP | Parent pipelines are exempt from parameter prefix requirement |
| Accounts Not Hardcoded | PASS | — |
| Account Reference Format | PASS | — |
| Doc Link | FAIL | Pipeline Info > Doc Link is empty. New pipelines must have the User Story URL linked. |
| Notes | FAIL | Pipeline Info > Notes is empty. Modified pipelines should have the ticket number in Notes. |

---

### mysql_20251009150554245743 (`mysql.slp`)

**Overall Status:** FAIL

| Passed | Failed | Skipped |
|:---:|:---:|:---:|
| 3 | 5 | 2 |

| Check | Status | Details |
|---|:---:|---|
| Snap Naming | FAIL | Snap name 'MySQL - Select' is a known default name; Snap name 'CSV Formatter' is a known default name; Snap name 'File Writer' is a known default name |
| Duplicate Snap Names | PASS | — |
| Pipeline Naming | FAIL | Pipeline name 'mysql_20251009150554245743' does not contain required project name 'sl_project' |
| Child Pipeline Naming | SKIP | Not a child pipeline — z_ prefix check skipped |
| Parameter Capture | FAIL | Parameter 'USER' does not have Capture enabled; Parameter 'NAME_CD_1' does not have Capture enabled; Parameter 'NAME_CD_2' does not have Capture enabled; Parameter 'DOMAIN_NAME' does not have Capture enabled; Parameter 'M_CURR_DATE' does not have Capture enabled; ... and 1 more |
| Parameter Prefix | SKIP | Parent pipelines are exempt from parameter prefix requirement |
| Accounts Not Hardcoded | PASS | — |
| Account Reference Format | PASS | — |
| Doc Link | FAIL | Pipeline Info > Doc Link is empty. New pipelines must have the User Story URL linked. |
| Notes | FAIL | Pipeline Info > Notes is empty. Modified pipelines should have the ticket number in Notes. |

---

### oracle_20251008063112437816 (`oracle.slp`)

**Overall Status:** FAIL

| Passed | Failed | Skipped |
|:---:|:---:|:---:|
| 2 | 6 | 2 |

| Check | Status | Details |
|---|:---:|---|
| Snap Naming | FAIL | Snap name 'Oracle - Execute' is a known default name; Snap name 'Oracle - Execute' is a known default name |
| Duplicate Snap Names | FAIL | — |
| Pipeline Naming | FAIL | Pipeline name 'oracle_20251008063112437816' does not contain required project name 'sl_project' |
| Child Pipeline Naming | SKIP | Not a child pipeline — z_ prefix check skipped |
| Parameter Capture | FAIL | Parameter 'USER' does not have Capture enabled; Parameter 'NAME_CD_1' does not have Capture enabled; Parameter 'NAME_CD_2' does not have Capture enabled; Parameter 'DOMAIN_NAME' does not have Capture enabled; Parameter 'M_CURR_DATE' does not have Capture enabled; ... and 1 more |
| Parameter Prefix | SKIP | Parent pipelines are exempt from parameter prefix requirement |
| Accounts Not Hardcoded | PASS | — |
| Account Reference Format | PASS | — |
| Doc Link | FAIL | Pipeline Info > Doc Link is empty. New pipelines must have the User Story URL linked. |
| Notes | FAIL | Pipeline Info > Notes is empty. Modified pipelines should have the ticket number in Notes. |

---

### oracle2 (`oracle2.slp`)

**Overall Status:** FAIL

| Passed | Failed | Skipped |
|:---:|:---:|:---:|
| 4 | 4 | 2 |

| Check | Status | Details |
|---|:---:|---|
| Snap Naming | FAIL | Snap name 'Data Validator' is a known default name; Snap name 'Filter' is a known default name; Snap name 'Structure' is a known default name; Snap name 'File Writer' is a known default name; Snap name 'CSV Formatter' is a known default name; ... and 1 more |
| Duplicate Snap Names | PASS | — |
| Pipeline Naming | FAIL | Pipeline name 'oracle2' does not contain required project name 'sl_project' |
| Child Pipeline Naming | SKIP | Not a child pipeline — z_ prefix check skipped |
| Parameter Capture | PASS | — |
| Parameter Prefix | SKIP | Parent pipelines are exempt from parameter prefix requirement |
| Accounts Not Hardcoded | PASS | — |
| Account Reference Format | PASS | — |
| Doc Link | FAIL | Pipeline Info > Doc Link is empty. New pipelines must have the User Story URL linked. |
| Notes | FAIL | Pipeline Info > Notes is empty. Modified pipelines should have the ticket number in Notes. |

---

### 2CMS Rebate Extract Pipeline2 (`oracle_cms_rebate.slp`)

**Overall Status:** FAIL

| Passed | Failed | Skipped |
|:---:|:---:|:---:|
| 3 | 5 | 2 |

| Check | Status | Details |
|---|:---:|---|
| Snap Naming | FAIL | Snap name 'Oracle - Select' is a known default name; Snap name 'Router' is a known default name; Snap name 'File Writer' is a known default name; Snap name 'Oracle - Insert' is a known default name; Snap name 'JSON Formatter' is a known default name; ... and 1 more |
| Duplicate Snap Names | PASS | — |
| Pipeline Naming | FAIL | Pipeline name '2CMS Rebate Extract Pipeline2' does not contain required project name 'sl_project' |
| Child Pipeline Naming | SKIP | Not a child pipeline — z_ prefix check skipped |
| Parameter Capture | FAIL | Parameter 'oracle_acct' does not have Capture enabled |
| Parameter Prefix | SKIP | Parent pipelines are exempt from parameter prefix requirement |
| Accounts Not Hardcoded | PASS | — |
| Account Reference Format | PASS | — |
| Doc Link | FAIL | Pipeline Info > Doc Link is empty. New pipelines must have the User Story URL linked. |
| Notes | FAIL | Pipeline Info > Notes is empty. Modified pipelines should have the ticket number in Notes. |

---

### kafka_snowflake_parent_pl_20251110203439149700 (`parent_pipeline1.slp`)

**Overall Status:** FAIL

| Passed | Failed | Skipped |
|:---:|:---:|:---:|
| 2 | 6 | 2 |

| Check | Status | Details |
|---|:---:|---|
| Snap Naming | FAIL | Snap name 'Pipeline Execute' is a known default name; Snap name 'Union' is a known default name; Snap name 'Binary to Document' is a known default name; Snap name 'Binary to Document' is a known default name; Snap name 'Document to Binary' is a known default name; ... and 2 more |
| Duplicate Snap Names | FAIL | — |
| Pipeline Naming | FAIL | Pipeline name 'kafka_snowflake_parent_pl_20251110203439149700' does not contain required project name 'sl_project' |
| Child Pipeline Naming | SKIP | Not a child pipeline — z_ prefix check skipped |
| Parameter Capture | FAIL | Parameter 'cross_account_role_arn' does not have Capture enabled; Parameter 'cross_account_external_id' does not have Capture enabled; Parameter 'ca_cert_path' does not have Capture enabled; Parameter 'ca_cert_key_path' does not have Capture enabled; Parameter 'child_pipeline1' does not have Capture enabled; ... and 1 more |
| Parameter Prefix | SKIP | Parent pipelines are exempt from parameter prefix requirement |
| Accounts Not Hardcoded | PASS | — |
| Account Reference Format | PASS | — |
| Doc Link | FAIL | Pipeline Info > Doc Link is empty. New pipelines must have the User Story URL linked. |
| Notes | FAIL | Pipeline Info > Notes is empty. Modified pipelines should have the ticket number in Notes. |

---

### postgres_s3_csv_20250605003727074993 (`postgres_oracle.slp`)

**Overall Status:** FAIL

| Passed | Failed | Skipped |
|:---:|:---:|:---:|
| 3 | 5 | 2 |

| Check | Status | Details |
|---|:---:|---|
| Snap Naming | FAIL | Snap name 'PostgreSQL - Select' is a known default name; Snap name 'Oracle - Insert' is a known default name |
| Duplicate Snap Names | PASS | — |
| Pipeline Naming | FAIL | Pipeline name 'postgres_s3_csv_20250605003727074993' does not contain required project name 'sl_project' |
| Child Pipeline Naming | SKIP | Not a child pipeline — z_ prefix check skipped |
| Parameter Capture | FAIL | Parameter 'postgresAcct' does not have Capture enabled; Parameter 's3Acct' does not have Capture enabled; Parameter 'bucket' does not have Capture enabled; Parameter 'actual_output_file' does not have Capture enabled |
| Parameter Prefix | SKIP | Parent pipelines are exempt from parameter prefix requirement |
| Accounts Not Hardcoded | PASS | — |
| Account Reference Format | PASS | — |
| Doc Link | FAIL | Pipeline Info > Doc Link is empty. New pipelines must have the User Story URL linked. |
| Notes | FAIL | Pipeline Info > Notes is empty. Modified pipelines should have the ticket number in Notes. |

---

### postgres_s3_20250603153223127531 (`postgres_to_s3_csv.slp`)

**Overall Status:** FAIL

| Passed | Failed | Skipped |
|:---:|:---:|:---:|
| 3 | 5 | 2 |

| Check | Status | Details |
|---|:---:|---|
| Snap Naming | FAIL | Snap name 'PostgreSQL - Select' is a known default name; Snap name 'S3 Upload' is a known default name; Snap name 'CSV Formatter' is a known default name |
| Duplicate Snap Names | PASS | — |
| Pipeline Naming | FAIL | Pipeline name 'postgres_s3_20250603153223127531' does not contain required project name 'sl_project' |
| Child Pipeline Naming | SKIP | Not a child pipeline — z_ prefix check skipped |
| Parameter Capture | FAIL | Parameter 'postgresAcct' does not have Capture enabled; Parameter 's3Acct' does not have Capture enabled; Parameter 'bucket' does not have Capture enabled; Parameter 'actual_output_file' does not have Capture enabled |
| Parameter Prefix | SKIP | Parent pipelines are exempt from parameter prefix requirement |
| Accounts Not Hardcoded | PASS | — |
| Account Reference Format | PASS | — |
| Doc Link | FAIL | Pipeline Info > Doc Link is empty. New pipelines must have the User Story URL linked. |
| Notes | FAIL | Pipeline Info > Notes is empty. Modified pipelines should have the ticket number in Notes. |

---

### postgres_s3_json_20250605003727074993 (`postgres_to_s3_json.slp`)

**Overall Status:** FAIL

| Passed | Failed | Skipped |
|:---:|:---:|:---:|
| 3 | 5 | 2 |

| Check | Status | Details |
|---|:---:|---|
| Snap Naming | FAIL | Snap name 'PostgreSQL - Select' is a known default name; Snap name 'S3 Upload' is a known default name; Snap name 'JSON Formatter' is a known default name |
| Duplicate Snap Names | PASS | — |
| Pipeline Naming | FAIL | Pipeline name 'postgres_s3_json_20250605003727074993' does not contain required project name 'sl_project' |
| Child Pipeline Naming | SKIP | Not a child pipeline — z_ prefix check skipped |
| Parameter Capture | FAIL | Parameter 'postgresAcct' does not have Capture enabled; Parameter 's3Acct' does not have Capture enabled; Parameter 'bucket' does not have Capture enabled; Parameter 'actual_output_file' does not have Capture enabled |
| Parameter Prefix | SKIP | Parent pipelines are exempt from parameter prefix requirement |
| Accounts Not Hardcoded | PASS | — |
| Account Reference Format | PASS | — |
| Doc Link | FAIL | Pipeline Info > Doc Link is empty. New pipelines must have the User Story URL linked. |
| Notes | FAIL | Pipeline Info > Notes is empty. Modified pipelines should have the ticket number in Notes. |

---

### sfdc (`salesforce.slp`)

**Overall Status:** FAIL

| Passed | Failed | Skipped |
|:---:|:---:|:---:|
| 2 | 6 | 2 |

| Check | Status | Details |
|---|:---:|---|
| Snap Naming | FAIL | Snap name 'Salesforce Read' is a known default name; Snap name 'Salesforce Create' is a known default name; Snap name 'JSON Generator' is a known default name |
| Duplicate Snap Names | PASS | — |
| Pipeline Naming | FAIL | Pipeline name 'sfdc' does not contain required project name 'sl_project' |
| Child Pipeline Naming | SKIP | Not a child pipeline — z_ prefix check skipped |
| Parameter Capture | FAIL | Parameter 'sfdc_acct' does not have Capture enabled |
| Parameter Prefix | SKIP | Parent pipelines are exempt from parameter prefix requirement |
| Accounts Not Hardcoded | PASS | — |
| Account Reference Format | FAIL | Account parameter 'sfdc_acct' default value '../../shared/sfdc_acct' does not match expected pattern; Account parameter 'sfdc_acct' default value '../../shared/sfdc_acct' does not match expected pattern |
| Doc Link | FAIL | Pipeline Info > Doc Link is empty. New pipelines must have the User Story URL linked. |
| Notes | FAIL | Pipeline Info > Notes is empty. Modified pipelines should have the ticket number in Notes. |

---

### salesforce_accounts_20260225235923397284 (`salesforce_accounts.slp`)

**Overall Status:** FAIL

| Passed | Failed | Skipped |
|:---:|:---:|:---:|
| 3 | 5 | 2 |

| Check | Status | Details |
|---|:---:|---|
| Snap Naming | FAIL | Snap name 'JSON Generator' is a known default name; Snap name 'Salesforce Create' is a known default name; Snap name 'Salesforce Update' is a known default name; Snap name 'Mapper' is a known default name; Snap name 'Salesforce Read' is a known default name; ... and 1 more |
| Duplicate Snap Names | PASS | — |
| Pipeline Naming | FAIL | Pipeline name 'salesforce_accounts_20260225235923397284' does not contain required project name 'sl_project' |
| Child Pipeline Naming | SKIP | Not a child pipeline — z_ prefix check skipped |
| Parameter Capture | FAIL | Parameter 'sfdc_acct' does not have Capture enabled |
| Parameter Prefix | SKIP | Parent pipelines are exempt from parameter prefix requirement |
| Accounts Not Hardcoded | PASS | — |
| Account Reference Format | PASS | — |
| Doc Link | FAIL | Pipeline Info > Doc Link is empty. New pipelines must have the User Story URL linked. |
| Notes | FAIL | Pipeline Info > Notes is empty. Modified pipelines should have the ticket number in Notes. |

---

### sit_pipeline (`sit_sqlserver.slp`)

**Overall Status:** FAIL

| Passed | Failed | Skipped |
|:---:|:---:|:---:|
| 4 | 4 | 2 |

| Check | Status | Details |
|---|:---:|---|
| Snap Naming | FAIL | Snap name 'Data Union' is a known default name |
| Duplicate Snap Names | PASS | — |
| Pipeline Naming | FAIL | Pipeline name 'sit_pipeline' does not contain required project name 'sl_project' |
| Child Pipeline Naming | SKIP | Not a child pipeline — z_ prefix check skipped |
| Parameter Capture | PASS | — |
| Parameter Prefix | SKIP | Parent pipelines are exempt from parameter prefix requirement |
| Accounts Not Hardcoded | PASS | — |
| Account Reference Format | PASS | — |
| Doc Link | FAIL | Pipeline Info > Doc Link is empty. New pipelines must have the User Story URL linked. |
| Notes | FAIL | Pipeline Info > Notes is empty. Modified pipelines should have the ticket number in Notes. |

---

### Basic Use Case - Script Snap(Working) (`sla_pipeline.slp`)

**Overall Status:** FAIL

| Passed | Failed | Skipped |
|:---:|:---:|:---:|
| 4 | 4 | 2 |

| Check | Status | Details |
|---|:---:|---|
| Snap Naming | FAIL | Snap name 'Mapper' is a known default name; Snap name 'JS Script' is a known default name |
| Duplicate Snap Names | PASS | — |
| Pipeline Naming | FAIL | Pipeline name 'Basic Use Case - Script Snap(Working)' does not contain required project name 'sl_project' |
| Child Pipeline Naming | SKIP | Not a child pipeline — z_ prefix check skipped |
| Parameter Capture | PASS | — |
| Parameter Prefix | SKIP | Parent pipelines are exempt from parameter prefix requirement |
| Accounts Not Hardcoded | PASS | — |
| Account Reference Format | PASS | — |
| Doc Link | FAIL | Pipeline Info > Doc Link is empty. New pipelines must have the User Story URL linked. |
| Notes | FAIL | Pipeline Info > Notes is empty. Modified pipelines should have the ticket number in Notes. |

---

### snowflake_20251006194710436694 (`snowflake.slp`)

**Overall Status:** FAIL

| Passed | Failed | Skipped |
|:---:|:---:|:---:|
| 3 | 5 | 2 |

| Check | Status | Details |
|---|:---:|---|
| Snap Naming | FAIL | Snap name 'Snowflake - Insert' is a known default name; Snap name 'Data Validator' is a known default name; Snap name 'Filter' is a known default name; Snap name 'Structure' is a known default name; Snap name 'CSV Formatter' is a known default name; ... and 1 more |
| Duplicate Snap Names | PASS | — |
| Pipeline Naming | FAIL | Pipeline name 'snowflake_20251006194710436694' does not contain required project name 'sl_project' |
| Child Pipeline Naming | SKIP | Not a child pipeline — z_ prefix check skipped |
| Parameter Capture | FAIL | Parameter 'snowflake_acct' does not have Capture enabled; Parameter 'actual_output' does not have Capture enabled; Parameter 'schema_name' does not have Capture enabled; Parameter 'table_name' does not have Capture enabled; Parameter 'expression_library' does not have Capture enabled |
| Parameter Prefix | SKIP | Parent pipelines are exempt from parameter prefix requirement |
| Accounts Not Hardcoded | PASS | — |
| Account Reference Format | PASS | — |
| Doc Link | FAIL | Pipeline Info > Doc Link is empty. New pipelines must have the User Story URL linked. |
| Notes | FAIL | Pipeline Info > Notes is empty. Modified pipelines should have the ticket number in Notes. |

---

### snowflake_20251007065035853459 (`snowflake1.slp`)

**Overall Status:** FAIL

| Passed | Failed | Skipped |
|:---:|:---:|:---:|
| 3 | 5 | 2 |

| Check | Status | Details |
|---|:---:|---|
| Snap Naming | FAIL | Snap name 'Snowflake - Insert' is a known default name; Snap name 'Data Validator' is a known default name; Snap name 'Filter' is a known default name |
| Duplicate Snap Names | PASS | — |
| Pipeline Naming | FAIL | Pipeline name 'snowflake_20251007065035853459' does not contain required project name 'sl_project' |
| Child Pipeline Naming | SKIP | Not a child pipeline — z_ prefix check skipped |
| Parameter Capture | FAIL | Parameter 'snowflake_acct' does not have Capture enabled; Parameter 'schema_name' does not have Capture enabled; Parameter 'table_name' does not have Capture enabled; Parameter 'expression_library' does not have Capture enabled |
| Parameter Prefix | SKIP | Parent pipelines are exempt from parameter prefix requirement |
| Accounts Not Hardcoded | PASS | — |
| Account Reference Format | PASS | — |
| Doc Link | FAIL | Pipeline Info > Doc Link is empty. New pipelines must have the User Story URL linked. |
| Notes | FAIL | Pipeline Info > Notes is empty. Modified pipelines should have the ticket number in Notes. |

---

### snowflake_20251007065035853459 (`snowflake2.slp`)

**Overall Status:** FAIL

| Passed | Failed | Skipped |
|:---:|:---:|:---:|
| 3 | 5 | 2 |

| Check | Status | Details |
|---|:---:|---|
| Snap Naming | FAIL | Snap name 'Snowflake - Insert' is a known default name; Snap name 'Data Validator' is a known default name; Snap name 'Filter' is a known default name |
| Duplicate Snap Names | PASS | — |
| Pipeline Naming | FAIL | Pipeline name 'snowflake_20251007065035853459' does not contain required project name 'sl_project' |
| Child Pipeline Naming | SKIP | Not a child pipeline — z_ prefix check skipped |
| Parameter Capture | FAIL | Parameter 'snowflake_acct' does not have Capture enabled; Parameter 'schema_name' does not have Capture enabled; Parameter 'table_name' does not have Capture enabled; Parameter 'expression_library' does not have Capture enabled |
| Parameter Prefix | SKIP | Parent pipelines are exempt from parameter prefix requirement |
| Accounts Not Hardcoded | PASS | — |
| Account Reference Format | PASS | — |
| Doc Link | FAIL | Pipeline Info > Doc Link is empty. New pipelines must have the User Story URL linked. |
| Notes | FAIL | Pipeline Info > Notes is empty. Modified pipelines should have the ticket number in Notes. |

---

### snowflake_keypair_20251126183711459164 (`snowflake_keypair.slp`)

**Overall Status:** FAIL

| Passed | Failed | Skipped |
|:---:|:---:|:---:|
| 3 | 5 | 2 |

| Check | Status | Details |
|---|:---:|---|
| Snap Naming | FAIL | Snap name 'Filter' is a known default name; Snap name 'Data Validator' is a known default name; Snap name 'Snowflake - Snowpipe Streaming' is a known default name; Snap name 'Router' is a known default name; Snap name 'Union' is a known default name; ... and 2 more |
| Duplicate Snap Names | PASS | — |
| Pipeline Naming | FAIL | Pipeline name 'snowflake_keypair_20251126183711459164' does not contain required project name 'sl_project' |
| Child Pipeline Naming | SKIP | Not a child pipeline — z_ prefix check skipped |
| Parameter Capture | FAIL | Parameter 'destination_hint' does not have Capture enabled; Parameter 'schema' does not have Capture enabled; Parameter 'table' does not have Capture enabled; Parameter 'isTest' does not have Capture enabled; Parameter 'test_input_file' does not have Capture enabled; ... and 1 more |
| Parameter Prefix | SKIP | Parent pipelines are exempt from parameter prefix requirement |
| Accounts Not Hardcoded | PASS | — |
| Account Reference Format | PASS | — |
| Doc Link | FAIL | Pipeline Info > Doc Link is empty. New pipelines must have the User Story URL linked. |
| Notes | FAIL | Pipeline Info > Notes is empty. Modified pipelines should have the ticket number in Notes. |

---

### snowflake_user_password_auth_20251125201248568545 (`snowflake_user_password_auth.slp`)

**Overall Status:** FAIL

| Passed | Failed | Skipped |
|:---:|:---:|:---:|
| 3 | 5 | 2 |

| Check | Status | Details |
|---|:---:|---|
| Snap Naming | FAIL | Snap name 'Snowflake - Insert' is a known default name; Snap name 'Data Validator' is a known default name; Snap name 'Filter' is a known default name |
| Duplicate Snap Names | PASS | — |
| Pipeline Naming | FAIL | Pipeline name 'snowflake_user_password_auth_20251125201248568545' does not contain required project name 'sl_project' |
| Child Pipeline Naming | SKIP | Not a child pipeline — z_ prefix check skipped |
| Parameter Capture | FAIL | Parameter 'snowflake_acct' does not have Capture enabled; Parameter 'schema_name' does not have Capture enabled; Parameter 'table_name' does not have Capture enabled; Parameter 'expression_library' does not have Capture enabled |
| Parameter Prefix | SKIP | Parent pipelines are exempt from parameter prefix requirement |
| Accounts Not Hardcoded | PASS | — |
| Account Reference Format | PASS | — |
| Doc Link | FAIL | Pipeline Info > Doc Link is empty. New pipelines must have the User Story URL linked. |
| Notes | FAIL | Pipeline Info > Notes is empty. Modified pipelines should have the ticket number in Notes. |

---

### sqlserver_20250731192144680328 (`sqlserver.slp`)

**Overall Status:** FAIL

| Passed | Failed | Skipped |
|:---:|:---:|:---:|
| 3 | 5 | 2 |

| Check | Status | Details |
|---|:---:|---|
| Snap Naming | FAIL | Snap name 'SQL Server - Select' is a known default name; Snap name 'CSV Formatter' is a known default name; Snap name 'File Writer' is a known default name |
| Duplicate Snap Names | PASS | — |
| Pipeline Naming | FAIL | Pipeline name 'sqlserver_20250731192144680328' does not contain required project name 'sl_project' |
| Child Pipeline Naming | SKIP | Not a child pipeline — z_ prefix check skipped |
| Parameter Capture | FAIL | Parameter 'USER' does not have Capture enabled; Parameter 'NAME_CD_1' does not have Capture enabled; Parameter 'NAME_CD_2' does not have Capture enabled; Parameter 'DOMAIN_NAME' does not have Capture enabled; Parameter 'M_CURR_DATE' does not have Capture enabled; ... and 1 more |
| Parameter Prefix | SKIP | Parent pipelines are exempt from parameter prefix requirement |
| Accounts Not Hardcoded | PASS | — |
| Account Reference Format | PASS | — |
| Doc Link | FAIL | Pipeline Info > Doc Link is empty. New pipelines must have the User Story URL linked. |
| Notes | FAIL | Pipeline Info > Notes is empty. Modified pipelines should have the ticket number in Notes. |

---
