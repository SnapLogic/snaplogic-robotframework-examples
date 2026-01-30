---
name: create-account
description: Creates Robot Framework test cases for SnapLogic account creation. Use when the user wants to create accounts (Oracle, PostgreSQL, Snowflake, Kafka, S3, etc.), needs to know what environment variables to configure, or wants to see account test case examples.
user-invocable: true
---

# Create Account Test Case Guide

## Claude Instructions

**IMPORTANT:** When user asks a simple question like "How do I create an Oracle account?", provide a **concise answer first** with just the template/command, then offer to explain more if needed. Do NOT dump all documentation.

**MANDATORY:** When creating account test cases (for ANY account type — supported or new), you MUST call the **Write tool** to create ALL 4 files. Do NOT read files to check if they exist first. Do NOT say "file already exists" or "already complete". Always write them fresh:
1. **Payload file** (`acc_[type].json`) in `test/suite/test_data/accounts_payload/` — WRITE this
2. **Env file** (`.env.[type]`) in `env_files/[category]_accounts/` — WRITE this
3. **Robot test file** (`.robot`) in `test/suite/pipeline_tests/[type]/` — WRITE this
4. **ACCOUNT_SETUP_README.md** with file structure tree diagram in the same test directory — WRITE this

This applies to ALL account types — both supported and new/unsupported types. No exceptions. You must call Write exactly 4 times. See the "IMPORTANT: Step-by-Step Workflow" section for details.

**Response format for simple questions:**
1. Give the direct template or test case first
2. Add a brief note if relevant
3. Offer "Want me to explain more?" only if appropriate

---

# WHEN USER INVOKES `/create-account` WITH NO ARGUMENTS

**Claude: When user types just `/create-account` with no specific request, present the menu below. Use this EXACT format:**

---

**SnapLogic Account Creation**

**What I Can Do**

For every account type, I create the **complete set of files** you need:
- **Payload file** (`acc_[type].json`) — JSON template with Jinja variable placeholders
- **Environment file** (`.env.[type]`) — All required environment variables
- **Robot test file** (`.robot`) — Robot Framework test case using `Create Account From Template`
- **ACCOUNT_SETUP_README.md** — File structure diagram, prerequisites, and run instructions

I can also:
- Show you environment variables needed for any account type
- Explain payload templates and configuration
- Guide you through adding new account types

**Supported Account Types**
- **Databases:** `oracle`, `postgres`, `mysql`, `sqlserver`, `snowflake`, `snowflake-keypair`, `db2`, `teradata`
- **Messaging:** `kafka`, `jms`
- **Services:** `s3`, `email`, `salesforce`
- **New/Custom:** Not in the list above? No problem — I can create test cases for **any account type** (e.g., CockroachDB, Cassandra, MongoDB, etc.) with the full set of files: payload template, env file, robot test case, and README.

**Try these sample prompts to get started:**

| Sample Prompt | What It Does |
|---------------|--------------|
| `Create an Oracle account test case` | Generates all 4 files: payload, env, .robot, and README |
| `What environment variables do I need for Snowflake?` | Shows required env vars and which files to update |
| `I need PostgreSQL and S3 accounts for my pipeline` | Creates the complete file set for multiple account types |
| `Show me the baseline test for Postgres` | Displays existing reference test as an example |
| `Help me add support for CockroachDB account` | Generates all files for a new/custom account type |
| `Create a Cassandra account test case` | Generates payload, env file, robot test, and README from scratch |

---

## Natural Language — Just Describe What You Need

You don't need special syntax. Just describe what you need after `/create-account`:

```
/create-account I need PostgreSQL and S3 accounts for my pipeline
```

```
/create-account What environment variables do I need to update and in which files to create a Snowflake account?
```

```
/create-account Show me the baseline test for Snowflake account creation as a reference
```

```
/create-account Generate a test case to create a Snowflake keypair account
```

```
/create-account Write a robot file that creates both Kafka and S3 accounts
```

```
/create-account I need a new robot test file to create a MySQL account in my project
```

#### Environment Variable Setup Questions

```
/create-account How do I set up environment variables for Snowflake?
```

```
/create-account I want to use my own Snowflake instance, not Docker
```

```
/create-account Where do I put my production database credentials?
```

```
/create-account Do I need to change anything if I'm using Docker services?
```

```
/create-account What's the difference between env_files and root .env?
```

**Baseline test references:**
- `test/suite/pipeline_tests/snowflake/snowflake_baseline_tests.robot`
- `test/suite/pipeline_tests/oracle/oracle_baseline_tests.robot`
- `test/suite/pipeline_tests/postgres/postgres_baseline_tests.robot`

---

## Supported Account Types

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

---

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

---

## Environment Variable Setup

