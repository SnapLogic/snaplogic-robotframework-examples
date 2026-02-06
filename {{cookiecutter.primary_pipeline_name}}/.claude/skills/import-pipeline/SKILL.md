---
name: import-pipeline
description: Creates Robot Framework test cases for importing SnapLogic pipelines. Use when the user wants to import pipelines (.slp files), needs to know prerequisites for pipeline import, or wants to see pipeline import test case examples.
user-invocable: true
---

# Import Pipeline Test Case Guide

## Usage Examples

| What You Want | Example Prompt |
|---------------|----------------|
| Explain steps | `Explain the steps to import a pipeline in SnapLogic` |
| Create import test case | `Create a robot test case to import my_pipeline.slp` |
| Import multiple pipelines | `I need to import data_extractor.slp and data_loader.slp` |
| Check prerequisites | `What are the prerequisites for importing a pipeline?` |
| Get template | `Show me a template for importing pipelines` |
| See example | `What does a pipeline import test case look like?` |
| Troubleshoot | `I'm getting an error importing my pipeline` |
| Verify pipeline file | `Check if my pipeline file exists in src/pipelines` |
| Parameterization | `How do I parameterize my pipeline for testing?` |

---

## Claude Instructions

**IMPORTANT:** When user asks a simple question like "How do I import a pipeline?", provide a **concise answer first** with just the template/command, then offer to explain more if needed. Do NOT dump all documentation.

**PREREQUISITES (Claude: Always verify these before creating test cases):**
1. A valid `.slp` pipeline file must exist under `src/pipelines/`. Check that the file is present before proceeding.
2. Required accounts must already be created before importing a pipeline. If the user hasn't created accounts yet, guide them to use `/create-account` first. Accounts are a dependency for pipeline execution.

**MANDATORY:** When creating pipeline import test cases, you MUST call the **Write tool** to create ALL required files. Do NOT read files to check if they exist first. Do NOT say "file already exists" or "already complete". Always write them fresh:
1. **Robot test file** (`.robot`) in `test/suite/pipeline_tests/[type]/` — WRITE this
2. **PIPELINE_IMPORT_README.md** with file structure tree diagram in the same test directory — WRITE this

This applies to ALL pipeline import test cases. No exceptions. You must call Write for each file. See the "IMPORTANT: Step-by-Step Workflow" section for details.

**Response format for simple questions:**
1. Give the direct template or test case first
2. Add a brief note if relevant
3. Offer "Want me to explain more?" only if appropriate

---

# WHEN USER INVOKES `/import-pipeline` WITH NO ARGUMENTS

**Claude: When user types just `/import-pipeline` with no specific request, present the menu below. Use this EXACT format:**

---

**SnapLogic Pipeline Import**

**Prerequisites**
1. A valid `.slp` pipeline file must exist under `src/pipelines/`
2. Required accounts must already be created before importing a pipeline — use `/create-account` first

**What I Can Do**

For every pipeline import, I create the **complete set of files** you need:
- **Robot test file** (`.robot`) — Robot Framework test case using `Import Pipelines From Template`
- **PIPELINE_IMPORT_README.md** — File structure diagram, prerequisites, and run instructions

I can also:
- Show you prerequisites for pipeline import
- Explain pipeline parameterization best practices
- Guide you through importing multiple pipelines
- Troubleshoot import issues

**Try these sample prompts to get started:**

| Sample Prompt | What It Does |
|---------------|--------------|
| `Create a test case to import snowflake_etl.slp` | Generates robot test file and README |
| `What are the prerequisites for importing a pipeline?` | Shows the full prerequisites checklist |
| `I need to import data_extractor.slp and data_loader.slp` | Creates test cases for multiple pipelines |
| `Show me the baseline test for pipeline import` | Displays existing reference test as an example |
| `How do I parameterize my pipeline?` | Explains pipeline parameters and how to use them in tests |
| `Where do I put my .slp pipeline file?` | Shows the correct file location |

---

## Natural Language — Just Describe What You Need

You don't need special syntax. Just describe what you need after `/import-pipeline`:

