---
name: upload-file
description: Creates Robot Framework test cases for uploading files to SnapLogic SLDB. Use when the user wants to upload files (JSON, CSV, expression libraries, pipelines, JAR files, etc.), needs to know which destination path to use, or wants to see file upload test case examples.
user-invocable: true
---

# Upload File Test Case Guide

## Usage Examples

| What You Want | Example Prompt |
|---------------|----------------|
| Upload JSON file | `Create a test case to upload JSON input files` |
| Upload CSV file | `Upload CSV test data to SnapLogic` |
| Upload expression library | `How do I upload an expression library to the shared folder?` |
| Upload JAR file | `Upload JDBC driver JAR for MySQL` |
| Multiple files | `Upload multiple test input files in one test case` |
| Get template | `Show me a template for uploading files` |
| See example | `What does a file upload test case look like?` |
| Destination paths | `What's the difference between PIPELINES_LOCATION_PATH and ACCOUNT_LOCATION_PATH?` |

---

## Claude Instructions

**IMPORTANT:** When user asks a simple question like "How do I upload a JSON file?", provide a **concise answer first** with just the template/command, then offer to explain more if needed. Do NOT dump all documentation.

**PREREQUISITES (Claude: Always verify these before creating test cases):**
1. The local file(s) to upload must exist in the project (typically under `test/suite/test_data/`)
2. Know the correct destination path:
   - `${PIPELINES_LOCATION_PATH}` — for test input files, pipelines
   - `${ACCOUNT_LOCATION_PATH}` — for expression libraries, JAR files, shared resources

**MANDATORY:** When creating file upload test cases, you MUST call the **Write tool** to create ALL required files. Do NOT read files to check if they exist first. Do NOT say "file already exists" or "already complete". Always write them fresh:
1. **Robot test file** (`.robot`) in `test/suite/pipeline_tests/[type]/` — WRITE this
2. **UPLOAD_FILE_README.md** with file structure tree diagram in the same test directory — WRITE this

This applies to ALL file upload test cases. No exceptions. You must call Write for each file. See the "IMPORTANT: Step-by-Step Workflow" section for details.

**Response format for simple questions:**
1. Give the direct template or test case first
2. Add a brief note if relevant
3. Offer "Want me to explain more?" only if appropriate

---

# WHEN USER INVOKES `/upload-file` WITH NO ARGUMENTS

**Claude: When user types just `/upload-file` with no specific request, present the menu below. Use this EXACT format:**

---

**SnapLogic File Upload**

**Prerequisites**
1. Local file(s) must exist in the project (typically under `test/suite/test_data/`)
2. Know the destination: `${PIPELINES_LOCATION_PATH}` for test files, `${ACCOUNT_LOCATION_PATH}` for shared resources

**What I Can Do**

For every file upload, I create the **complete set of files** you need:
- **Robot test file** (`.robot`) — Robot Framework test case using `Upload File Using File Protocol Template`
- **UPLOAD_FILE_README.md** — File structure diagram, prerequisites, and run instructions

I can also:
- Explain SLDB (SnapLogic Database) file storage
- Guide you on which destination path to use
- Show examples for different file types (JSON, CSV, JAR, .expr)
- Help with uploading multiple files in one test case

**Supported File Types**
| Type | Extension | Destination |
|------|-----------|-------------|
| JSON | `.json` | `${PIPELINES_LOCATION_PATH}` |
| CSV | `.csv` | `${PIPELINES_LOCATION_PATH}` |
| Expression Library | `.expr` | `${ACCOUNT_LOCATION_PATH}` |
| JAR Files | `.jar` | `${ACCOUNT_LOCATION_PATH}` |
| Pipeline | `.slp` | `${PIPELINES_LOCATION_PATH}` |

**Try these sample prompts to get started:**

| Sample Prompt | What It Does |
|---------------|--------------|
| `Create a test case to upload JSON input files` | Generates robot test file and README |
| `Upload expression library to shared folder` | Creates test for .expr file upload |
| `Upload multiple CSV files for testing` | Creates multi-file upload test case |
| `What destination path should I use for JAR files?` | Explains path conventions |
| `Show me the baseline test for file uploads` | Displays existing reference test |