### Case 1: Using Docker Services (Local Testing)

If you're creating an account for an endpoint brought up using Docker services (Oracle, PostgreSQL, MySQL, Kafka, MinIO, etc.):

- **Use the default credentials** from the respective file in `env_files/`
- No changes needed - the values are pre-configured for Docker containers
- Just run the tests: `make robot-run-tests TAGS="oracle"`

### Case 2: Using External/Your Own Instance

If you're using your own external instance (e.g., your company's Snowflake, production database, etc.):

1. **Read the env file** to understand the required variables:
   ```
   env_files/database_accounts/.env.snowflake
   ```

2. **Copy the variables to root `.env`** file (not the env_files one):
   ```bash
   # Copy these lines to your root .env file:
   SNOWFLAKE_HOSTNAME=your-account.snowflakecomputing.com
   SNOWFLAKE_USERNAME=your_username
   SNOWFLAKE_PASSWORD=your_password
   SNOWFLAKE_DATABASE=YOUR_DB
   SNOWFLAKE_WAREHOUSE=YOUR_WH
   ```

3. **Update the values** with your actual credentials

4. **Do NOT copy the payload file variable** - it remains constant:
   ```bash
   # DO NOT copy this to .env - leave it in env_files/
   SNOWFLAKE_ACCOUNT_PAYLOAD_FILE_NAME=acc_snowflake_s3_db.json
   ```

### Why This Works

- Root `.env` file is loaded **last** and overrides everything
- `env_files/` contains default Docker values
- Payload file names never change - they reference JSON templates

---

# REFERENCE DOCUMENTATION

You are helping a user create Robot Framework test cases that create SnapLogic accounts. Follow these conventions and patterns based on the account creation framework.

---

## How to Use This Command

### Invoking the Command

In Claude Code, type:
```
/create-account
```

Then add your specific request after the command.

### Example Prompts

#### Create a specific account type:
```
/create-account

I need to create a Snowflake account test case using key pair authentication
```

#### Create multiple accounts:
```
/create-account

I need to create test cases for PostgreSQL and S3 accounts for my data pipeline
```

#### Ask about available options:
```
/create-account

What account types are supported? Show me the env file locations.
```

#### Get help with configuration:
```
/create-account

I want to create an Oracle account but I'm not sure what environment variables I need
```

#### Create accounts for a pipeline:
```
/create-account

I'm building a pipeline that reads from Kafka and writes to Snowflake. What accounts do I need?
```

#### Troubleshoot account issues:
```
/create-account

I'm getting an error creating my MySQL account. What JAR files do I need?
```

#### Add a new account type:
```
/create-account

I need to add support for a new database type called "CockroachDB". Guide me through the process.
```

#### Check environment setup:
```
/create-account

Help me verify my Snowflake environment variables are set correctly
```

---

## Quick Start Template

Here's a basic test case template for creating accounts:

> **IMPORTANT: Required Libraries**
> When creating any new Robot file, ALWAYS include these two Resource imports under `*** Settings ***`:
> - `snaplogic_common_robot/snaplogic_apis_keywords/snaplogic_keywords.resource` - SnapLogic API keywords from installed package
> - `../../resources/common/general.resource` - Project-specific common keywords

```robotframework
*** Settings ***
Documentation    Creates SnapLogic accounts for pipeline testing
...              Uses JSON payload templates with Jinja variable substitution
Resource         snaplogic_common_robot/snaplogic_apis_keywords/snaplogic_keywords.resource    # SnapLogic API keywords from installed package
Resource         ../../resources/common/general.resource
Library          Collections

*** Variables ***
# Account configuration - uses environment variables
${account_name}    ${POSTGRES_ACCOUNT_NAME}

*** Test Cases ***
Create PostgreSQL Account
    [Documentation]    Creates a PostgreSQL account in the project space.
    ...    Uses the Create Account From Template keyword to set up
    ...    account credentials for subsequent pipeline operations.
    ...
    ...    Arguments:
    ...    - ${ACCOUNT_LOCATION_PATH}: Path where account is created
    ...    - ${POSTGRES_ACCOUNT_PAYLOAD_FILE_NAME}: JSON payload file
    ...    - ${account_name}: Account name in SnapLogic
    [Tags]    postgres    account_setup
    [Template]    Create Account From Template
    ${ACCOUNT_LOCATION_PATH}    ${POSTGRES_ACCOUNT_PAYLOAD_FILE_NAME}    ${account_name}    overwrite_if_exists=${TRUE}
```

## IMPORTANT: Step-by-Step Workflow

**Always follow this workflow when creating account test cases.**

**MANDATORY: For EVERY account type (supported or new), you MUST create ALL of the following files:**