```
/import-pipeline I need to import my_pipeline.slp into SnapLogic
```

```
/import-pipeline What are the prerequisites for importing a pipeline?
```

```
/import-pipeline Show me the baseline test for pipeline import
```

```
/import-pipeline Generate a test case to import snowflake_etl.slp
```

```
/import-pipeline Write a robot file that imports multiple pipelines
```

```
/import-pipeline I need a test case to import data_processor.slp
```

#### Pipeline Preparation Questions

```
/import-pipeline Where do I put my .slp pipeline file?
```

```
/import-pipeline What variables do I need for pipeline import?
```

```
/import-pipeline How do I parameterize my pipeline for testing?
```

**Baseline test references:**
- `test/suite/pipeline_tests/snowflake/snowflake_baseline_tests.robot`
- `test/suite/pipeline_tests/oracle/oracle_baseline_tests.robot`
- `test/suite/pipeline_tests/postgres/postgres_baseline_tests.robot`

---

## Quick Template Reference

**Import pipeline test case:**
```robotframework
[Template]    Import Pipelines From Template
${unique_id}    ${PIPELINES_LOCATION_PATH}    ${pipeline_name}    ${pipeline_file_name}
```

**Required variables:**
| Variable | Description |
|----------|-------------|
| `${unique_id}` | Generated in suite setup (Check connections keyword) |
| `${PIPELINES_LOCATION_PATH}` | SnapLogic destination path |
| `${pipeline_name}` | Logical name (without .slp extension) |
| `${pipeline_file_name}` | Physical file name (with .slp extension) |

**Related slash command:** `/import-pipeline`

---

## Agentic Workflow (Claude: Follow these steps in order)

**This is the complete guide. Proceed with the steps below.**

### Step 1: Understand the User's Request
Parse what the user wants:
- Import a single pipeline or multiple pipelines?
- Need prerequisites checklist?
- Create test case?
- Show template or examples?
- Questions about pipeline parameterization?

### Step 2: Follow the Guide
Use the detailed instructions below to:
- Show the prerequisites for pipeline import
- Verify pipeline .slp file location
- Create or explain the test case
- Provide troubleshooting if needed

### Step 3: Respond to User
Provide the requested information or create the test case based on this guide.

---

## Prerequisites Checklist

Before importing a pipeline, ensure you have completed the following:

### Step 0: Verify Account Creation (REQUIRED)
**Accounts must be created before importing a pipeline.** If the pipeline references any accounts (database, S3, Kafka, etc.), those accounts must already exist in SnapLogic. Use `/create-account` to create them first.

### Step 1: Pipeline Preparation in SnapLogic Designer

1. **Build and test your pipeline** in SnapLogic Designer
   - Ensure the pipeline executes successfully
   - **Best Practice:** Use pipeline parameters for:
     - Account names (e.g., `snowflake_acct`, `oracle_acct`)
     - Database connection details (schema, table names)
     - File paths
     - Any configurable values

2. **Why use pipeline parameters?**
   - Provides flexibility to execute pipelines with different data sets
   - Allows runtime updates through triggered tasks
   - Makes pipelines reusable across environments

3. **Determine deployment locations:**
   - Where should accounts be created? (e.g., `shared`, `accounts`)
   - Where should pipelines be imported? (e.g., project path)

### Step 2: Export Pipeline as .slp File

1. In SnapLogic Designer, right-click on your pipeline
2. Select **Export** or **Download as SLP**
3. Save the `.slp` file

### Step 3: Upload Pipeline to Project

**IMPORTANT:** Upload your `.slp` pipeline file to:

```
src/pipelines/
```

Full path:
```
/snaplogic-robotframework-examples/src/pipelines/your_pipeline.slp
```

### Step 4: Verify File Location

```bash
# Check if pipeline exists
ls src/pipelines/*.slp
```

---

## Expected Outcome After Prerequisites

- Valid `.slp` pipeline file in `src/pipelines/`
- Clear understanding of required accounts
- Knowledge of database/service credentials needed
- Defined import locations for pipelines and accounts
- Pipeline uses parameters for flexibility