---

## Natural Language — Just Describe What You Need

You don't need special syntax. Just describe what you need after `/upload-file`:

```
/upload-file Create a test case to upload JSON input files
```

```
/upload-file How do I upload an expression library to the shared folder?
```

```
/upload-file Upload multiple test input files in one test case
```

```
/upload-file What's the difference between PIPELINES_LOCATION_PATH and ACCOUNT_LOCATION_PATH?
```

```
/upload-file Upload JDBC driver JAR for MySQL
```

**Baseline test references:**
- `test/suite/pipeline_tests/snowflake/snowflake_baseline_tests.robot`
- `test/suite/pipeline_tests/oracle/oracle_baseline_tests.robot`

---

## Quick Template Reference

**Upload file test case:**
```robotframework
[Template]    Upload File Using File Protocol Template
${input_file_path}    ${PIPELINES_LOCATION_PATH}
```

**Key destination paths:**
| Destination | Use For |
|-------------|---------|
| `${PIPELINES_LOCATION_PATH}` | Test input files, pipelines, project-specific files |
| `${ACCOUNT_LOCATION_PATH}` | Expression libraries, JAR files, shared resources |

**Related slash command:** `/upload-file`

---

## Agentic Workflow (Claude: Follow these steps in order)

**This is the complete guide. Proceed with the steps below.**

### Step 1: Understand the User's Request
Parse what the user wants:
- What file type? (JSON, CSV, .expr, .slp, .jar, etc.)
- Upload to which location? (project folder, shared folder)
- Single file or multiple files?
- Create test case?
- Show template or examples?

### Step 2: Follow the Guide
Use the detailed instructions below to:
- Identify the correct destination path variable
- Determine the appropriate file location convention
- Create or explain the test case

### Step 3: Respond to User
Provide the requested information or create the test case based on this guide.

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

## Quick Start Template

Here's a basic test case template for uploading files:

> **IMPORTANT: Required Libraries**
> When creating any new Robot file, ALWAYS include these Resource imports under `*** Settings ***`:
> - `snaplogic_common_robot/snaplogic_apis_keywords/snaplogic_keywords.resource` - SnapLogic API keywords from installed package
> - `../../resources/common/files.resource` - File operation keywords including upload template
> - `../../resources/common/general.resource` - Project-specific common keywords

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

## IMPORTANT: Step-by-Step Workflow

**Always follow this workflow when creating file upload test cases.**

**MANDATORY: You MUST create ALL of the following files:**

| # | File | Location | Purpose |
|---|------|----------|---------|
| 1 | **Robot test file** | `test/suite/pipeline_tests/[type]/[type]_file_upload.robot` | Robot Framework test case |
| 2 | **UPLOAD_FILE_README.md** | `test/suite/pipeline_tests/[type]/UPLOAD_FILE_README.md` | File structure diagram and instructions |

**ALWAYS create all files using the Write tool.** There are NO exceptions. Even if a file already exists, you MUST still use the Write tool to create/overwrite it. Do NOT skip any file. Do NOT say "file already exists" or "marking it complete" — actually write the file content.

**CRITICAL: Do NOT read files to check if they exist first. Do NOT skip writing a file because it already exists. Always use the Write tool to create every file, every time.**

### Step 1: Identify the File Type and Destination
Determine which file type(s) to upload and the appropriate destination path.

### Step 2: Verify Local File Location
Ensure the file exists in the project (typically under `test/suite/test_data/`).

### Step 3: Create the Robot Test Case (ALWAYS — use Write tool)
**ALWAYS use the Write tool** to create the `.robot` test file in `test/suite/pipeline_tests/[type]/`. Do NOT skip this step. Do NOT check if it exists first.

### Step 4: Create UPLOAD_FILE_README.md with File Structure (ALWAYS — use Write tool)
**ALWAYS use the Write tool** to create an UPLOAD_FILE_README.md in the test directory with a file structure tree diagram. See the "MANDATORY: README with File Structure" section for the template. Do NOT skip this step.