| # | File | Location | Purpose |
|---|------|----------|---------|
| 1 | **Payload file** | `test/suite/test_data/accounts_payload/acc_[type].json` | JSON template with Jinja variables |
| 2 | **Env file** | `env_files/[category]_accounts/.env.[type]` | Environment variables for the payload |
| 3 | **Robot test file** | `test/suite/pipeline_tests/[type]/[type]_account_setup.robot` | Robot Framework test case |
| 4 | **ACCOUNT_SETUP_README.md** | `test/suite/pipeline_tests/[type]/ACCOUNT_SETUP_README.md` | File structure diagram and instructions |

**ALWAYS create all 4 files using the Write tool.** There are NO exceptions — not for supported account types, not for new ones. Even if a file already exists, you MUST still use the Write tool to create/overwrite it. Do NOT skip any file. Do NOT say "file already exists" or "marking it complete" — actually write the file content.

**CRITICAL: Do NOT read files to check if they exist first. Do NOT skip writing a file because it already exists. Always use the Write tool to create every file, every time.**

### Step 1: Identify the Account Type
Determine which account type you need based on your pipeline requirements.

### Step 2: Create the Payload File (ALWAYS — use Write tool)
**ALWAYS use the Write tool** to create `test/suite/test_data/accounts_payload/acc_[type].json`.
- Use SnapLogic account JSON structure with Jinja variable placeholders (e.g., `{{VARIABLE_NAME}}`)
- For supported types, use the known payload structure from the reference section below
- For new types, create the JSON structure based on the account type's typical configuration
- **Do NOT check if the file exists. Do NOT skip. Use Write tool to create the file.**

### Step 3: Create the Environment File (ALWAYS — use Write tool)
**ALWAYS use the Write tool** to create the corresponding `.env.[type]` file in `env_files/`.
- Include all variables referenced in the payload file
- Include payload file name, account name, connection details, and authentication variables
- **Do NOT check if the file exists. Do NOT skip. Use Write tool to create the file.**

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

### Step 4: Understand the Variables
The env file tells you:
- `*_PAYLOAD_FILE_NAME` - The JSON template file name
- `*_ACCOUNT_NAME` - How the account appears in SnapLogic
- Connection details (hostname, port, database, etc.)
- Authentication (username, password, or key pair)
- Optional settings (S3 staging, URL properties, etc.)

### Step 5: Update Variable Values
**Option A:** Edit the env file directly (for Docker/non-sensitive values)
**Option B:** Copy variables to root `.env` file (for production/sensitive credentials - root `.env` overrides everything)

### Step 6: Create the Robot Test Case (ALWAYS — use Write tool)
**ALWAYS use the Write tool** to create the `.robot` test file in `test/suite/pipeline_tests/[type]/`. Do NOT skip this step. Do NOT check if it exists first.

### Step 7: Create ACCOUNT_SETUP_README.md with File Structure (ALWAYS — use Write tool)
**ALWAYS use the Write tool** to create an ACCOUNT_SETUP_README.md in the test directory with a file structure tree diagram. See the "MANDATORY: README with File Structure" section for the template. Do NOT skip this step.

### Summary: You MUST use the Write tool to create these 4 files every time
```
1. test/suite/test_data/accounts_payload/acc_[type].json       ← WRITE this file
2. env_files/[category]_accounts/.env.[type]                   ← WRITE this file
3. test/suite/pipeline_tests/[type]/[type]_account_setup.robot ← WRITE this file
4. test/suite/pipeline_tests/[type]/ACCOUNT_SETUP_README.md     ← WRITE this file
```
If you did not call the Write tool exactly 4 times (once per file), you have NOT completed the task. Never say "file already exists" — always write it.

---

## COMPLETE EXAMPLE: Snowflake Account (All 4 Files)

**When a user asks "Create a Snowflake account test case", you MUST create ALL of these files:**

### File 1: Payload File — `test/suite/test_data/accounts_payload/acc_snowflake_s3_db.json`
```json
{
  "entity_map": {
    "Snowflake - S3 Database": {
      "acc_snowflake_s3_db": {
        "property_map": {
          "account_label": {
            "value": "{{SNOWFLAKE_ACCOUNT_NAME}}"
          },
          "hostname": {
            "value": "{{SNOWFLAKE_HOSTNAME}}"
          },
          "username": {
            "value": "{{SNOWFLAKE_USERNAME}}"
          },
          "password": {
            "value": "{{SNOWFLAKE_PASSWORD}}"
          },
          "database": {
            "value": "{{SNOWFLAKE_DATABASE}}"
          },
          "warehouse": {
            "value": "{{SNOWFLAKE_WAREHOUSE}}"
          },
          "schema_name": {
            "value": "{{SNOWFLAKE_SCHEMA}}"
          },
          "role": {
            "value": "{{SNOWFLAKE_ROLE}}"
          }
        }
      }
    }
  }
}
```