---

## Quick Start Template

Here's a basic test case template for importing pipelines:

> **IMPORTANT: Required Libraries**
> When creating any new Robot file, ALWAYS include these Resource imports under `*** Settings ***`:
> - `snaplogic_common_robot/snaplogic_apis_keywords/snaplogic_keywords.resource` - SnapLogic API keywords from installed package
> - `../../resources/common/general.resource` - Project-specific common keywords

```robotframework
*** Settings ***
Documentation    Imports SnapLogic pipelines for testing
...              Uploads pipeline definitions (.slp files) to the specified project location
Resource         snaplogic_common_robot/snaplogic_apis_keywords/snaplogic_keywords.resource
Resource         ../../resources/common/general.resource
Library          Collections

*** Variables ***
# Pipeline configuration
${pipeline_name}                my_pipeline
${pipeline_file_name}           my_pipeline.slp

*** Test Cases ***
Import Pipeline
    [Documentation]    Imports pipeline file (.slp) into the SnapLogic project space.
    ...    This test case uploads pipeline definitions and deploys them to the specified location,
    ...    making them available for task creation and execution.
    ...
    ...    PREREQUISITES:
    ...    - ${unique_id} - Generated from suite setup (Check connections keyword)
    ...    - Pipeline .slp file must exist in src/pipelines/ directory
    ...    - SnapLogic project and folder structure must be in place
    ...
    ...    ARGUMENT DETAILS:
    ...    - Argument 1: ${unique_id} - Unique test execution identifier for naming/tracking
    ...    - Argument 2: ${PIPELINES_LOCATION_PATH} - SnapLogic folder path where pipelines will be imported
    ...    - Argument 3: ${pipeline_name} - Logical name for the pipeline (without .slp extension)
    ...    - Argument 4: ${pipeline_file_name} - Physical .slp file name to import
    [Tags]    pipeline_import    setup
    [Template]    Import Pipelines From Template
    ${unique_id}    ${PIPELINES_LOCATION_PATH}    ${pipeline_name}    ${pipeline_file_name}
```

---

## IMPORTANT: Step-by-Step Workflow

**Always follow this workflow when creating pipeline import test cases.**

**MANDATORY: You MUST create ALL of the following files:**

| # | File | Location | Purpose |
|---|------|----------|---------|
| 1 | **Robot test file** | `test/suite/pipeline_tests/[type]/[type]_pipeline_import.robot` | Robot Framework test case |
| 2 | **PIPELINE_IMPORT_README.md** | `test/suite/pipeline_tests/[type]/PIPELINE_IMPORT_README.md` | File structure diagram and instructions |

**ALWAYS create all files using the Write tool.** There are NO exceptions. Even if a file already exists, you MUST still use the Write tool to create/overwrite it. Do NOT skip any file. Do NOT say "file already exists" or "marking it complete" — actually write the file content.

**CRITICAL: Do NOT read files to check if they exist first. Do NOT skip writing a file because it already exists. Always use the Write tool to create every file, every time.**

### Step 1: Identify the Pipeline
Determine which pipeline(s) need to be imported based on the user's request.

### Step 2: Verify Pipeline File Location
Ensure the `.slp` file exists in `src/pipelines/`.

### Step 3: Create the Robot Test Case (ALWAYS — use Write tool)
**ALWAYS use the Write tool** to create the `.robot` test file in `test/suite/pipeline_tests/[type]/`. Do NOT skip this step. Do NOT check if it exists first.

### Step 4: Create PIPELINE_IMPORT_README.md with File Structure (ALWAYS — use Write tool)
**ALWAYS use the Write tool** to create a PIPELINE_IMPORT_README.md in the test directory with a file structure tree diagram. See the "MANDATORY: README with File Structure" section for the template. Do NOT skip this step.

