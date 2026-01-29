---
name: upload-file
description: Creates Robot Framework test cases for uploading files to SnapLogic SLDB. Use when the user wants to upload files (JSON, CSV, expression libraries, pipelines, JAR files, etc.), needs to know which destination path to use, or wants to see file upload test case examples.
user-invocable: true
---

# Upload File Test Case Guide

## Claude Instructions

**IMPORTANT:** When user asks a simple question like "How do I upload a JSON file?", provide a **concise answer first** with just the template/command, then offer to explain more if needed. Do NOT dump all documentation.

**Response format for simple questions:**
1. Give the direct template or test case first
2. Add a brief note if relevant
3. Offer "Want me to explain more?" only if appropriate

---

# COMMAND ACTIONS (Claude: Read this first!)

## Available Commands

| Command | Action |
|---------|--------|
| `/upload-file-testcase` | Default menu with quick options |
| `/upload-file-testcase info` | Full menu with all commands and file types |
| `/upload-file-testcase template` | Generic upload test case template |
| `/upload-file-testcase create json` | Create JSON file upload test case |
| `/upload-file-testcase create csv` | Create CSV file upload test case |
| `/upload-file-testcase create expr` | Create expression library upload test case |
| `/upload-file-testcase create slp` | Create pipeline file upload test case |
| `/upload-file-testcase create jar` | Create JAR file upload test case |

### Natural Language Examples

You can also use natural language:

```
/upload-file-testcase I need to upload a JSON test input file to my project
```

```
/upload-file-testcase How do I upload an expression library to the shared folder?
```

```
/upload-file-testcase Show me how to upload multiple files in one test case
```

#### Upload Test Case Examples

```
/upload-file-testcase Create a robot test to upload CSV files to SnapLogic
```

```
/upload-file-testcase Generate a test case to upload expression libraries
```

```
/upload-file-testcase Write a robot file that uploads JAR files to the shared folder
```

#### Environment Variable Questions

```
/upload-file-testcase What's the difference between PIPELINES_LOCATION_PATH and ACCOUNT_LOCATION_PATH?
```

```
/upload-file-testcase Where should I upload expression libraries?
```

```
/upload-file-testcase What destination path should I use for test input files?
```

**Baseline test references:**
- `test/suite/pipeline_tests/snowflake/snowflake_baseline_tests.robot`
- `test/suite/pipeline_tests/oracle/oracle.robot`
- `test/suite/pipeline_tests/kafka/kafka_snowflake_tests.robot`

---

## What is SLDB?

**SLDB (SnapLogic Database)** is SnapLogic's internal file storage system. When you upload files to a SnapLogic project space, they are stored in SLDB and can be referenced using paths like:
- `sldb:///org/project_space/project/filename.json`
- `sldb:///org/project_space/shared/expression_library.expr`

Files uploaded to SLDB can be:
- Referenced by pipelines during execution
- Used as input data for pipeline testing
- Shared across multiple pipelines in a project

---

## Supported File Types

| File Type | Extension | Typical Destination | Use Case |
|-----------|-----------|---------------------|----------|
| JSON | `.json` | `${PIPELINES_LOCATION_PATH}` | Test input data |
| CSV | `.csv` | `${PIPELINES_LOCATION_PATH}` | Test input data |
| Expression Library | `.expr` | `${ACCOUNT_LOCATION_PATH}` | Shared functions |
| Pipeline | `.slp` | `${PIPELINES_LOCATION_PATH}` | Pipeline definitions |
| JAR Files | `.jar` | `${ACCOUNT_LOCATION_PATH}` | JDBC drivers |
| XML | `.xml` | `${PIPELINES_LOCATION_PATH}` | Configuration files |
| Text | `.txt` | `${PIPELINES_LOCATION_PATH}` | Test data |

---

## Key Environment Variables

