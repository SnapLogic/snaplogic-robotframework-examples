# Oracle Account Creation Tests

To create account-related test cases, you need 3 files:
- **Account payload file** — JSON template with Jinja variable placeholders for SnapLogic account configuration
- **Environment file** — Contains the environment variables referenced in the payload file
- **Test case file** — Robot Framework test that uses `Create Account From Template` to create the account

## Purpose
Creates Oracle database account(s) in SnapLogic for pipeline testing.

## File Structure
```
project-root/
├── test/
│   └── suite/
│       ├── pipeline_tests/
│       │   └── oracle/
│       │       ├── oracle_account_setup.robot             ← Test case file
│       │       └── ACCOUNT_SETUP_README.md                ← This file
│       └── test_data/
│           └── accounts_payload/
│               └── acc_oracle.json                        ← Account payload file
├── env_files/
│   └── database_accounts/
│       └── .env.oracle                                    ← Environment file
└── .env                                                   ← Override credentials here
```

## Prerequisites
Configure in `env_files/database_accounts/.env.oracle` or override in root `.env`:
- `ORACLE_HOST` — Oracle database hostname (default: `oracle-db` for Docker)
- `ORACLE_PORT` — Port number (default: `1521`)
- `ORACLE_USER` — Database username (default: `SYSTEM`)
- `ORACLE_PASSWORD` — Database password
- `ORACLE_DATABASE` — Service name / database name (default: `FREEPDB1`)
- `ORACLE_ACCOUNT_NAME` — Account label in SnapLogic (default: `oracle_acct`)

> **Docker users:** The default values in `.env.oracle` are pre-configured for the local Docker container (`oracle-db`). No changes needed for local testing.
>
> **External Oracle instance:** Copy the variables above to root `.env` and update with your connection details.

## How to Run
```bash
make robot-run-all-tests TAGS="oracle" PROJECT_SPACE_SETUP=True
```