### Summary: You MUST use the Write tool to create these files every time
```
1. test/suite/pipeline_tests/[type]/[type]_pipeline_import.robot    ← WRITE this file
2. test/suite/pipeline_tests/[type]/PIPELINE_IMPORT_README.md       ← WRITE this file
```
If you did not call the Write tool for each file, you have NOT completed the task. Never say "file already exists" — always write it.

---

## COMPLETE EXAMPLE: Snowflake Pipeline Import (All Files)

**When a user asks "Create a pipeline import test case for Snowflake", you MUST create ALL of these files:**

### File 1: Robot Test File — `test/suite/pipeline_tests/snowflake/snowflake_pipeline_import.robot`
```robotframework
*** Settings ***
Documentation    Imports Snowflake pipeline(s) into SnapLogic for testing
...              Uploads pipeline definitions (.slp files) to the specified project location
Resource         snaplogic_common_robot/snaplogic_apis_keywords/snaplogic_keywords.resource
Resource         ../../resources/common/general.resource
Library          Collections

*** Variables ***
# Pipeline configuration
${pipeline_name}                snowflake_keypair
${pipeline_file_name}           snowflake_keypair.slp

*** Test Cases ***
Import Snowflake Pipeline
    [Documentation]    Imports Snowflake pipeline file (.slp) into the SnapLogic project space.
    ...    PREREQUISITES:
    ...    - ${unique_id} - Generated from suite setup (Check connections keyword)
    ...    - Pipeline .slp file must exist in src/pipelines/ directory
    ...    - SnapLogic project and folder structure must be in place
    ...
    ...    ARGUMENT DETAILS:
    ...    - Argument 1: ${unique_id} - Unique test execution identifier for naming/tracking
    ...    - Argument 2: ${PIPELINES_LOCATION_PATH} - SnapLogic folder path where pipelines will be imported
    ...    - Argument 3: ${pipeline_name} - Logical name for the pipeline (without .slp extension)
    ...    - Argument 4: ${pipeline_file_name} - Physical .slp file name to import
    [Tags]    snowflake    pipeline_import
    [Template]    Import Pipelines From Template
    ${unique_id}    ${PIPELINES_LOCATION_PATH}    ${pipeline_name}    ${pipeline_file_name}
```

### File 2: README — `test/suite/pipeline_tests/snowflake/PIPELINE_IMPORT_README.md`
````markdown
# Snowflake Pipeline Import Tests

To create pipeline import test cases, you need:
- **Pipeline .slp file** — Exported from SnapLogic Designer, placed in `src/pipelines/`
- **Test case file** — Robot Framework test that uses `Import Pipelines From Template` to import the pipeline

## Purpose
Imports Snowflake pipeline(s) into SnapLogic for testing.

## File Structure
```
project-root/
├── src/
│   └── pipelines/
│       └── snowflake_keypair.slp                              ← Pipeline file (.slp)
├── test/
│   └── suite/
│       └── pipeline_tests/
│           └── snowflake/
│               ├── snowflake_pipeline_import.robot            ← Test case file
│               └── PIPELINE_IMPORT_README.md                  ← This file
└── .env                                                       ← Environment configuration
```

## Prerequisites
1. Pipeline `.slp` file must exist in `src/pipelines/`
2. Pipeline must be tested and working in SnapLogic Designer
3. Required accounts must be created before pipeline import
4. Environment variables configured:
   - `${PIPELINES_LOCATION_PATH}` — SnapLogic folder path for pipeline import
   - `${unique_id}` — Generated from suite setup

## How to Run
```bash
make robot-run-all-tests TAGS="snowflake" PROJECT_SPACE_SETUP=True
```
````

**Claude: The above is a COMPLETE example. When creating pipeline import test cases for ANY pipeline type, follow the same pattern — always create all files. Never create just the .robot file alone.**

---

## How Pipeline Import Works

```
┌─────────────────────────┐
│  src/pipelines/         │
│  your_pipeline.slp      │
└───────────┬─────────────┘
            │
            ▼
┌─────────────────────────┐     ┌─────────────────────────┐
│   Import Pipelines      │     │   SnapLogic API         │
│   From Template         │────▶│   Pipeline Import       │
│   Keyword               │     │                         │
└─────────────────────────┘     └───────────┬─────────────┘
                                            │
                                            ▼
                                ┌─────────────────────────┐
                                │   Pipeline Available    │
                                │   in SnapLogic at:      │
                                │   ${PIPELINES_LOCATION_ │
                                │   PATH}/${pipeline_name}│
                                └─────────────────────────┘
```