| Variable | Description | Example Value |
|----------|-------------|---------------|
| `${PIPELINES_LOCATION_PATH}` | Project folder path for pipelines and test data | `ml-legacy-migration/slim-travis-automation-ps/slim_travis_project` |
| `${ACCOUNT_LOCATION_PATH}` | Shared folder path for accounts, JARs, expr libs | `ml-legacy-migration/slim-travis-automation-ps/shared` |
| `${ORG_NAME}` | SnapLogic organization name | `ml-legacy-migration` |
| `${PROJECT_SPACE}` | Project space name | `slim-travis-automation-ps` |
| `${PROJECT_NAME}` | Project name | `slim_travis_project` |

### When to Use Each Path

| Destination | Use For |
|-------------|---------|
| `${PIPELINES_LOCATION_PATH}` | Test input files, pipelines, project-specific files |
| `${ACCOUNT_LOCATION_PATH}` | Expression libraries, JAR files, shared resources |

---

## Quick Start Template

Here's a basic test case template for uploading files:

> **IMPORTANT: Required Libraries**
> When creating any new Robot file, ALWAYS include these Resource imports under `*** Settings ***`:
> - `snaplogic_common_robot/snaplogic_apis_keywords/snaplogic_keywords.resource` - SnapLogic API keywords from installed package
> - `../../resources/common/files.resource` - File operation keywords including upload template

```robotframework
*** Settings ***
Documentation    Uploads files to SnapLogic SLDB for pipeline testing
Resource         snaplogic_common_robot/snaplogic_apis_keywords/snaplogic_keywords.resource
Resource         ../../resources/common/files.resource
Resource         ../../resources/common/general.resource
Library          Collections
Library          OperatingSystem

*** Variables ***
# Input file paths (local)
${input_file_name}              test_input.json
${input_file_path}              ${CURDIR}/../../test_data/actual_expected_data/input_data/${input_file_name}

*** Test Cases ***
Upload Test Input File
    [Documentation]    Uploads test input file to SnapLogic project folder.
    ...    Files are stored in SLDB and can be referenced by pipelines.
    ...
    ...    Arguments:
    ...    - Local file path: Path to the file on local filesystem
    ...    - Destination path: SnapLogic path where file will be uploaded
    [Tags]    upload    setup
    [Template]    Upload File Using File Protocol Template
    ${input_file_path}    ${PIPELINES_LOCATION_PATH}
```

---

## How File Upload Works

```
┌─────────────────────┐     ┌─────────────────────┐     ┌─────────────────────┐
│   Local File        │     │   Upload Keyword    │     │   SnapLogic SLDB    │
│   System            │     │                     │     │                     │
└──────────┬──────────┘     └──────────┬──────────┘     └──────────┬──────────┘
           │                           │                           │
           │  ${CURDIR}/data/test.json │                           │
           │                           │                           │
           └───────────────────────────┘                           │
                           │                                       │
                           │  Upload File Using                    │
                           │  File Protocol Template               │
                           │                                       │
                           └───────────────────────────────────────┘
                                           │
                                           ▼
                                ┌─────────────────────┐
                                │   File Available    │
                                │   in SnapLogic at:  │
                                │   sldb:///org/ps/   │
                                │   project/test.json │
                                └─────────────────────┘
```

---

## Test Case Examples by File Type

### JSON Input Files

```robotframework
Upload JSON Test Input File
    [Documentation]    Uploads JSON test input file to SnapLogic project folder.
    [Tags]    upload    json    setup
    [Template]    Upload File Using File Protocol Template
    ${CURDIR}/../../test_data/actual_expected_data/input_data/snowflake/test_input.json    ${PIPELINES_LOCATION_PATH}
```

### CSV Input Files

```robotframework
Upload CSV Test Data
    [Documentation]    Uploads CSV test data file to SnapLogic project folder.
    [Tags]    upload    csv    setup
    [Template]    Upload File Using File Protocol Template
    ${CURDIR}/../../test_data/actual_expected_data/input_data/test_data.csv    ${PIPELINES_LOCATION_PATH}
```

### Expression Libraries

