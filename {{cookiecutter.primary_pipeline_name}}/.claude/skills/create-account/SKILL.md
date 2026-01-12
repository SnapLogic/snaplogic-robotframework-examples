---
name: create-account
description: Creates Robot Framework test cases for SnapLogic account creation. Use when the user wants to create accounts (Oracle, PostgreSQL, Snowflake, Kafka, S3, etc.), needs to know what environment variables to configure, or wants to see account test case examples.
user-invocable: true
---

# SnapLogic Account Creation Skill

You help users create Robot Framework test cases that create SnapLogic accounts.

## How to Use This Skill

### Automatic Activation
This skill activates automatically when Claude detects you're asking about account creation. Just ask naturally:

```
I need to create a Snowflake account for my pipeline
```

```
What environment variables do I need for an Oracle account?
```

```
Show me how to create PostgreSQL and S3 accounts
```

### Manual Invocation
You can also invoke this skill explicitly:

```
/create-account
```

### Related Slash Command
For more structured actions, use the slash command:

| Command | Action |
|---------|--------|
| `/create-account-testcase` | Default menu with quick options |
| `/create-account-testcase info` | Full menu with all commands |
| `/create-account-testcase list` | Table of supported account types |
| `/create-account-testcase create oracle` | Create Oracle account test case |
| `/create-account-testcase check snowflake` | Check Snowflake env variables |

---

## When to Use This Skill

Automatically activate when the user:
- Wants to create a SnapLogic account test case
- Asks about account types (Oracle, Snowflake, PostgreSQL, etc.)
- Needs to know what environment variables to configure for an account
- Wants to see baseline/example account tests
- Asks about account payload files or env file locations

## Workflow

### Step 1: Identify Account Type

Ask or determine which account type is needed:

| Type | Description |
|------|-------------|
| `oracle` | Oracle Database |
| `postgres` | PostgreSQL Database |
| `mysql` | MySQL Database |
| `sqlserver` | SQL Server Database |
| `snowflake` | Snowflake (Password Auth) |
| `snowflake-keypair` | Snowflake (Key Pair Auth) |
| `db2` | IBM DB2 |
| `teradata` | Teradata |
| `kafka` | Apache Kafka |
| `jms` | JMS/ActiveMQ |
| `s3` | AWS S3 / MinIO |
| `email` | Email/SMTP |
| `salesforce` | Salesforce |

### Step 2: Check Environment File

**Always read the env file first** to understand what variables are available:

| Account Type | Env File Location |
|--------------|-------------------|
| Oracle | `env_files/database_accounts/.env.oracle` |
| PostgreSQL | `env_files/database_accounts/.env.postgres` |
| MySQL | `env_files/database_accounts/.env.mysql` |
| SQL Server | `env_files/database_accounts/.env.sqlserver` |
| Snowflake (Password) | `env_files/database_accounts/.env.snowflake` |
| Snowflake (Key Pair) | `env_files/database_accounts/.env.snowflake_s3_keypair` |
| DB2 | `env_files/database_accounts/.env.db2` |
| Teradata | `env_files/database_accounts/.env.teradata` |
| Kafka | `env_files/messaging_service_accounts/.env.kafka` |
| JMS | `env_files/messaging_service_accounts/.env.jms` |
| S3 / MinIO | `env_files/mock_service_accounts/.env.s3` |
| Email | `env_files/mock_service_accounts/.env.email` |
| Salesforce | `env_files/mock_service_accounts/.env.salesforce` |

### Step 3: Show Baseline Test Reference

Point users to baseline tests for examples:

- `test/suite/pipeline_tests/snowflake/snowflake_baseline_tests.robot`
- `test/suite/pipeline_tests/oracle/oracle_baseline_tests.robot`
- `test/suite/pipeline_tests/postgres/postgres_baseline_tests.robot`

### Step 4: Create Test Case

Use this template pattern:

```robotframework
*** Settings ***
Documentation    Creates SnapLogic accounts for pipeline testing
Resource         ../../resources/common/general.resource
Library          Collections

*** Test Cases ***
Create [AccountType] Account
    [Documentation]    Creates a [AccountType] account in SnapLogic.
    [Tags]    [tag]    account_setup
    [Template]    Create Account From Template
    ${ACCOUNT_LOCATION_PATH}    ${[TYPE]_ACCOUNT_PAYLOAD_FILE_NAME}    ${[TYPE]_ACCOUNT_NAME}    overwrite_if_exists=${TRUE}
```

## Account Files Reference

| Account Type | Payload File | Env File |
|--------------|--------------|----------|
| PostgreSQL | `acc_postgres.json` | `env_files/database_accounts/.env.postgres` |
| MySQL | `acc_mysql.json` | `env_files/database_accounts/.env.mysql` |
| Oracle | `acc_oracle.json` | `env_files/database_accounts/.env.oracle` |
| SQL Server | `acc_sqlserver.json` | `env_files/database_accounts/.env.sqlserver` |
| Snowflake | `acc_snowflake_s3_db.json` | `env_files/database_accounts/.env.snowflake` |
| Snowflake (Key Pair) | `acc_snowflake_s3_keypair.json` | `env_files/database_accounts/.env.snowflake_s3_keypair` |
| DB2 | `acc_db2.json` | `env_files/database_accounts/.env.db2` |
| Teradata | `acc_teradata.json` | `env_files/database_accounts/.env.teradata` |
| Kafka | `acc_kafka.json` | `env_files/messaging_service_accounts/.env.kafka` |
| JMS | `acc_jms.json` | `env_files/messaging_service_accounts/.env.jms` |
| S3 / MinIO | `acc_s3.json` | `env_files/mock_service_accounts/.env.s3` |
| Email | `acc_email.json` | `env_files/mock_service_accounts/.env.email` |
| Salesforce | `acc_salesforce.json` | `env_files/mock_service_accounts/.env.salesforce` |

## Example Test Cases

### Oracle Account
```robotframework
Create Oracle Account
    [Documentation]    Creates an Oracle database account in SnapLogic.
    [Tags]    oracle    account_setup
    [Template]    Create Account From Template
    ${ACCOUNT_LOCATION_PATH}    ${ORACLE_ACCOUNT_PAYLOAD_FILE_NAME}    ${ORACLE_ACCOUNT_NAME}    overwrite_if_exists=${TRUE}
```

### Snowflake Key Pair Account
```robotframework
Create Snowflake Key Pair Account
    [Documentation]    Creates a Snowflake account using key pair authentication.
    [Tags]    snowflake    account_setup    keypair
    [Template]    Create Account From Template
    ${ACCOUNT_LOCATION_PATH}    ${SNOWFLAKE_ACCOUNT_PAYLOAD_KEY_PAIR_FILE_NAME}    ${SNOWFLAKE_KEYPAIR_ACCOUNT_NAME}    overwrite_if_exists=${TRUE}
```

### S3/MinIO Account
```robotframework
Create S3 Account
    [Documentation]    Creates an S3/MinIO account in SnapLogic.
    [Tags]    s3    minio    account_setup
    [Template]    Create Account From Template
    ${ACCOUNT_LOCATION_PATH}    ${S3_ACCOUNT_PAYLOAD_FILE_NAME}    ${S3_ACCOUNT_NAME}    overwrite_if_exists=${TRUE}
```

## Environment Variable Override

To use your own credentials instead of Docker defaults, copy variables to root `.env`:

```bash
# Root .env overrides env_files/ settings
SNOWFLAKE_KEYPAIR_HOSTNAME=mycompany.snowflakecomputing.com
SNOWFLAKE_KEYPAIR_USERNAME=my_username
SNOWFLAKE_KEYPAIR_DATABASE=PRODUCTION_DB
```

## JAR File Requirements

Some accounts require JDBC driver JAR files:

| Account | JAR Required | Location |
|---------|--------------|----------|
| MySQL | Yes | `test/suite/test_data/accounts_jar_files/mysql/` |
| DB2 | Yes | `test/suite/test_data/accounts_jar_files/db2/` |
| Teradata | Yes | `test/suite/test_data/accounts_jar_files/teradata/` |
| JMS | Yes | `test/suite/test_data/accounts_jar_files/jms/` |