---

## Template Keyword Arguments

| Argument | Description | Example |
|----------|-------------|---------|
| `${unique_id}` | Unique test execution identifier (generated in suite setup) | `test_20240115_143022` |
| `${PIPELINES_LOCATION_PATH}` | SnapLogic path where pipeline will be imported | `org/project_space/project` |
| `${pipeline_name}` | Logical name for the pipeline (used in SnapLogic) | `snowflake_etl` |
| `${pipeline_file_name}` | Physical .slp file name in src/pipelines/ | `snowflake_etl.slp` |

---

## Key Environment Variables

| Variable | Description | Example Value |
|----------|-------------|---------------|
| `${PIPELINES_LOCATION_PATH}` | Project folder path for pipelines | `ml-legacy-migration/slim-travis-automation-ps/slim_travis_project` |
| `${ORG_NAME}` | SnapLogic organization name | `ml-legacy-migration` |
| `${PROJECT_SPACE}` | Project space name | `slim-travis-automation-ps` |
| `${PROJECT_NAME}` | Project name | `slim_travis_project` |

---

## Test Case Examples

### Basic Pipeline Import

```robotframework
*** Variables ***
${pipeline_name}                snowflake_demo
${pipeline_file_name}           snowflake_demo.slp

*** Test Cases ***
Import Snowflake Pipeline
    [Documentation]    Imports Snowflake demo pipeline into the project.
    [Tags]    snowflake    pipeline_import
    [Template]    Import Pipelines From Template
    ${unique_id}    ${PIPELINES_LOCATION_PATH}    ${pipeline_name}    ${pipeline_file_name}
```

### Multiple Pipeline Import

```robotframework
*** Variables ***
# Pipeline 1
${pipeline1_name}               data_extractor
${pipeline1_file_name}          data_extractor.slp

# Pipeline 2
${pipeline2_name}               data_transformer
${pipeline2_file_name}          data_transformer.slp

# Pipeline 3
${pipeline3_name}               data_loader
${pipeline3_file_name}          data_loader.slp

*** Test Cases ***
Import ETL Pipelines
    [Documentation]    Imports multiple ETL pipeline files into the project.
    ...    Each row represents a pipeline import operation.
    [Tags]    etl    pipeline_import    multi_pipeline
    [Template]    Import Pipelines From Template
    # unique_id    pipelines_location    pipeline_name    pipeline_file_name
    ${unique_id}    ${PIPELINES_LOCATION_PATH}    ${pipeline1_name}    ${pipeline1_file_name}
    ${unique_id}    ${PIPELINES_LOCATION_PATH}    ${pipeline2_name}    ${pipeline2_file_name}
    ${unique_id}    ${PIPELINES_LOCATION_PATH}    ${pipeline3_name}    ${pipeline3_file_name}
```

### Pipeline Import with Account Creation (Complete Setup)

```robotframework
*** Settings ***
Documentation    Complete pipeline setup with account and import
Resource         snaplogic_common_robot/snaplogic_apis_keywords/snaplogic_keywords.resource
Resource         ../../resources/common/general.resource
Library          Collections

*** Variables ***
${pipeline_name}                oracle_to_snowflake
${pipeline_file_name}           oracle_to_snowflake.slp

*** Test Cases ***
Create Oracle Account
    [Documentation]    Creates Oracle source account.
    [Tags]    oracle    account_setup
    [Template]    Create Account From Template
    ${ACCOUNT_LOCATION_PATH}    ${ORACLE_ACCOUNT_PAYLOAD_FILE_NAME}    ${ORACLE_ACCOUNT_NAME}    overwrite_if_exists=${TRUE}

Create Snowflake Account
    [Documentation]    Creates Snowflake destination account.
    [Tags]    snowflake    account_setup
    [Template]    Create Account From Template
    ${ACCOUNT_LOCATION_PATH}    ${SNOWFLAKE_ACCOUNT_PAYLOAD_KEY_PAIR_FILE_NAME}    ${SNOWFLAKE_KEYPAIR_ACCOUNT_NAME}    overwrite_if_exists=${TRUE}

Import Pipeline
    [Documentation]    Imports the Oracle to Snowflake pipeline.
    [Tags]    pipeline_import
    [Template]    Import Pipelines From Template
    ${unique_id}    ${PIPELINES_LOCATION_PATH}    ${pipeline_name}    ${pipeline_file_name}
```

