# D0365 Pipeline — Overview & Database Reference

> **Note on naming:** This pipeline writes to **SQL Server** . 
---

## 1. What this pipeline does (in one paragraph)

The D0365 pipeline ingests a single industry-standard text file describing
electricity-market settlement data — invoices, contracts, billing periods,
metered units — and loads it into 8 related tables in a SQL Server database
under the `esb` schema. The file uses a pipe-delimited format with record-type
prefixes (`ZHV`, `86I`, `87I`, …) and represents one or more **CFD
(Contract For Difference)** invoices for a billing month.

If anything goes wrong mid-load, an automatic rollback pipeline cleans up any
half-written rows so the database stays in a consistent state.

---

## 2. The two pipeline files

| File                                  | Purpose                                                                         |
| ------------------------------------- | ------------------------------------------------------------------------------- |
| `D0365_test_clean_version.slp`        | **Main pipeline** — reads the file and writes to 8 tables                       |
| `D0365_Error_Pipeline_SQL_Delete.slp` | **Error / rollback pipeline** — runs automatically if the main pipeline fails   |
| `d0365_helpers.expr`                  | **Expression library** — shared functions for date conversion and ID generation |

The main pipeline references the error pipeline by name (no path), so both must
exist in the same SnapLogic project space.

---

## 3. Input file format

Plain text, pipe-delimited (`|`), with each line tagged by record type. Example:

```
ZHV|D0365001|D0365|001|TESTPARTY|20260504|001
86I|TESTPARTY|100001|20260504|20260518|15150.00
87I|CFD-AAA-001|CFD|10000.00|5000.00|150.00|15150.00|0.00
88I|20260401|SP01|5000.00|2500.00|75.00
89I|1|100.50|10.0|5.00|0.50|0.95|55.00||45.00||1.0|EXC|1.0|5.50|275.00
CME|MPN-001
89I|2|150.75|15.0|7.50|0.50|0.95|55.00||45.00||1.0|EXC|1.0|7.50|375.00
CME|MPN-002
88I|20260402|SP02|5000.00|2500.00|75.00
89I|1|120.00|12.0|6.00|0.50|0.95|55.00||45.00||1.0|EXC|1.0|5.50|275.00
CME|MPN-003
90I|100001|20260504|10000.00|20260420|20260504|150.00
91I|20260420|0.05
92I|Curtailment Comp|100.00|0|0|0|0|0|0|20260401|20260430
ZPT
```

### Record-type meanings

| Tag   | Meaning                                       | Lands in table               |
| ----- | --------------------------------------------- | ---------------------------- |
| `ZHV` | File header (must appear once)                | `esb.D0365Interchange`       |
| `86I` | Invoice header                                | `esb.EMRInvoiceHeader`       |
| `87I` | Contract for Difference (one per invoice)     | `esb.ContractForDifference`  |
| `88I` | Billing period                                | `esb.CFDBillingPeriod`       |
| `89I` | Settlement unit (per period)                  | `esb.CFDSettlementUnit`      |
| `CME` | Metered entity (structural only — not stored) | —                            |
| `90I` | Default interest *(optional)*                 | `esb.CFDDefaultInterest`     |
| `91I` | Default interest rate *(optional)*            | `esb.CFDDefaultInterestRate` |
| `92I` | Ad-hoc payment *(optional)*                   | `esb.CFDAdHocPayment`        |
| `ZPT` | File trailer (ignored)                        | —                            |

### Required hierarchy

```
ZHV  (exactly 1)
└── 86I  (≥1)              Invoice
    ├── 87I  (exactly 1)   Contract For Difference
    │   ├── 88I  (≥1)      Billing Period
    │   │   └── 89I  (≥1)  Settlement Unit
    │   │       └── CME    metered entity
    │   ├── 90I  (≥0)      Default Interest
    │   │   └── 91I  (≥0)  Default Interest Rate
    │   └── 92I  (≥0)      Ad-Hoc Payment
ZPT
```

The Script London snap validates this structure. If any mandatory record is
missing or out of order, the file is rejected before any database writes
happen.

---

## 4. Pipeline architecture (main pipeline)

The main pipeline has 32 snaps. Conceptually, the flow is:

```
                       ┌─────────────────────────┐
                       │  Binary Read (file)     │
                       └────────────┬────────────┘
                                    ▼
                       ┌─────────────────────────┐
                       │  Binary → Document      │  bytes → text doc
                       └────────────┬────────────┘
                                    ▼
                       ┌─────────────────────────┐
                       │  Script London (Python) │  parse + validate +
                       │                         │  emit per-record docs
                       └────────────┬────────────┘
                                    ▼
                       ┌─────────────────────────┐
                       │  Router  ($_table)      │  route by record type
                       └────────────┬────────────┘
                                    │
        ┌──────────────┬────────────┼──────────────┬──────────────┐
        ▼              ▼            ▼              ▼              ▼
    Mapper 86I    Mapper 87I   Mapper 88I    Mapper 89I    Mapper 90/91/92I
        │              │            │              │              │
        ▼              ▼            ▼              ▼              ▼
   Insert        Insert        Insert        Insert        Insert
   EMRInvoice    ContractForD  CFDBilling    CFDSettlement  3 optional
   Header                       Period        Unit          tables
```

### What each stage does

| Stage | Snap(s)            | Purpose                                                                                                         |
| ----- | ------------------ | --------------------------------------------------------------------------------------------------------------- |
| 1     | Binary Read        | Open the file from SnapLogic SLDB or a configured path                                                          |
| 2     | Binary → Document  | Convert raw bytes to a single document with a `content` text field                                              |
| 3     | Script London      | Parse the file line-by-line, validate structure, generate hierarchical IDs, emit one tagged document per record |
| 4     | Router             | Read each document's `_table` field and forward to the correct branch                                           |
| 5     | Joins              | Re-attach parent IDs (e.g. settlement units carry their billing period's ID)                                    |
| 6     | Filters            | Skip optional branches when the optional FK is absent                                                           |
| 7     | Mappers            | Rename/cast fields to match SQL Server column types                                                             |
| 8     | SQL Server Inserts | Write each row to its target table                                                                              |

---

## 5. Database schema (`esb` schema in SQL Server)

| Table                    | Source | Primary Key                | Foreign Key (logical)     |
| ------------------------ | ------ | -------------------------- | ------------------------- |
| `D0365Interchange`       | `ZHV`  | `D0365InterchangeID`       | — (root)                  |
| `EMRInvoiceHeader`       | `86I`  | `EMRInvoiceHeaderID`       | implicit via prefix       |
| `ContractForDifference`  | `87I`  | `ContractForDifferenceID`  | `EMRInvoiceHeaderID`      |
| `CFDBillingPeriod`       | `88I`  | `CFDBillingPeriodID`       | `ContractForDifferenceID` |
| `CFDSettlementUnit`      | `89I`  | `CFDSettlementUnitID`      | `CFDBillingPeriodID`      |
| `CFDDefaultInterest`     | `90I`  | `CFDDefaultInterestID`     | `ContractForDifferenceID` |
| `CFDDefaultInterestRate` | `91I`  | `CFDDefaultInterestRateID` | `CFDDefaultInterestID`    |
| `CFDAdHocPayment`        | `92I`  | `CFDAdHocPaymentID`        | `ContractForDifferenceID` |

The **schema does not declare formal `FOREIGN KEY` constraints** — relationships
are enforced through the hierarchical ID format (see next section). This was
the customer's original design.

DDL lives in [`sqlserver_queries.resource`](../test/suite/test_data/queries/sqlserver_queries.resource)
under the variables `${SQL_CREATE_TABLE_*}`.

---

## 6. Hierarchical ID generation (the magic)

Every primary key is built from the file's root key plus its position in the
hierarchy. Defined in `d0365_helpers.expr`:

| Level            | Format                        | Example                          |
| ---------------- | ----------------------------- | -------------------------------- |
| File header      | `fileId + "_" + fromId`       | `D0365001_TESTPARTY`             |
| Invoice          | `<root> + "_" + invoiceIndex` | `D0365001_TESTPARTY_1`           |
| Contract         | `<invoice> + "_" + cfdIndex`  | `D0365001_TESTPARTY_1_1`         |
| Billing period   | `<contract> + "_" + bpIndex`  | `D0365001_TESTPARTY_1_1_1`       |
| Settlement unit  | `<bp> + "_" + unitId`         | `D0365001_TESTPARTY_1_1_1_1`     |
| Default interest | `<contract> + "_DI" + idx`    | `D0365001_TESTPARTY_1_1_DI1`     |
| Interest rate    | `<DI> + "_IR" + idx`          | `D0365001_TESTPARTY_1_1_DI1_IR1` |
| Ad-hoc payment   | `<contract> + "_AH" + idx`    | `D0365001_TESTPARTY_1_1_AH1`     |

### Why this matters

- **Determinism:** the same file always produces the same IDs. Reprocessing
  triggers PRIMARY KEY violations on purpose — the database refuses to
  silently double-load.
- **Rollback by prefix:** the error pipeline can wipe a failing file's data
  with `WHERE id LIKE 'D0365001%'` — a surgical cleanup.
- **No FK constraints needed:** you can join any child to its grandparent by
  comparing prefixes.

---

## 7. Error pipeline (`D0365_Error_Pipeline_SQL_Delete`)

### When it runs

SnapLogic invokes it automatically when **any** snap in the main pipeline emits
an error document — file missing, validation failure, type mismatch, database
down, etc. It does NOT run on the happy path.

### What it does

1. Receives error documents from the main pipeline. Each one carries `original`
   = the row that failed to insert.
2. The **Get the ID** mapper inspects `original` and pulls the file's root key
   out of whichever ID column is present.
3. Six SQL Server **Delete** snaps run in dependency-safe order:

```sql
DELETE FROM esb.CFDAdHocPayment       WHERE ContractForDifferenceID LIKE '<root>%'
DELETE FROM esb.CFDSettlementUnit     WHERE CFDBillingPeriodID      LIKE '<root>%'
DELETE FROM esb.CFDBillingPeriod      WHERE ContractForDifferenceID LIKE '<root>%'
DELETE FROM esb.ContractForDifference WHERE EMRInvoiceHeaderID      LIKE '<root>%'
DELETE FROM esb.EMRInvoiceHeader      WHERE EMRInvoiceHeaderID      LIKE '<root>%'
DELETE FROM esb.D0365Interchange      WHERE D0365InterchangeID      LIKE '<root>%'
```

### Important: it deletes **only the failing file's rows**

The `LIKE '<root>%'` filter targets one file at a time. Other files already in
the database are untouched.

### Known gap

The error pipeline currently does **NOT** delete from `esb.CFDDefaultInterest`
or `esb.CFDDefaultInterestRate`. If a partial failure leaves rows in those two
tables, they become orphans. This is a design oversight in the customer's
pipeline — flag it for them.

---

## 8. State of the database

### Before pipeline execution

```
TEST.esb (all tables empty)
├── D0365Interchange       (0)
├── EMRInvoiceHeader       (0)
├── ContractForDifference  (0)
├── CFDBillingPeriod       (0)
├── CFDSettlementUnit      (0)
├── CFDDefaultInterest     (0)
├── CFDDefaultInterestRate (0)
└── CFDAdHocPayment        (0)
```

The Robot test framework's suite setup (`Reset D0365 Tables If They Exist`)
clears the tables before each run so the pipeline always starts with a clean
slate.

### After successful execution (with the sample file)

```
TEST.esb
├── D0365Interchange       (1)   ← D0365001_TESTPARTY
├── EMRInvoiceHeader       (1)   ← invoice 100001, total 15150.00
├── ContractForDifference  (1)   ← CFD-AAA-001, NetPayable 15150.0000
├── CFDBillingPeriod       (2)   ← SP01 (Apr 1), SP02 (Apr 2)
├── CFDSettlementUnit      (3)   ← units 1+2 in SP01, unit 1 in SP02
├── CFDDefaultInterest     (1)   ← if optional branch worked
├── CFDDefaultInterestRate (1)   ← if optional branch worked
└── CFDAdHocPayment        (1)   ← if optional branch worked
```

Counts for the 5 mandatory tables (1, 1, 1, 2, 3) come directly from the file
structure: 1 ZHV, 1 86I, 1 87I, 2 88Is, 3 89Is.

---

## 9. Robot Framework test suite

Located at [`test/suite/pipeline_tests/sqlserver/sql_server2.robot`](../test/suite/pipeline_tests/sqlserver/sql_server2.robot).

### Suite structure

| Phase                        | Test cases                                                                                                      |
| ---------------------------- | --------------------------------------------------------------------------------------------------------------- |
| **Suite setup** (1 keyword)  | `Initialize Test Environment` — connect + truncate-if-exists                                                    |
| **Setup** (5 cases)          | Create Account · Upload input Files · Import Pipeline · Import Error Pipeline · Setup Of SQL Server Prereq Data |
| **Execute** (2 cases)        | Create Triggered Task · Execute Triggered Task                                                                  |
| **Verify counts** (5 cases)  | One per mandatory table                                                                                         |
| **Verify content** (4 cases) | InterchangeID format, InvoiceTotal, NetPayableAmount, settlement-unit IDs                                       |

### How to run

```bash
make robot-run-tests-no-gp TAGS="sqlserver_drax"
```

Reports land in `test/robot_output/`:
- `report-*.html` — pass/fail summary
- `log-*.html` — detailed step-by-step

### Design principles (from project CLAUDE.md)

- **Test cases contain only verifications.** All logic lives in keywords.
- **All SQL lives in `sqlserver_queries.resource`** — not inline in tests.
- **Idempotent setup** — schema creation and table truncation run safely on
  any re-run.

---

## 10. Configuration files

| File                                                                                                                                                                      | Purpose                                                   |
| ------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------- |
| [`env_files/database_accounts/.env.sqlserver`](../env_files/database_accounts/.env.sqlserver)                                                                             | SQL Server connection (host, port, database, credentials) |
| [`test/suite/test_data/accounts_payload/acc_sqlserver.json`](../test/suite/test_data/accounts_payload/acc_sqlserver.json)                                                 | SnapLogic account template (with TLS settings)            |
| [`test/suite/test_data/queries/sqlserver_queries.resource`](../test/suite/test_data/queries/sqlserver_queries.resource)                                                   | DDL, INSERT, SELECT, DELETE statements                    |
| [`test/suite/test_data/actual_expected_data/input_data/D0365_sample_2026_05_04.txt`](../test/suite/test_data/actual_expected_data/input_data/D0365_sample_2026_05_04.txt) | Sample input file                                         |

### Important env vars

```bash
SQLSERVER_HOST=sqlserver-db        # Docker container name (NOT localhost)
SQLSERVER_DATABASE=TEST            # Application DB (not master)
SQLSERVER_PORT=1433
SQLSERVER_USER=sa
```

The TLS flags in `acc_sqlserver.json` (`encrypt=true`, `trustServerCertificate=true`)
are required because SQL Server 2022 enforces encryption by default and the
Docker container uses a self-signed cert.

---

## 11. Troubleshooting

| Symptom                                          | Likely cause                                             | Fix                                                                                                            |
| ------------------------------------------------ | -------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------- |
| `Connection is not available, request timed out` | TLS/account misconfig or wrong hostname                  | Set `encrypt=true; trustServerCertificate=true`; hostname must be `sqlserver-db` (not `localhost`)             |
| `network snaplogicnet not found`                 | Docker compose project prefix                            | Run `make start-services` to recreate the network                                                              |
| `Violation of PRIMARY KEY constraint`            | Re-running with the same file                            | Suite setup truncates automatically; if running manually, run the truncate queries first                       |
| `Invalid value` on insert                        | `parseFloat(null)` → `NaN` from empty optional fields    | Sample file should fill optional decimals; or fix the customer's mappers to be null-safe                       |
| `'original' was not found`                       | Error pipeline expression doesn't guard `$original`      | Patched in this repo's copy of `D0365_Error_Pipeline_SQL_Delete.slp`                                           |
| `Asset [None] to be Pipeline but was Org`        | Triggered-task lookup couldn't find the pipeline by name | Confirm `Import Pipeline` ran first; use `Create Triggered Task From Template` (not the original-name variant) |

---

## 12. Demo cheat sheet

If you're showing this to a customer:

1. **One command runs everything**
   ```bash
   make robot-run-tests-no-gp TAGS="sqlserver_drax"
   ```
2. **Open the Robot HTML report** to walk through each test case
3. **Verify in DBeaver** by connecting to `localhost:1433`, database `TEST`,
   schema `esb` — show row counts in each table
4. **Talking points:**
   - Pipeline parses a real-world industry file format
   - Generates deterministic hierarchical IDs (no DB sequences needed)
   - Auto-rolls-back on partial failure via the error pipeline
   - Robot Framework asserts both row counts and specific column values
   - End-to-end: 16 test cases, all passing in ~2 minutes