### Summary: You MUST use the Write tool to create these files every time
```
1. test/suite/pipeline_tests/[type]/[type]_file_upload.robot    ← WRITE this file
2. test/suite/pipeline_tests/[type]/UPLOAD_FILE_README.md       ← WRITE this file
```
If you did not call the Write tool for each file, you have NOT completed the task. Never say "file already exists" — always write it.

---

## COMPLETE EXAMPLE: Snowflake File Upload (All Files)

**When a user asks "Create a file upload test case for Snowflake", you MUST create ALL of these files:**

### File 1: Robot Test File — `test/suite/pipeline_tests/snowflake/snowflake_file_upload.robot`
```robotframework
*** Settings ***
Documentation    Uploads test input files and expression libraries to SnapLogic SLDB
...              Files are stored in SLDB and can be referenced by Snowflake pipelines
Resource         snaplogic_common_robot/snaplogic_apis_keywords/snaplogic_keywords.resource
Resource         ../../resources/common/files.resource
Resource         ../../resources/common/general.resource
Library          Collections
Library          OperatingSystem

*** Variables ***
# Input file paths (local)
${input_file1_name}             test_input_file1.json
${input_file2_name}             test_input_file2.json
${input_file1_path}             ${CURDIR}/../../test_data/actual_expected_data/input_data/snowflake/${input_file1_name}
${input_file2_path}             ${CURDIR}/../../test_data/actual_expected_data/input_data/snowflake/${input_file2_name}
${expr_lib_path}                ${CURDIR}/../../test_data/actual_expected_data/expression_libraries/snowflake/snowflake_library.expr

*** Test Cases ***
Upload Snowflake Test Files
    [Documentation]    Uploads test input files and expression libraries to SnapLogic.
    ...    - Test input files go to ${PIPELINES_LOCATION_PATH} (project folder)
    ...    - Expression libraries go to ${ACCOUNT_LOCATION_PATH} (shared folder)
    ...
    ...    PREREQUISITES:
    ...    - Local files must exist in test_data directory
    ...    - SnapLogic project structure must be in place
    [Tags]    snowflake    upload    setup
    [Template]    Upload File Using File Protocol Template
    # local file path                    destination_path
    ${input_file1_path}                  ${PIPELINES_LOCATION_PATH}
    ${input_file2_path}                  ${PIPELINES_LOCATION_PATH}
    ${expr_lib_path}                     ${ACCOUNT_LOCATION_PATH}
```

### File 2: README — `test/suite/pipeline_tests/snowflake/UPLOAD_FILE_README.md`
````markdown
# Snowflake File Upload Tests

To create file upload test cases, you need:
- **Local file(s)** — Test input files, expression libraries, etc. in the project
- **Test case file** — Robot Framework test that uses `Upload File Using File Protocol Template`

## Purpose
Uploads test input files and expression libraries to SnapLogic SLDB for Snowflake pipeline testing.

## File Structure
```
project-root/
├── test/
│   └── suite/
│       ├── pipeline_tests/
│       │   └── snowflake/
│       │       ├── snowflake_file_upload.robot            ← Test case file
│       │       └── UPLOAD_FILE_README.md                  ← This file
│       └── test_data/
│           └── actual_expected_data/
│               ├── input_data/
│               │   └── snowflake/
│               │       ├── test_input_file1.json          ← Input file 1
│               │       └── test_input_file2.json          ← Input file 2
│               └── expression_libraries/
│                   └── snowflake/
│                       └── snowflake_library.expr         ← Expression library
└── .env                                                   ← Environment configuration
```

## Destination Paths
- **Test input files** → `${PIPELINES_LOCATION_PATH}` (project folder)
- **Expression libraries** → `${ACCOUNT_LOCATION_PATH}` (shared folder)
- **JAR files** → `${ACCOUNT_LOCATION_PATH}` (shared folder)

## Prerequisites
1. Local files must exist in `test/suite/test_data/` directory
2. Environment variables configured in `.env`