---

## File Location Conventions

### Pipeline Files
```
src/
└── pipelines/                          # Upload your .slp files here
    ├── snowflake_demo.slp
    ├── oracle_etl.slp
    ├── kafka_consumer.slp
    └── data_processor.slp
```

### Test Suite Structure
```
test/suite/pipeline_tests/
├── snowflake/
│   └── snowflake_baseline_tests.robot  # Contains Import Pipeline test case
├── oracle/
│   └── oracle_baseline_tests.robot
└── your_system/
    └── your_tests.robot
```

---

## Pipeline Parameterization Best Practices

### Why Parameterize?

Parameterized pipelines are more flexible and reusable:

```
# In SnapLogic Designer, use expression parameters like:
_snowflake_acct       # Account reference
_schema_name          # Database schema
_table_name           # Target table
_input_file           # Input file path
```

### Using Parameters in Test Cases

```robotframework
*** Variables ***
# Task parameters that map to pipeline parameters
&{task_params_set}
...    snowflake_acct=../shared/${SNOWFLAKE_ACCOUNT_NAME}
...    schema_name=DEMO
...    table_name=DEMO.TEST_TABLE
...    input_file=${input_file_name}

*** Test Cases ***
Create Triggered Task With Parameters
    [Documentation]    Creates task with pipeline parameters.
    [Tags]    task_creation
    [Template]    Create Triggered Task From Template
    ${unique_id}    ${PIPELINES_LOCATION_PATH}    ${pipeline_name}    ${task_name}    ${GROUNDPLEX_NAME}    ${task_params_set}
```

---

## Complete Example from Baseline Test

From `snowflake_baseline_tests.robot`:

```robotframework
*** Variables ***
# Pipeline name and file details
${pipeline_name}                        snowflake_keypair
${pipeline_file_name}                   snowflake_keypair.slp
${sf_acct_keypair}                      ${pipeline_name}_account

# Task Details
${task_name}                            Task

# Task parameters
&{task_params_set}
...                                     snowflake_acct=../shared/${sf_acct_keypair}
...                                     schema=DEMO
...                                     table=DEMO.TEST_SNAP4
...                                     destination_hint=BRAZE:Subscription
...                                     isTest=test
...                                     test_input_file=${input_file1_path}

*** Test Cases ***
Import Pipeline
    [Documentation]    Imports Snowflake pipeline files (.slp) into the SnapLogic project space.
    ...    This test case uploads pipeline definitions and deploys them to the specified location,
    ...    making them available for task creation and execution.
    ...
    ...    PREREQUISITES:
    ...    - ${unique_id} - Generated from suite setup (Check connections keyword)
    ...    - Pipeline .slp files must exist in the test_data directory
    ...    - SnapLogic project and folder structure must be in place
    ...
    ...    ARGUMENT DETAILS:
    ...    - Argument 1: ${unique_id} - Unique test execution identifier for naming/tracking
    ...    - Argument 2: ${PIPELINES_LOCATION_PATH} - SnapLogic folder path where pipelines will be imported
    ...    - Argument 3: ${pipeline_name} - Logical name for the pipeline (without .slp extension)
    ...    - Argument 4: ${pipeline_file_name} - Physical .slp file name to import
    [Tags]    snowflake_demo    snowflake_demo3    snowflake_multiple_files
    [Template]    Import Pipelines From Template

    ${unique_id}    ${PIPELINES_LOCATION_PATH}    ${pipeline_name}    ${pipeline_file_name}
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
│  3. Upload Files        │
│  (Input data, expr libs)│
└───────────┬─────────────┘
            │
            ▼
┌─────────────────────────┐
│  4. Import Pipeline     │  ◄── YOU ARE HERE
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
└───────────┬─────────────┘
            │
            ▼
┌─────────────────────────┐
│  7. Verify Results      │
└─────────────────────────┘
```

