

# Robot Framework Test Execution Flow

This document provides a comprehensive overview of what happens when Robot Framework tests are executed in the SnapLogic automation framework, detailing the initialization process, directory structure, and execution sequence.

---

## Table of Contents
- [Project Structure Overview](#project-structure-overview)
- [Test Execution Initialization Process](#test-execution-initialization-process)
  - [Phase 1: Suite Setup Initialization](#phase-1-suite-setup-initialization)
  - [Phase 2: Environment Configuration](#phase-2-environment-configuration)
  - [Phase 3: Project Infrastructure Setup](#phase-3-project-infrastructure-setup)
  - [Phase 4: Test Execution](#phase-4-test-execution)
  - [Phase 5: Output Generation](#phase-5-output-generation)
- [Key Features of the Initialization Process](#key-features-of-the-initialization-process)
- [Best Practices for Test Development](#best-practices-for-test-development)

---

## Project Structure Overview

### Test Directory Structure
```
/Users/spothana/QADocs/SLIM_TEST_EXAMPLE4/snaplogic-test-example/
├── test/                           # All tests and test data
│   ├── suite/                      # Main test suite directory
│   │   ├── __init__.robot         # Suite initialization file (CRITICAL)
│   │   ├── pipeline_tests/        # Individual test files
│   │   │   ├── ML_Oracle.robot
│   │   │   ├── ML_minio.robot
│   │   │   ├── Postgres_To_S3.robot
│   │   │   ├── common_pipeline.robot
│   │   │   └── create_plex.robot
│   │   └── test_data/             # Test payloads and data
│   │       ├── accounts_payload/  # Account configuration files
│   │       │   ├── acc_oracle.json
│   │       │   ├── acc_postgres.json
│   │       │   └── acc_s3.json
│   │       └── queries/           # SQL queries and resources
│   ├── robot_output/              # Test execution results
│   └── .config/                   # Configuration files
└── src/                           # Pipeline source files
    └── pipelines/                 # SnapLogic pipeline files (.slp)
        ├── ML_Oracle.slp
        ├── ML_minio.slp
        ├── ML_Postgres.slp
        └── Postgres_to_S3.slp
```

---

## Test Execution Initialization Process

### Phase 1: Suite Setup Initialization

When Robot Framework tests start execution, the **first and most critical step** is loading the suite initialization file:

**File Path:** `test/suite/__init__.robot`

This file acts as the entry point and performs the following essential operations:

---

### 1. Library and Resource Loading

```robot
*** Settings ***
Library         OperatingSystem
Library         BuiltIn
Library         Process
Library         JSONLibrary
Resource        snaplogic_common_robot/snaplogic_apis_keywords/snaplogic_keywords.resource
```

The `snaplogic_common_robot/snaplogic_apis_keywords/snaplogic_keywords.resource` file is part of the `snaplogic-common-robot` library, which is installed via `requirements.txt`. This library contains reusable Robot Framework keywords specifically designed to interact with the SnapLogic APIs and simplify test development.

- Loads core libraries and SnapLogic-specific keywords

---

### 2. Global Variable Declaration

```robot
*** Variables ***
${ACCOUNT_PAYLOAD_PATH}     /app/test/suite/test_data/accounts_payload
${ENV_FILE_PATH}            /app/.env
```

- Sets reusable paths for payloads and environment config

---

### 3. Suite Setup Execution

```robot
Suite Setup     Before Suite
```

- Automatically triggers `Before Suite` keyword before tests

---

## Phase 2: Environment Configuration

### `Load Environment Variables` Keyword

#### File Validation
- Verifies the existence of `.env`
- Aborts if missing

#### Smart Variable Parsing
- Skips comments and blanks
- Attempts JSON parse on values:
  ```robot
  ${status}    ${json_result}=    Run Keyword And Ignore Error
      Evaluate    json.loads(r'''${var_value}''')    json
  ```

#### Data Type Mapping
- 🧾 JSON Dictionaries → `&{variable}`
- 📜 JSON Lists → `@{variable}`
- 🔢 Primitives → `${variable}`
- 🔤 Plain Strings → `${variable}`

#### Environment Variable Registration
- Makes variables available as both env vars and RF vars

---

### Environment Variable Validation

```robot
@{required_env_vars}=    Create List
    URL
    ORG_ADMIN_USER
    ORG_ADMIN_PASSWORD
    ORG_NAME
    PROJECT_SPACE
    PROJECT_NAME
    GROUNDPLEX_NAME
    GROUNDPLEX_ENV
    RELEASE_BUILD_VERSION
```

Validation logic:
```robot
IF    ${missing_count} > 0
    ${missing_vars_str}=    Evaluate    ", ".join($missing_vars)
    Fail
        Missing required environment variables: ${missing_vars_str}. 
        Please check your .env file and ensure all required variables are defined.
END
```

---

### Global Variable Setup

```robot
Set Global Variable    ${ACCOUNT_PAYLOAD_PATH}
Set Global Variable    ${ENV_FILE_PATH}
Set Global Variable    ${ORG_NAME}
```

- Ensures key variables are shared across tests

---

## Phase 3: Project Infrastructure Setup

### Conditional Execution Using `PROJECT_SPACE_SETUP`

```robot
Set Up Data
    ${URL}
    ${ORG_ADMIN_USER}
    ${ORG_ADMIN_PASSWORD}
    ${ORG_NAME}
    ${PROJECT_SPACE}
    ${PROJECT_NAME}
    ${ENV_FILE_PATH}
```

When `PROJECT_SPACE_SETUP=True`, the following occurs:
- Deletes existing project space
- Creates project space and project
- Creates required accounts

---

## Phase 4: Test Execution

### Tag-Based Execution

Sample tags from `ML_Oracle.robot`:
```robot
[Tags]    create_account    oracle
[Tags]    import_pipeline2    oracle
[Tags]    create_triggered_task    oracle
[Tags]    end_to_end_workflow    import_pipeline    oracle2
```

#### Running Examples
- `TAGS="oracle"`
- `TAGS="createplex"`
- `TAGS="minio"`

---

### Test File Setup

```robot
Suite Setup         Check connections
```

---

### Resource Utilization

- Account payloads: `test_data/accounts_payload/*.json`
- Pipelines: `src/pipelines/*.slp`
- SQL queries: `test_data/queries/*.sql`

---

## Phase 5: Output Generation

### Output Directory

Results written to `robot_output/`:
- `report-[timestamp].html`
- `log-[timestamp].html`
- `output-[timestamp].xml`

---

## Key Features of the Initialization Process

### ✅ Fail-Fast Validation
Immediate exit on missing config

### 🔄 Dynamic Variable Handling
Supports JSON parsing and fallback

### 🔁 Conditional Infra Setup
Toggle via `PROJECT_SPACE_SETUP`

### 🌐 Global Resource Management
Shared paths, consistent access

### 📊 Comprehensive Logging
Tracks each setup and run phase

---

## Best Practices for Test Development

### ✅ Environment Configuration
- Define all required keys in `.env`
- Use JSON for complex data
- Comment your `.env` for clarity

### 🧱 Test Organization
- Organize test data into subfolders
- Follow naming conventions
- Use meaningful tags

### 🧪 Pipeline Management
- Store `.slp` files in `src/pipelines/`
- Match names with test files
- Validate accessibility during test runs

---

This initialization process ensures that every test execution starts with a properly configured environment, validated settings, and the necessary infrastructure components, providing a reliable foundation for comprehensive SnapLogic automation testing.