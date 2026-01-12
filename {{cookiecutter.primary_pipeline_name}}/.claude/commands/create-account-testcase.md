---
description: Guide for creating Robot Framework test cases that create SnapLogic accounts
---

# COMMAND ACTIONS (Claude: Read this first!)

## Available Commands

| Command | Action |
|---------|--------|
| `/create-account-testcase` | Default menu with quick options |
| `/create-account-testcase info` | Full menu with all commands and account types |
| `/create-account-testcase list` | Table of supported account types |
| `/create-account-testcase template` | Generic test case template |
| `/create-account-testcase create oracle` | Create Oracle account test case |
| `/create-account-testcase create postgres` | Create PostgreSQL account test case |
| `/create-account-testcase create snowflake` | Create Snowflake account test case (password auth) |
| `/create-account-testcase create snowflake-keypair` | Create Snowflake account test case (key pair auth) |
| `/create-account-testcase check snowflake` | Check Snowflake env variables |

### Natural Language Examples

You can also use natural language:

```
/create-account-testcase I need PostgreSQL and S3 accounts for my pipeline
```

```
/create-account-testcase What environment variables do I need to update and in which files to create a Snowflake account?
```

```
/create-account-testcase Show me the baseline test for Snowflake account creation as a reference
```

#### Create Test Case for Account Creation

```
/create-account-testcase Create a robot test file for Oracle account creation
```

```
/create-account-testcase Generate a test case to create a Snowflake keypair account
```

```
/create-account-testcase Write a robot file that creates both Kafka and S3 accounts
```

```
/create-account-testcase I need a new robot test file to create a MySQL account in my project
```

#### Environment Variable Setup Questions

```
/create-account-testcase How do I set up environment variables for Snowflake?
```

```
/create-account-testcase I want to use my own Snowflake instance, not Docker
```

```
/create-account-testcase Where do I put my production database credentials?
```

```
/create-account-testcase Do I need to change anything if I'm using Docker services?
```

```
/create-account-testcase What's the difference between env_files and root .env?
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
/create-account-testcase
```

Then add your specific request after the command.

### Example Prompts

#### Create a specific account type:
```
/create-account-testcase

I need to create a Snowflake account test case using key pair authentication
```

#### Create multiple accounts:
```
/create-account-testcase

I need to create test cases for PostgreSQL and S3 accounts for my data pipeline
```

#### Ask about available options:
```
/create-account-testcase

What account types are supported? Show me the env file locations.
```

#### Get help with configuration:
```
/create-account-testcase

I want to create an Oracle account but I'm not sure what environment variables I need
```

#### Create accounts for a pipeline:
```
/create-account-testcase

I'm building a pipeline that reads from Kafka and writes to Snowflake. What accounts do I need?
```

#### Troubleshoot account issues:
```
/create-account-testcase

I'm getting an error creating my MySQL account. What JAR files do I need?
```

#### Add a new account type:
```
/create-account-testcase

I need to add support for a new database type called "CockroachDB". Guide me through the process.
```

#### Check environment setup:
```
/create-account-testcase

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

**Always follow this workflow when creating account test cases:**

### Step 1: Identify the Account Type
Determine which account type you need based on your pipeline requirements.

### Step 2: Check the Environment File FIRST
**This is critical!** Before writing any test case, read the corresponding `.env` file to understand what variables are available:

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

### Step 3: Understand the Variables
The env file tells you:
- `*_PAYLOAD_FILE_NAME` - The JSON template file name
- `*_ACCOUNT_NAME` - How the account appears in SnapLogic
- Connection details (hostname, port, database, etc.)
- Authentication (username, password, or key pair)
- Optional settings (S3 staging, URL properties, etc.)

### Step 4: Update Variable Values
**Option A:** Edit the env file directly (for Docker/non-sensitive values)
**Option B:** Copy variables to root `.env` file (for production/sensitive credentials - root `.env` overrides everything)

### Step 5: Create the Test Case
Use the variables from the env file in your Robot Framework test case.

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

## Checklist Before Committing

- [ ] Payload file exists in `accounts_payload/`
- [ ] Environment file exists in `env_files/`
- [ ] All Jinja variables in payload have corresponding env variables
- [ ] JAR files added if required (MySQL, DB2, Teradata, JMS)
- [ ] Test has appropriate tags
- [ ] Documentation describes the account type
- [ ] No sensitive credentials are hardcoded