---

## MANDATORY: PIPELINE_IMPORT_README.md with File Structure

**IMPORTANT: Every time you create pipeline import test cases, you MUST also create a PIPELINE_IMPORT_README.md in the same directory with a file structure diagram.**

This is required for ALL pipeline types. No exceptions.

### What to Include in the README

1. **Purpose** — Brief description of what the test suite does
2. **File Structure** — A tree diagram showing all related files (test files, pipeline .slp files)
3. **Prerequisites** — Pipeline file location and environment variables needed
4. **How to Run** — The make command to execute the tests

### README Template

````markdown
# [Pipeline Type] Pipeline Import Tests

To create pipeline import test cases, you need:
- **Pipeline .slp file** — Exported from SnapLogic Designer, placed in `src/pipelines/`
- **Test case file** — Robot Framework test that uses `Import Pipelines From Template` to import the pipeline

## Purpose
Imports [Pipeline Type] pipeline(s) into SnapLogic for testing.

## File Structure
```
project-root/
├── src/
│   └── pipelines/
│       └── [pipeline_name].slp                                ← Pipeline file (.slp)
├── test/
│   └── suite/
│       └── pipeline_tests/
│           └── [pipeline_type]/
│               ├── [pipeline_type]_pipeline_import.robot      ← Test case file
│               └── PIPELINE_IMPORT_README.md                  ← This file
└── .env                                                       ← Environment configuration
```

## Prerequisites
1. Pipeline `.slp` file must exist in `src/pipelines/`
2. Pipeline must be tested and working in SnapLogic Designer
3. Required accounts must be created before pipeline import
4. Environment variables configured:
   - `${PIPELINES_LOCATION_PATH}` — SnapLogic folder path for pipeline import
   - `${unique_id}` — Generated from suite setup

## How to Run
```bash
make robot-run-all-tests TAGS="[pipeline_type]" PROJECT_SPACE_SETUP=True
```
````

---

## Troubleshooting

### Common Issues

| Issue | Cause | Solution |
|-------|-------|----------|
| `Pipeline file not found` | .slp file not in src/pipelines/ | Upload pipeline to `src/pipelines/` |
| `Import failed` | Invalid .slp format | Re-export pipeline from SnapLogic Designer |
| `Pipeline already exists` | Pipeline with same name exists | Use different name or delete existing |
| `Permission denied` | User lacks import permissions | Check SnapLogic permissions |
| `Project not found` | PIPELINES_LOCATION_PATH incorrect | Verify path in .env file |

### Debug Tips

1. **Verify pipeline file exists:**
   ```bash
   ls src/pipelines/${pipeline_file_name}
   ```

2. **Log the paths being used:**
   ```robotframework
   Log    Pipeline file: ${pipeline_file_name}    console=yes
   Log    Destination: ${PIPELINES_LOCATION_PATH}    console=yes
   ```

3. **Check environment variables:**
   ```bash
   make check-env
   ```

---

## Checklist Before Committing

- [ ] Pipeline .slp file exists in `src/pipelines/`
- [ ] Pipeline tested and working in SnapLogic Designer
- [ ] Pipeline uses parameters for configurable values
- [ ] `${pipeline_name}` variable defined (without .slp extension)
- [ ] `${pipeline_file_name}` variable defined (with .slp extension)
- [ ] Test has appropriate tags
- [ ] Documentation describes the pipeline being imported
- [ ] Required accounts are created before pipeline import (if pipeline references them)
- [ ] **PIPELINE_IMPORT_README.md created with file structure diagram**