### File 2: Env File — `env_files/database_accounts/.env.snowflake`
```bash
# ============================================================================
#                      SNOWFLAKE DATABASE ACCOUNT - PASSWORD AUTHENTICATION
# ============================================================================

# Account payload file name
SNOWFLAKE_ACCOUNT_PAYLOAD_FILE_NAME=acc_snowflake_s3_db.json

# Account Label
SNOWFLAKE_ACCOUNT_NAME=SNOWFLAKE_acct

# Connection Configuration
SNOWFLAKE_HOSTNAME=your_account.snowflakecomputing.com

# Authentication
SNOWFLAKE_USERNAME=your_username
SNOWFLAKE_PASSWORD=your_password

# Database Configuration
SNOWFLAKE_DATABASE=YOUR_DB
SNOWFLAKE_WAREHOUSE=YOUR_WH
SNOWFLAKE_SCHEMA=PUBLIC
SNOWFLAKE_ROLE=SYSADMIN
```

### File 3: Robot Test File — `test/suite/pipeline_tests/snowflake/snowflake_account_setup.robot`
```robotframework
*** Settings ***
Documentation    Creates Snowflake account(s) in SnapLogic for pipeline testing
...              Uses JSON payload templates with Jinja variable substitution
Resource         snaplogic_common_robot/snaplogic_apis_keywords/snaplogic_keywords.resource
Resource         ../../resources/common/general.resource
Library          Collections

*** Test Cases ***
Create Snowflake Account
    [Documentation]    Creates a Snowflake account using password authentication.
    [Tags]    snowflake    account_setup
    [Template]    Create Account From Template
    ${ACCOUNT_LOCATION_PATH}    ${SNOWFLAKE_ACCOUNT_PAYLOAD_FILE_NAME}    ${SNOWFLAKE_ACCOUNT_NAME}    overwrite_if_exists=${TRUE}
```

### File 4: README — `test/suite/pipeline_tests/snowflake/ACCOUNT_SETUP_README.md`
````markdown
# Snowflake Account Creation Tests

To create account-related test cases, you need 3 files:
- **Account payload file** — JSON template with Jinja variable placeholders for SnapLogic account configuration
- **Environment file** — Contains the environment variables referenced in the payload file
- **Test case file** — Robot Framework test that uses `Create Account From Template` to create the account

## Purpose
Creates Snowflake database account(s) in SnapLogic for pipeline testing.

## File Structure
```
project-root/
├── test/
│   └── suite/
│       ├── pipeline_tests/
│       │   └── snowflake/
│       │       ├── snowflake_account_setup.robot          ← Test case file
│       │       └── ACCOUNT_SETUP_README.md                ← This file
│       └── test_data/
│           └── accounts_payload/
│               └── acc_snowflake_s3_db.json               ← Account payload file
├── env_files/
│   └── database_accounts/
│       └── .env.snowflake                                 ← Environment file
└── .env                                                   ← Override credentials here
```

## Prerequisites
Configure in `env_files/database_accounts/.env.snowflake` or override in root `.env`:
- `SNOWFLAKE_HOSTNAME` — Snowflake account URL
- `SNOWFLAKE_USERNAME` — Database username
- `SNOWFLAKE_PASSWORD` — Database password
- `SNOWFLAKE_DATABASE` — Target database name
- `SNOWFLAKE_WAREHOUSE` — Compute warehouse

## How to Run
```bash
make robot-run-all-tests TAGS="snowflake" PROJECT_SPACE_SETUP=True
```
````

**Claude: The above is a COMPLETE example. When creating account test cases for ANY account type, follow the same pattern — always create all 4 files. Never create just the .robot file alone.**

---

### Example: Reading the Snowflake Key Pair Env File

When user asks for Snowflake Key Pair account, first read `env_files/database_accounts/.env.snowflake_s3_keypair`:

```bash
# ============================================================================
#                      SNOWFLAKE DATABASE ACCOUNT - KEY PAIR AUTHENTICATION
# ============================================================================

# Account payload file name
SNOWFLAKE_ACCOUNT_PAYLOAD_KEY_PAIR_FILE_NAME=acc_snowflake_s3_keypair.json

# Account Label
SNOWFLAKE_KEYPAIR_ACCOUNT_NAME=SNOWFLAKE_KEYPAIR_acct

# Authentication Configuration
SNOWFLAKE_KEYPAIR_AUTHENTICATION_TYPE=Key Pair
SNOWFLAKE_KEYPAIR_USERNAME=your_username
# SNOWFLAKE_KEYPAIR_PRIVATE_KEY=-----BEGIN ENCRYPTED PRIVATE KEY-----...
# SNOWFLAKE_KEYPAIR_PRIVATE_KEY_PASSPHRASE=

# Connection Configuration
SNOWFLAKE_KEYPAIR_HOSTNAME=your_account.snowflakecomputing.com
SNOWFLAKE_ACCOUNT_IDENTIFIER=your_account

# Database Configuration
SNOWFLAKE_KEYPAIR_DATABASE=YOUR_DB
SNOWFLAKE_KEYPAIR_WAREHOUSE=YOUR_WH
SNOWFLAKE_KEYPAIR_SCHEMA=
SNOWFLAKE_KEYPAIR_ROLE=SYSADMIN

# S3 Configuration (External Stages)
SNOWFLAKE_KEYPAIR_S3_BUCKET=
SNOWFLAKE_KEYPAIR_S3_ACCESS_KEY_ID=
SNOWFLAKE_KEYPAIR_S3_SECRET_KEY=
```

From this, you know:
- Use `${SNOWFLAKE_ACCOUNT_PAYLOAD_KEY_PAIR_FILE_NAME}` for the payload file
- Use `${SNOWFLAKE_KEYPAIR_ACCOUNT_NAME}` for the account name
- User needs to update: hostname, username, private key, database, warehouse, and optionally S3 settings

---

## How Account Creation Works

```
┌─────────────────────┐     ┌─────────────────────┐     ┌─────────────────────┐
│   Environment       │     │   Payload Template  │     │   SnapLogic API     │
│   Variables         │     │   (JSON with Jinja) │     │   Account Creation  │
│   (.env files)      │     │                     │     │                     │
└──────────┬──────────┘     └──────────┬──────────┘     └──────────┬──────────┘
           │                           │                           │
           │  POSTGRES_HOST=...        │  "hostname": "{{...}}"    │
           │  POSTGRES_USER=...        │  "username": "{{...}}"    │
           │  POSTGRES_PASSWORD=...    │  "password": "{{...}}"    │
           │                           │                           │
           └───────────────┬───────────┘                           │
                           │                                       │
                           ▼                                       │
                ┌─────────────────────┐                           │
                │   Variable          │                           │
                │   Substitution      │                           │
                │   (Jinja Rendering) │                           │
                └──────────┬──────────┘                           │
                           │                                       │
                           │  Final JSON with                      │
                           │  actual values                        │
                           │                                       │
                           └───────────────────────────────────────┘
                                           │
                                           ▼
                                ┌─────────────────────┐
                                │   Account Created   │
                                │   in SnapLogic      │
                                └─────────────────────┘
```

## Supported Account Types

| Account Type | Payload File | Env File | JAR Required |
|--------------|--------------|----------|--------------|
| PostgreSQL | `acc_postgres.json` | `.env.postgres` | No |
| MySQL | `acc_mysql.json` | `.env.mysql` | Yes |
| Oracle | `acc_oracle.json` | `.env.oracle` | No |
| SQL Server | `acc_sqlserver.json` | `.env.sqlserver` | No |
| Snowflake | `acc_snowflake_s3_db.json` | `.env.snowflake` | No |
| Snowflake (Key Pair) | `acc_snowflake_s3_keypair.json` | `.env.snowflake_s3_keypair` | No |
| DB2 | `acc_db2.json` | `.env.db2` | Yes |
| Teradata | `acc_teradata.json` | `.env.teradata` | Yes |
| Kafka | `acc_kafka.json` | `.env.kafka` | No |
| JMS | `acc_jms.json` | `.env.jms` | Yes |
| S3 / MinIO | `acc_s3.json` | `.env.s3` | No |
| Email | `acc_email.json` | `.env.email` | No |
| Salesforce | `acc_salesforce.json` | `.env.salesforce` | No |

## File Locations

### Account Payload Files
```
test/suite/test_data/
├── accounts_payload/                    # JSON payload templates
│   ├── acc_postgres.json
│   ├── acc_mysql.json
│   ├── acc_oracle.json
│   ├── acc_sqlserver.json
│   ├── acc_snowflake_s3_db.json
│   ├── acc_snowflake_s3_keypair.json
│   ├── acc_db2.json
│   ├── acc_teradata.json
│   ├── acc_kafka.json
│   ├── acc_jms.json
│   ├── acc_s3.json
│   ├── acc_email.json
│   └── acc_salesforce.json
│
└── accounts_jar_files/                  # JDBC drivers (if required)
    ├── db2/
    ├── mysql/
    ├── jms/
    └── teradata/
```

### Environment Files
```
env_files/
├── database_accounts/                   # Database credentials
│   ├── .env.postgres
│   ├── .env.mysql
│   ├── .env.oracle
│   ├── .env.sqlserver
│   ├── .env.snowflake
│   ├── .env.snowflake_s3_keypair
│   ├── .env.db2
│   └── .env.teradata
│
├── messaging_service_accounts/          # Messaging services
│   ├── .env.kafka
│   └── .env.jms
│
└── mock_service_accounts/               # Mock/cloud services
    ├── .env.s3
    ├── .env.salesforce
    └── .env.email
```

