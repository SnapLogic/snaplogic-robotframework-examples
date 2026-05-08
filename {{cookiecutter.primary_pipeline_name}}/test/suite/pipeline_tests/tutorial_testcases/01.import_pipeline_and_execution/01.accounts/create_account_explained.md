# Creating a SnapLogic Account — Manual vs Automation

> **What is an account?**
> A small piece of config that tells SnapLogic *how* to connect to a system —
> a database, S3, Kafka, etc. Pipelines reference it by name.

---

## The two ways

```
┌────────────────────────────────┐         ┌────────────────────────────────┐
│         MANUAL (UI)            │   VS    │   AUTOMATION (Robot test)      │
│   Click around in Designer     │         │   Run a make command           │
└────────────────────────────────┘         └────────────────────────────────┘
```

Both produce the **same end result**: an account asset stored in SnapLogic.
Only the *path to get there* is different.



## What data is needed — side-by-side

```
┌──────────────────────────────────┬──────────────────────────────────────┐
│           MANUAL                 │            AUTOMATION                │
├──────────────────────────────────┼──────────────────────────────────────┤
│  Typed into Designer form:       │  Stored in 2 files:                  │
│                                  │                                      │
│  • Hostname   ___________        │  📄 acc_sqlserver.json (payload)     │
│  • Port       ___________        │     {                                │
│  • Username   ___________        │       "host": "{{HOST}}",            │
│  • Password   ___________        │       "user": "{{USER}}",            │
│  • Database   ___________        │       "password": "{{PASSWORD}}",    │
│  • Account    ___________        │       ...                            │
│    label                         │     }                                │
│  • Encrypt?   ___________        │                                      │
│  • Trust      ___________        │  📄 .env.sqlserver (credentials)     │
│    cert?                         │     SQLSERVER_HOST=sqlserver-db      │
│                                  │     SQLSERVER_USER=sa                │
│  Per account.  Per environment.  │     SQLSERVER_PASSWORD=...           │
│  Every time.                     │     ...                              │
└──────────────────────────────────┴──────────────────────────────────────┘
```

---

## Where the automation reads each variable from

| Variable                       | Source file                                                   |
| ------------------------------ | ------------------------------------------------------------- |
| `${ACCOUNT_LOCATION_PATH}`     | `.env` (project root)                                         |
| `${ACCOUNT_PAYLOAD_FILE_NAME}` | `env_files/database_accounts/env.filename`(Eg:.env.sqlserver) |
| `${ACCOUNT_NAME}`              | `env_files/database_accounts/.env.sqlserver`                  |

---

## Where the actual files live

- **Account payload templates:** the JSON files referenced by `${ACCOUNT_PAYLOAD_FILE_NAME}` live in
  📁 `test/suite/test_data/accounts_payload/`

- **JAR files (when needed):** some account types — MySQL, DB2, Teradata, JMS — require a JDBC driver JAR. These must be **uploaded to SLDB before** the account is created. All JAR files live in
  📁 `test/suite/test_data/accounts_jar_files/<type>/`

---

## Sample account-creation test case

Here's the actual Robot test case that creates an account ([`create_account.robot`](./create_account.robot)):

```robot
*** Settings ***
Resource    snaplogic_common_robot/snaplogic_apis_keywords/snaplogic_keywords.resource

*** Test Cases ***
Create Account
    [Tags]    sqlserver2_demo2
    [Template]    Create Account From Template

    # account_location_path             payload_file_name                       account_name
    ${ACCOUNT_LOCATION_PATH}    ${SQLSERVER_ACCOUNT_PAYLOAD_FILE_NAME}    ${SQLSERVER_ACCOUNT_NAME}

    # Same call, but force-replace the account if it already exists
    ${ACCOUNT_LOCATION_PATH}    ${SQLSERVER_ACCOUNT_PAYLOAD_FILE_NAME}    ${SQLSERVER_ACCOUNT_NAME}    overwrite_if_exists=${TRUE}
```

Three positional arguments per row, plus one optional named argument:
1. **Where** to create the account (location in the project space)
2. **Which** JSON template to use (file name in `accounts_payload/`)
3. **What name** the account should have in SnapLogic
4. *(optional)* `overwrite_if_exists=${TRUE}` — see below

### About `overwrite_if_exists`

By default, if an account with the same name already exists in the project space, the keyword **skips creation** and the row passes silently. That's the safe default — it makes re-runs idempotent.

Set `overwrite_if_exists=${TRUE}` to force a **delete + recreate** when the account exists. Use it when:

- You changed values in `.env` (e.g. password rotated) and need the account to pick them up
- The existing account got into a bad state and you want a clean slate
- You're iterating on the JSON template and want each run to apply the latest version

⚠ It is **destructive** — any manual edits made in the SnapLogic UI to that account are wiped out. For demos and CI it's usually what you want; for shared accounts on a customer org, double-check first.

Add more rows to create more accounts in the same test case — Robot calls `Create Account From Template` once per row.

---

## Usage example

Run this test case:

```bash
make robot-run-tests-no-gp TAGS="tag_name"     # eg: TAGS="sql_server"
```

What happens:

1. Robot loads `.env` and `env_files/.../.env.sqlserver`
2. Reads `acc_sqlserver.json` from `test/suite/test_data/accounts_payload/`
3. In PAYLOAD: Substitutes placeholders (`{{HOST}}`, `{{USER}}`, `{{PASSWORD}}`...) with values from the env files
4. POSTs the rendered JSON to SnapLogic
5. ✅ The account appears in the SnapLogic UI under the project space → `shared`

To run against a different environment (e.g. stage):

```bash
make robot-run-tests-no-gp TAGS="tag_name" ENV=.env.stage     # eg: TAGS="sql_server"
```