```robotframework
Upload Expression Library
    [Documentation]    Uploads expression library (.expr) to shared folder.
    ...    Expression libraries contain reusable functions that can be
    ...    referenced across multiple pipelines in the project.
    [Tags]    upload    expr    setup
    [Template]    Upload File Using File Protocol Template
    ${CURDIR}/../../test_data/actual_expected_data/expression_libraries/my_library.expr    ${ACCOUNT_LOCATION_PATH}
```

### Multiple Files in One Test Case

```robotframework
Upload Multiple Test Files
    [Documentation]    Uploads multiple files to SnapLogic using data-driven approach.
    ...    Each row represents a file upload operation.
    [Tags]    upload    setup    multi_file
    [Template]    Upload File Using File Protocol Template
    # local file path                                                                      destination_path
    ${CURDIR}/../../test_data/actual_expected_data/input_data/snowflake/test_input1.json    ${PIPELINES_LOCATION_PATH}
    ${CURDIR}/../../test_data/actual_expected_data/input_data/snowflake/test_input2.json    ${PIPELINES_LOCATION_PATH}
    ${CURDIR}/../../test_data/actual_expected_data/input_data/snowflake/test_input3.json    ${PIPELINES_LOCATION_PATH}
    ${CURDIR}/../../test_data/actual_expected_data/expression_libraries/snowflake/snowflake_library.expr    ${ACCOUNT_LOCATION_PATH}
```

### Using file:// Protocol Prefix

Both formats are supported - with or without `file://` prefix:

```robotframework
Upload Files With File Protocol
    [Documentation]    Demonstrates file:// protocol prefix usage.
    [Tags]    upload    setup
    [Template]    Upload File Using File Protocol Template
    # Without prefix (recommended)
    ${CURDIR}/../../test_data/input.json    ${PIPELINES_LOCATION_PATH}
    # With file:// prefix (also works)
    file://${CURDIR}/../../test_data/input2.json    ${PIPELINES_LOCATION_PATH}
```

### JAR Files for JDBC Drivers

```robotframework
Upload JDBC Driver JAR
    [Documentation]    Uploads JAR file for database connectivity.
    ...    Required for MySQL, DB2, Teradata, and JMS connections.
    [Tags]    upload    jar    setup
    [Template]    Upload File Using File Protocol Template
    ${CURDIR}/../../test_data/accounts_jar_files/mysql/mysql-connector-java.jar    ${ACCOUNT_LOCATION_PATH}
```

---

## Template Keyword Arguments

| Argument | Description | Example |
|----------|-------------|---------|
| `file_url` | Local file path (with or without `file://` prefix) | `${CURDIR}/data/test.json` |
| `destination_path` | SnapLogic folder path where file will be uploaded | `${PIPELINES_LOCATION_PATH}` |

---

## File Location Conventions

### Test Data Files
```
test/suite/test_data/
├── actual_expected_data/
│   ├── input_data/                    # Test input files
│   │   ├── snowflake/
│   │   │   ├── test_input_file1.json
│   │   │   ├── test_input_file2.json
│   │   │   └── test_input_file3.json
│   │   ├── oracle/
│   │   └── postgres/
│   ├── expected_output/               # Expected results for comparison
│   │   ├── snowflake/
│   │   ├── oracle/
│   │   └── postgres/
│   └── expression_libraries/          # .expr files
│       └── snowflake/
│           ├── snowflake_library.expr
│           └── snowflake_library2.expr
│
├── accounts_jar_files/                # JDBC drivers
│   ├── mysql/
│   ├── db2/
│   ├── teradata/
│   └── jms/
│
└── accounts_payload/                  # Account JSON templates
```

---

## Complete Example: Snowflake Test Setup

From `snowflake_baseline_tests.robot`:

```robotframework
*** Variables ***
# Input files
${input_file1_name}                     test_input_file1.json
${input_file2_name}                     test_input_file2.json
${input_file3_name}                     test_input_file3.json
${input_file1_path}                     ${CURDIR}/../../test_data/actual_expected_data/input_data/snowflake/${input_file1_name}
${input_file2_path}                     ${CURDIR}/../../test_data/actual_expected_data/input_data/snowflake/${input_file2_name}
${input_file3_path}                     ${CURDIR}/../../test_data/actual_expected_data/input_data/snowflake/${input_file3_name}

*** Test Cases ***
Upload test input file
    [Documentation]    Uploads test input files and expression libraries to SnapLogic.
    [Tags]    snowflake_demo    snowflake_demo2    snowflake_multiple_files
    [Template]    Upload File Using File Protocol Template
    # local file path    destination_path in snaplogic
    ${input_file1_path}    ${PIPELINES_LOCATION_PATH}
    ${input_file2_path}    ${PIPELINES_LOCATION_PATH}
    ${input_file3_path}    ${PIPELINES_LOCATION_PATH}
    ${CURDIR}/../../test_data/actual_expected_data/expression_libraries/snowflake/snowflake_library.expr    ${ACCOUNT_LOCATION_PATH}
    file://${CURDIR}/../../test_data/actual_expected_data/expression_libraries/snowflake/snowflake_library2.expr    ${ACCOUNT_LOCATION_PATH}
```

---

## Usage Scenarios

### Scenario 1: Upload Test Input Before Pipeline Execution

```robotframework
*** Test Cases ***
Upload Test Input File
    [Tags]    setup
    [Template]    Upload File Using File Protocol Template
    ${input_file_path}    ${PIPELINES_LOCATION_PATH}

Execute Pipeline With Uploaded Input
    [Tags]    execution
    [Template]    Run Triggered Task With Parameters From Template
    ${unique_id}    ${PIPELINES_LOCATION_PATH}    ${pipeline_name}    ${task_name}    test_input_file=${input_file_name}
```

### Scenario 2: Upload Shared Expression Library

```robotframework
*** Test Cases ***
Upload Shared Expression Library
    [Documentation]    Upload expression library to shared folder for use by multiple pipelines.
    [Tags]    setup    shared
    [Template]    Upload File Using File Protocol Template
    ${CURDIR}/../../test_data/expression_libraries/common_functions.expr    ${ACCOUNT_LOCATION_PATH}
```

### Scenario 3: Upload Multiple File Types

```robotframework
*** Test Cases ***
Setup Test Environment
    [Documentation]    Uploads all required files before test execution.
    [Tags]    setup
    [Template]    Upload File Using File Protocol Template
    # Test input data
    ${CURDIR}/test_data/input.json    ${PIPELINES_LOCATION_PATH}
    ${CURDIR}/test_data/config.xml    ${PIPELINES_LOCATION_PATH}
    # Shared resources
    ${CURDIR}/expression_libs/utils.expr    ${ACCOUNT_LOCATION_PATH}
    ${CURDIR}/jar_files/driver.jar    ${ACCOUNT_LOCATION_PATH}
```

---

## Troubleshooting

### Common Issues

| Issue | Cause | Solution |
|-------|-------|----------|
| `Source file not found` | File path is incorrect | Check `${CURDIR}` relative path |
| `Permission denied` | User lacks write access to destination | Verify `${ACCOUNT_LOCATION_PATH}` permissions |
| `File not uploaded` | Destination path doesn't exist | Ensure project space/folder exists |

### Debug Tips

1. **Verify file exists locally:**
   ```robotframework
   File Should Exist    ${input_file_path}
   ```

2. **Log the paths being used:**
   ```robotframework
   Log    Local path: ${input_file_path}    console=yes
   Log    Destination: ${PIPELINES_LOCATION_PATH}    console=yes
   ```

3. **Check environment variables:**
   ```bash
   make check-env
   ```

---

## Checklist Before Committing

- [ ] Local file path uses `${CURDIR}` for relative paths
- [ ] Destination path uses appropriate environment variable
- [ ] Expression libraries go to `${ACCOUNT_LOCATION_PATH}` (shared)
- [ ] Test input files go to `${PIPELINES_LOCATION_PATH}` (project)
- [ ] Test has appropriate tags
- [ ] Documentation describes the file being uploaded
- [ ] No hardcoded paths (use environment variables)