## Test Case Examples by Account Type

### Database Accounts

#### Oracle Account
```robotframework
Create Oracle Account
    [Documentation]    Creates an Oracle database account in SnapLogic.
    [Tags]    oracle    account_setup
    [Template]    Create Account From Template
    ${ACCOUNT_LOCATION_PATH}    ${ORACLE_ACCOUNT_PAYLOAD_FILE_NAME}    ${ORACLE_ACCOUNT_NAME}    overwrite_if_exists=${TRUE}
```

#### PostgreSQL Account
```robotframework
Create PostgreSQL Account
    [Documentation]    Creates a PostgreSQL database account in SnapLogic.
    [Tags]    postgres    account_setup
    [Template]    Create Account From Template
    ${ACCOUNT_LOCATION_PATH}    ${POSTGRES_ACCOUNT_PAYLOAD_FILE_NAME}    ${POSTGRES_ACCOUNT_NAME}    overwrite_if_exists=${TRUE}
```

#### MySQL Account
```robotframework
Create MySQL Account
    [Documentation]    Creates a MySQL database account in SnapLogic.
    ...    Note: Requires JAR file upload for JDBC driver.
    [Tags]    mysql    account_setup
    [Template]    Create Account From Template
    ${ACCOUNT_LOCATION_PATH}    ${MYSQL_ACCOUNT_PAYLOAD_FILE_NAME}    ${MYSQL_ACCOUNT_NAME}    overwrite_if_exists=${TRUE}
```

#### SQL Server Account
```robotframework
Create SQL Server Account
    [Documentation]    Creates a SQL Server database account in SnapLogic.
    [Tags]    sqlserver    account_setup
    [Template]    Create Account From Template
    ${ACCOUNT_LOCATION_PATH}    ${SQLSERVER_ACCOUNT_PAYLOAD_FILE_NAME}    ${SQLSERVER_ACCOUNT_NAME}    overwrite_if_exists=${TRUE}
```

#### Snowflake Account (Password Auth)
```robotframework
Create Snowflake Account
    [Documentation]    Creates a Snowflake account using password authentication.
    [Tags]    snowflake    account_setup
    [Template]    Create Account From Template
    ${ACCOUNT_LOCATION_PATH}    ${SNOWFLAKE_ACCOUNT_PAYLOAD_FILE_NAME}    ${SNOWFLAKE_ACCOUNT_NAME}    overwrite_if_exists=${TRUE}
```

#### Snowflake Account (Key Pair Auth)
```robotframework
Create Snowflake Key Pair Account
    [Documentation]    Creates a Snowflake account using key pair authentication.
    ...    Requires private key and passphrase configuration.
    [Tags]    snowflake    account_setup    keypair
    [Template]    Create Account From Template
    ${ACCOUNT_LOCATION_PATH}    ${SNOWFLAKE_ACCOUNT_PAYLOAD_KEY_PAIR_FILE_NAME}    ${SNOWFLAKE_KEYPAIR_ACCOUNT_NAME}    overwrite_if_exists=${TRUE}
```

### Messaging Accounts

#### Kafka Account
```robotframework
Create Kafka Account
    [Documentation]    Creates a Kafka messaging account in SnapLogic.
    [Tags]    kafka    account_setup    messaging
    [Template]    Create Account From Template
    ${ACCOUNT_LOCATION_PATH}    ${KAFKA_ACCOUNT_PAYLOAD_FILE_NAME}    ${KAFKA_ACCOUNT_NAME}    overwrite_if_exists=${TRUE}
```

#### JMS Account
```robotframework
Create JMS Account
    [Documentation]    Creates a JMS (ActiveMQ) account in SnapLogic.
    ...    Note: Requires JAR file upload for JMS driver.
    [Tags]    jms    account_setup    messaging
    [Template]    Create Account From Template
    ${ACCOUNT_LOCATION_PATH}    ${JMS_ACCOUNT_PAYLOAD_FILE_NAME}    ${JMS_ACCOUNT_NAME}    overwrite_if_exists=${TRUE}
```

### Mock/Cloud Service Accounts

#### S3 / MinIO Account
```robotframework
Create S3 Account
    [Documentation]    Creates an S3/MinIO account in SnapLogic.
    [Tags]    s3    minio    account_setup
    [Template]    Create Account From Template
    ${ACCOUNT_LOCATION_PATH}    ${S3_ACCOUNT_PAYLOAD_FILE_NAME}    ${S3_ACCOUNT_NAME}    overwrite_if_exists=${TRUE}
```