## How to Run
```bash
make robot-run-all-tests TAGS="snowflake" PROJECT_SPACE_SETUP=True
```
````

**Claude: The above is a COMPLETE example. When creating file upload test cases for ANY type, follow the same pattern — always create all files. Never create just the .robot file alone.**

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

## Template Keyword Arguments

| Argument | Description | Example |
|----------|-------------|---------|
| `file_url` | Local file path (with or without `file://` prefix) | `${CURDIR}/data/test.json` |
| `destination_path` | SnapLogic folder path where file will be uploaded | `${PIPELINES_LOCATION_PATH}` |

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

### JAR Files for JDBC Drivers

```robotframework
Upload JDBC Driver JAR
    [Documentation]    Uploads JAR file for database connectivity.
    ...    Required for MySQL, DB2, Teradata, and JMS connections.
    [Tags]    upload    jar    setup
    [Template]    Upload File Using File Protocol Template
    ${CURDIR}/../../test_data/accounts_jar_files/mysql/mysql-connector-java.jar    ${ACCOUNT_LOCATION_PATH}
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

## Typical Test Execution Flow

```
┌─────────────────────────┐
│  1. Suite Setup         │
│  (Generate unique_id)   │
└───────────┬─────────────┘
            │
            ▼
┌─────────────────────────┐
│  2. Create Accounts     │
│  (Database, S3, etc.)   │
└───────────┬─────────────┘
            │
            ▼
┌─────────────────────────┐
│  3. Upload Files        │  ◄── YOU ARE HERE
│  (Input data, expr libs)│
└───────────┬─────────────┘
            │
            ▼
┌─────────────────────────┐
│  4. Import Pipeline     │
│  (.slp file)            │
└───────────┬─────────────┘
            │
            ▼
┌─────────────────────────┐
│  5. Create Task         │
│  (Triggered/Ultra)      │
└───────────┬─────────────┘
            │
            ▼
┌─────────────────────────┐
│  6. Execute Task        │
└─────────────────────────┘
```

---

## MANDATORY: UPLOAD_FILE_README.md with File Structure

**IMPORTANT: Every time you create file upload test cases, you MUST also create an UPLOAD_FILE_README.md in the same directory with a file structure diagram.**

This is required for ALL file types. No exceptions.

### What to Include in the README

1. **Purpose** — Brief description of what files are being uploaded
2. **File Structure** — A tree diagram showing all related files
3. **Destination Paths** — Which path variable to use for each file type
4. **Prerequisites** — Local files must exist
5. **How to Run** — The make command to execute the tests

### README Template

````markdown
# [Type] File Upload Tests

To create file upload test cases, you need:
- **Local file(s)** — Test input files, expression libraries, etc. in the project
- **Test case file** — Robot Framework test that uses `Upload File Using File Protocol Template`

## Purpose
Uploads [file types] to SnapLogic SLDB for [type] pipeline testing.

## File Structure
```
project-root/
├── test/
│   └── suite/
│       ├── pipeline_tests/
│       │   └── [type]/
│       │       ├── [type]_file_upload.robot               ← Test case file
│       │       └── UPLOAD_FILE_README.md                  ← This file
│       └── test_data/
│           └── actual_expected_data/
│               ├── input_data/
│               │   └── [type]/
│               │       └── [input_files]                  ← Input files
│               └── expression_libraries/
│                   └── [type]/
│                       └── [expr_files]                   ← Expression libraries
└── .env                                                   ← Environment configuration
```

## Destination Paths
- **Test input files** → `${PIPELINES_LOCATION_PATH}` (project folder)
- **Expression libraries** → `${ACCOUNT_LOCATION_PATH}` (shared folder)
- **JAR files** → `${ACCOUNT_LOCATION_PATH}` (shared folder)

## Prerequisites
1. Local files must exist in `test/suite/test_data/` directory
2. Environment variables configured in `.env`

## How to Run
```bash
make robot-run-all-tests TAGS="[type]" PROJECT_SPACE_SETUP=True
```
````

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
- [ ] **UPLOAD_FILE_README.md created with file structure diagram**