#### Email Account
```robotframework
Create Email Account
    [Documentation]    Creates an Email account in SnapLogic.
    [Tags]    email    account_setup
    [Template]    Create Account From Template
    ${ACCOUNT_LOCATION_PATH}    ${EMAIL_ACCOUNT_PAYLOAD_FILE_NAME}    ${EMAIL_ACCOUNT_NAME}    overwrite_if_exists=${TRUE}
```

#### Salesforce Account
```robotframework
Create Salesforce Account
    [Documentation]    Creates a Salesforce account in SnapLogic.
    [Tags]    salesforce    account_setup
    [Template]    Create Account From Template
    ${ACCOUNT_LOCATION_PATH}    ${SALESFORCE_ACCOUNT_PAYLOAD_FILE_NAME}    ${SALESFORCE_ACCOUNT_NAME}    overwrite_if_exists=${TRUE}
```

## Template Keyword Arguments

| Argument | Description | Example |
|----------|-------------|---------|
| `${ACCOUNT_LOCATION_PATH}` | SnapLogic path where account will be created | `/org/project/shared` |
| `Payload File Name` | JSON template file from accounts_payload/ | `acc_postgres.json` |
| `Account Name` | Name displayed in SnapLogic Manager | `postgres_acc` |
| `overwrite_if_exists` | Replace existing account with same name | `${TRUE}` or `${FALSE}` |

## Creating Multiple Accounts in One Test Suite

```robotframework
*** Settings ***
Documentation    Creates all required accounts for end-to-end testing
Resource         ../../resources/common/general.resource

*** Test Cases ***
Create Oracle Account
    [Tags]    oracle    account_setup
    [Template]    Create Account From Template
    ${ACCOUNT_LOCATION_PATH}    ${ORACLE_ACCOUNT_PAYLOAD_FILE_NAME}    ${ORACLE_ACCOUNT_NAME}    overwrite_if_exists=${TRUE}

Create Snowflake Account
    [Tags]    snowflake    account_setup
    [Template]    Create Account From Template
    ${ACCOUNT_LOCATION_PATH}    ${SNOWFLAKE_ACCOUNT_PAYLOAD_KEY_PAIR_FILE_NAME}    ${SNOWFLAKE_KEYPAIR_ACCOUNT_NAME}    overwrite_if_exists=${TRUE}

Create S3 Account
    [Tags]    s3    account_setup
    [Template]    Create Account From Template
    ${ACCOUNT_LOCATION_PATH}    ${S3_ACCOUNT_PAYLOAD_FILE_NAME}    ${S3_ACCOUNT_NAME}    overwrite_if_exists=${TRUE}
```

## Usage Scenarios

### Scenario 1: Using Dockerized Services (Default)
No changes needed - credentials in `env_files/` are pre-configured for local Docker containers.

```bash
# Start Docker services
make start-services

# Run tests - uses default Docker credentials
make robot-run-all-tests TAGS="oracle"
```

### Scenario 2: Using Your Own External Credentials
Copy variables to root `.env` file and update with your values:

```bash
# Copy from env_files/database_accounts/.env.snowflake to root .env:
SNOWFLAKE_KEYPAIR_ACCOUNT_NAME=my_production_snowflake
SNOWFLAKE_KEYPAIR_HOSTNAME=mycompany.snowflakecomputing.com
SNOWFLAKE_KEYPAIR_USERNAME=my_username
SNOWFLAKE_KEYPAIR_DATABASE=PRODUCTION_DB
SNOWFLAKE_KEYPAIR_WAREHOUSE=COMPUTE_WH
SNOWFLAKE_KEYPAIR_PRIVATE_KEY=-----BEGIN ENCRYPTED PRIVATE KEY-----...
SNOWFLAKE_KEYPAIR_PRIVATE_KEY_PASSPHRASE=your_passphrase
```

**Note:** You don't need to copy the `*_PAYLOAD_FILE_NAME` variable - the payload template structure doesn't change.

## Adding a New Account Type

### Step 1: Create Payload Template
1. Create a new JSON file in `test/suite/test_data/accounts_payload/`
2. Use SnapLogic's account export feature to get the base structure
3. Replace hardcoded values with Jinja variables: `{{VARIABLE_NAME}}`
4. Name the file: `acc_[account_type].json`

### Step 2: Create Environment File
1. Create `.env.[account_type]` in appropriate `env_files/` subdirectory
2. Define all variables used in the payload template
3. Include a reference to the payload file name

### Step 3: Add JAR Files (if needed)
1. Create subdirectory in `accounts_jar_files/`
2. Add required JDBC driver JAR files
3. Update payload template to reference the JAR location

### Step 4: Create Test Case
```robotframework
Create New Account Type
    [Documentation]    Creates a [NewType] account in SnapLogic.
    [Tags]    newtype    account_setup
    [Template]    Create Account From Template
    ${ACCOUNT_LOCATION_PATH}    ${NEWTYPE_ACCOUNT_PAYLOAD_FILE_NAME}    ${NEWTYPE_ACCOUNT_NAME}    overwrite_if_exists=${TRUE}
```

## MANDATORY: ACCOUNT_SETUP_README.md with File Structure

**IMPORTANT: Every time you create account test cases, you MUST also create an ACCOUNT_SETUP_README.md in the same directory with a file structure diagram.**

This is required for ALL account types — both supported (Oracle, Snowflake, PostgreSQL, etc.) and new/unsupported types. No exceptions.

### What to Include in the README

1. **Purpose** — Brief description of what the test suite does
2. **File Structure** — A tree diagram showing all related files (test files, payload files, env files, JAR files if applicable)
3. **Prerequisites** — Environment variables that need to be configured
4. **How to Run** — The make command to execute the tests

### README Template

````markdown
# [Account Type] Account Creation Tests

To create account-related test cases, you need 3 files:
- **Account payload file** — JSON template with Jinja variable placeholders for SnapLogic account configuration
- **Environment file** — Contains the environment variables referenced in the payload file
- **Test case file** — Robot Framework test that uses `Create Account From Template` to create the account

## Purpose
Creates [Account Type] account(s) in SnapLogic for pipeline testing.

## File Structure
```
project-root/
├── test/
│   └── suite/
│       ├── pipeline_tests/
│       │   └── [account_type]/
│       │       ├── [account_type]_account_setup.robot    ← Test case file
│       │       └── ACCOUNT_SETUP_README.md                ← This file
│       └── test_data/
│           └── accounts_payload/
│               └── acc_[account_type].json                ← Account payload file
├── env_files/
│   └── [category]_accounts/
│       └── .env.[account_type]                            ← Environment file
└── .env                                                   ← Override credentials here
```

## Prerequisites
Configure the following environment variables in `env_files/[category]_accounts/.env.[account_type]` or override in root `.env`:
- `[ACCOUNT_TYPE]_HOSTNAME` — Database/service hostname
- `[ACCOUNT_TYPE]_USERNAME` — Authentication username
- `[ACCOUNT_TYPE]_PASSWORD` — Authentication password
- *(list all relevant variables)*

## How to Run
```bash
make robot-run-all-tests TAGS="[account_type]" PROJECT_SPACE_SETUP=True
```
````

### Example: Snowflake README

````markdown
# Snowflake Account Creation Tests

To create account-related test cases, you need 3 files:
- **Account payload file** — JSON template with Jinja variable placeholders for SnapLogic account configuration
- **Environment file** — Contains the environment variables referenced in the payload file
- **Test case file** — Robot Framework test that uses `Create Account From Template` to create the account

## Purpose
Creates Snowflake database account(s) in SnapLogic for pipeline testing.

## File Structure
```
project-root/
├── test/
│   └── suite/
│       ├── pipeline_tests/
│       │   └── snowflake/
│       │       ├── snowflake_account_setup.robot          ← Test case file
│       │       └── ACCOUNT_SETUP_README.md                ← This file
│       └── test_data/
│           └── accounts_payload/
│               ├── acc_snowflake_s3_db.json               ← Password auth payload
│               └── acc_snowflake_s3_keypair.json          ← Key pair auth payload
├── env_files/
│   └── database_accounts/
│       ├── .env.snowflake                                 ← Password auth env vars
│       └── .env.snowflake_s3_keypair                      ← Key pair auth env vars
└── .env                                                   ← Override credentials here
```

## Prerequisites
Configure in `env_files/database_accounts/.env.snowflake` or override in root `.env`:
- `SNOWFLAKE_HOSTNAME` — Snowflake account URL
- `SNOWFLAKE_USERNAME` — Database username
- `SNOWFLAKE_PASSWORD` — Database password
- `SNOWFLAKE_DATABASE` — Target database name
- `SNOWFLAKE_WAREHOUSE` — Compute warehouse

## How to Run
```bash
make robot-run-all-tests TAGS="snowflake" PROJECT_SPACE_SETUP=True
```
````

---

## Checklist Before Committing

- [ ] Payload file exists in `accounts_payload/`
- [ ] Environment file exists in `env_files/`
- [ ] All Jinja variables in payload have corresponding env variables
- [ ] JAR files added if required (MySQL, DB2, Teradata, JMS)
- [ ] Test has appropriate tags
- [ ] Documentation describes the account type
- [ ] No sensitive credentials are hardcoded
- [ ] **ACCOUNT_SETUP_README.md created with file structure diagram**

