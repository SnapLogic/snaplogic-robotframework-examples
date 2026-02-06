---
name: create-triggered-task
description: Creates Robot Framework test cases for creating and executing SnapLogic triggered tasks. Use when the user wants to create triggered tasks for on-demand pipeline execution, execute triggered tasks with parameters, or wants to see triggered task test case examples.
user-invocable: true
---

# Create Triggered Task Test Case Guide

## Usage Examples

| What You Want | Example Prompt |
|---------------|----------------|
| Create triggered task | `Create a triggered task for my Snowflake pipeline` |
| Create and execute task | `Create and execute a triggered task for my Oracle pipeline` |
| Execute existing task | `Execute a triggered task with different input file` |
| Task with parameters | `Create a task that passes account and schema parameters` |
| Task with notifications | `Create a task with email notifications on completion` |
| Task with timeout | `Create a triggered task with 5 minute timeout` |
| Get template | `Show me a template for creating and executing triggered tasks` |
| See example | `What does a triggered task test case look like?` |

---

## Claude Instructions

**IMPORTANT:** When user asks a simple question like "How do I create a triggered task?", provide a **concise answer first** with just the template/command, then offer to explain more if needed. Do NOT dump all documentation.

**PREREQUISITES (Claude: Always verify these before creating test cases):**
1. Pipeline must be imported first — use `/import-pipeline` if not done yet.
2. Required accounts must be created first — use `/create-account` if not done yet.
3. Know what parameters the pipeline expects (account references, schema, table, etc.).

**MANDATORY:** When creating triggered task test cases, you MUST call the **Write tool** to create ALL required files. Do NOT read files to check if they exist first. Do NOT say "file already exists" or "already complete". Always write them fresh:
1. **Robot test file** (`.robot`) in `test/suite/pipeline_tests/[type]/` — WRITE this
2. **TRIGGERED_TASK_README.md** with file structure tree diagram in the same test directory — WRITE this

This applies to ALL triggered task test cases. No exceptions. You must call Write for each file. See the "IMPORTANT: Step-by-Step Workflow" section for details.

**Response format for simple questions:**
1. Give the direct template or test case first
2. Add a brief note if relevant
3. Offer "Want me to explain more?" only if appropriate

---

# WHEN USER INVOKES `/create-triggered-task` WITH NO ARGUMENTS

**Claude: When user types just `/create-triggered-task` with no specific request, present the menu below. Use this EXACT format:**

---

**SnapLogic Triggered Task Creation & Execution**

**Prerequisites**
1. Pipeline must be imported first — use `/import-pipeline`
2. Required accounts must be created first — use `/create-account`
3. Know what parameters the pipeline expects

**What I Can Do**

For every triggered task, I create the **complete set of files** you need:
- **Robot test file** (`.robot`) — Robot Framework test cases for creating AND executing triggered tasks
- **TRIGGERED_TASK_README.md** — File structure diagram, prerequisites, and run instructions

**Two Key Operations:**
1. **Create Triggered Task** — Uses `Create Triggered Task From Template` to create the task
2. **Execute Triggered Task** — Uses `Run Triggered Task With Parameters From Template` to run the task

I can also:
- Show you how to pass pipeline parameters
- Configure email notifications for task completion/failure
- Set execution timeouts
- Override parameters at execution time

**What is a Triggered Task?**
A triggered task is an **on-demand pipeline execution** in SnapLogic. You first CREATE the task (define it), then EXECUTE it (run it with parameters).

**Try these sample prompts to get started:**

| Sample Prompt | What It Does |
|---------------|--------------|
| `Create a triggered task for my Snowflake pipeline` | Creates triggered task test case |
| `Create and execute a triggered task` | Creates task + runs it |
| `Execute a task with different input file` | Shows parameter override at execution |
| `Create a task with parameters for account and schema` | Shows parameter passing |
| `Create a task with email notifications` | Adds notification configuration |
| `Show me the baseline test for triggered task` | Displays existing reference test |

**Need to set up the pipeline first?** Use `/end-to-end-pipeline-verification` for complete setup.

---

## Natural Language — Just Describe What You Need

You don't need special syntax. Just describe what you need after `/create-triggered-task`:

```
/create-triggered-task Create a triggered task for my Snowflake pipeline
```

```
/create-triggered-task Create and execute a triggered task with input file parameter
```

```
/create-triggered-task I need a task that passes snowflake_acct and schema parameters
```

```
/create-triggered-task Execute a triggered task with different input files
```

```
/create-triggered-task Create a task with email notifications on completion and failure
```

**Baseline test references:**
- `test/suite/pipeline_tests/snowflake/snowflake_baseline_tests.robot`
- `test/suite/pipeline_tests/oracle/oracle_baseline_tests.robot`

---

## Quick Template Reference

**Create triggered task:**
```robotframework
[Template]    Create Triggered Task From Template
${unique_id}    ${PIPELINES_LOCATION_PATH}    ${pipeline_name}    ${task_name}    ${GROUNDPLEX_NAME}    ${task_params_set}    execution_timeout=300
```

**Execute triggered task:**
```robotframework
[Template]    Run Triggered Task With Parameters From Template
${unique_id}    ${PIPELINES_LOCATION_PATH}    ${pipeline_name}    ${task_name}    param1=value1    param2=value2
```

**Required variables for Create:**
| Variable | Description |
|----------|-------------|
| `${unique_id}` | Generated in suite setup |
| `${PIPELINES_LOCATION_PATH}` | SnapLogic path where pipeline is stored |
| `${pipeline_name}` | Name of the pipeline |
| `${task_name}` | Name to assign to the task |
| `${GROUNDPLEX_NAME}` | Snaplex where task will execute (optional) |
| `${task_params_set}` | Dictionary of parameters to pass (optional) |

**Required variables for Execute:**
| Variable | Description |
|----------|-------------|
| `${unique_id}` | Same unique_id used when creating the task |
| `${PIPELINES_LOCATION_PATH}` | SnapLogic path where pipeline is stored |
| `${pipeline_name}` | Name of the pipeline |
| `${task_name}` | Name of the triggered task to execute |
| `key=value` | Optional parameter overrides |

**Related slash command:** `/create-triggered-task`

---

## Quick Start Template

Here's a basic test case template for creating AND executing triggered tasks:

> **IMPORTANT: Required Libraries**
> When creating any new Robot file, ALWAYS include these Resource imports under `*** Settings ***`:
> - `snaplogic_common_robot/snaplogic_apis_keywords/snaplogic_keywords.resource` - SnapLogic API keywords from installed package
> - `../../resources/common/general.resource` - Project-specific common keywords

```robotframework
*** Settings ***
Documentation    Creates and executes triggered tasks for SnapLogic pipeline execution
Resource         snaplogic_common_robot/snaplogic_apis_keywords/snaplogic_keywords.resource
Resource         ../../resources/common/general.resource
Library          Collections

*** Variables ***
# Pipeline configuration
${pipeline_name}                my_pipeline
${task_name}                    Task

# Input file for execution
${input_file_name}              test_input.json

# Task parameters - passed to pipeline during creation
&{task_params_set}
...    account_name=../shared/${ACCOUNT_NAME}
...    schema=DEMO
...    table=TEST_TABLE

*** Test Cases ***
Create Triggered Task
    [Documentation]    Creates a triggered task for pipeline execution.
    ...    PREREQUISITES:
    ...    - Pipeline must be imported first
    ...    - Accounts must be created first
    ...    - ${unique_id} - Generated from suite setup
    ...
    ...    ARGUMENTS:
    ...    - ${unique_id}: Unique test execution identifier
    ...    - ${PIPELINES_LOCATION_PATH}: SnapLogic path where pipeline is stored
    ...    - ${pipeline_name}: Name of the pipeline
    ...    - ${task_name}: Name for the triggered task
    ...    - ${GROUNDPLEX_NAME}: Snaplex for execution (optional)
    ...    - ${task_params_set}: Parameters to pass to pipeline (optional)
    [Tags]    task_creation    triggered_task
    [Template]    Create Triggered Task From Template
    ${unique_id}    ${PIPELINES_LOCATION_PATH}    ${pipeline_name}    ${task_name}    ${GROUNDPLEX_NAME}    ${task_params_set}    execution_timeout=300

Execute Triggered Task
    [Documentation]    Executes the triggered task with specified parameters and monitors completion.
    ...    This test case runs the pipeline through the triggered task, optionally overriding
    ...    task parameters for different execution scenarios.
    ...
    ...    PREREQUISITES:
    ...    - Task must be created first (Create Triggered Task test case)
    ...    - Task must be in ready state before execution
    ...
    ...    ARGUMENTS:
    ...    - ${unique_id}: Unique identifier matching the task creation
    ...    - ${PIPELINES_LOCATION_PATH}: SnapLogic path where pipelines are stored
    ...    - ${pipeline_name}: Name of the pipeline associated with the task
    ...    - ${task_name}: Name of the triggered task to execute
    ...    - key=value: Optional parameter overrides (e.g., test_input_file=input.json)
    [Tags]    task_execution    triggered_task
    [Template]    Run Triggered Task With Parameters From Template
    ${unique_id}    ${PIPELINES_LOCATION_PATH}    ${pipeline_name}    ${task_name}    test_input_file=${input_file_name}
```

---

## IMPORTANT: Step-by-Step Workflow

**Always follow this workflow when creating triggered task test cases.**

**MANDATORY: You MUST create ALL of the following files:**

| # | File | Location | Purpose |
|---|------|----------|---------|
| 1 | **Robot test file** | `test/suite/pipeline_tests/[type]/[type]_triggered_task.robot` | Robot Framework test case |
| 2 | **TRIGGERED_TASK_README.md** | `test/suite/pipeline_tests/[type]/TRIGGERED_TASK_README.md` | File structure diagram and instructions |

**ALWAYS create all files using the Write tool.** There are NO exceptions. Even if a file already exists, you MUST still use the Write tool to create/overwrite it. Do NOT skip any file.

### Step 1: Identify Requirements
- Which pipeline is the triggered task for?
- What parameters does the pipeline need?
- Need notifications?
- What timeout value?
- Need to execute the task after creating it?

### Step 2: Verify Prerequisites
- Pipeline must be imported (`/import-pipeline`)
- Accounts must be created (`/create-account`)

### Step 3: Create the Robot Test Case (ALWAYS — use Write tool)
**ALWAYS use the Write tool** to create the `.robot` test file. Do NOT skip this step.

### Step 4: Create TRIGGERED_TASK_README.md (ALWAYS — use Write tool)
**ALWAYS use the Write tool** to create the README with file structure diagram. Do NOT skip this step.

---

## COMPLETE EXAMPLE: Snowflake Triggered Task with Execution (All Files)

**When a user asks "Create and execute a triggered task for Snowflake pipeline", you MUST create ALL of these files:**

### File 1: Robot Test File — `test/suite/pipeline_tests/snowflake/snowflake_triggered_task.robot`
```robotframework
*** Settings ***
Documentation    Creates and executes triggered task for Snowflake pipeline
...              Task is created with parameters and then executed with optional overrides
Resource         snaplogic_common_robot/snaplogic_apis_keywords/snaplogic_keywords.resource
Resource         ../../resources/common/general.resource
Library          Collections

*** Variables ***
# Pipeline configuration
${pipeline_name}                snowflake_keypair
${task_name}                    Task
${sf_acct_keypair}              ${pipeline_name}_account

# Input files for execution
${input_file1_name}             test_input_file1.json
${input_file2_name}             test_input_file2.json
${input_file3_name}             test_input_file3.json

# Notification configuration (optional)
@{notification_states}          Completed    Failed
&{task_notifications}
...    recipients=notify@example.com
...    states=${notification_states}

# Task parameters - passed to pipeline during creation
&{task_params_set}
...    snowflake_acct=../shared/${sf_acct_keypair}
...    schema=DEMO
...    table=DEMO.TEST_TABLE
...    isTest=test
...    test_input_file=${input_file1_name}

*** Test Cases ***
Create Snowflake Triggered Task
    [Documentation]    Creates a triggered task for Snowflake pipeline execution.
    ...    The task is configured with pipeline parameters for account reference,
    ...    schema, and table settings.
    ...
    ...    PREREQUISITES:
    ...    - Snowflake account must be created first
    ...    - Pipeline must be imported first
    ...    - ${unique_id} - Generated from suite setup
    ...
    ...    ARGUMENTS:
    ...    - ${unique_id}: Unique test execution identifier
    ...    - ${PIPELINES_LOCATION_PATH}: SnapLogic path where pipeline is stored
    ...    - ${pipeline_name}: Name of the pipeline (snowflake_keypair)
    ...    - ${task_name}: Name for the triggered task (Task)
    ...    - ${GROUNDPLEX_NAME}: Snaplex for execution
    ...    - ${task_params_set}: Parameters including account, schema, table
    ...    - execution_timeout: Task timeout in seconds
    [Tags]    snowflake    task_creation    triggered_task
    [Template]    Create Triggered Task From Template
    ${unique_id}    ${PIPELINES_LOCATION_PATH}    ${pipeline_name}    ${task_name}    ${GROUNDPLEX_NAME}    ${task_params_set}    execution_timeout=300

Execute Snowflake Triggered Task
    [Documentation]    Executes the triggered task with specified parameters and monitors completion.
    ...    This test case runs the pipeline through the triggered task, optionally overriding
    ...    task parameters for different execution scenarios.
    ...
    ...    PREREQUISITES:
    ...    - Task must be created first (Create Snowflake Triggered Task)
    ...    - Task must be in ready state before execution
    ...
    ...    ARGUMENTS:
    ...    - ${unique_id}: Unique identifier matching the task creation
    ...    - ${PIPELINES_LOCATION_PATH}: SnapLogic path where pipelines are stored
    ...    - ${pipeline_name}: Name of the pipeline associated with the task
    ...    - ${task_name}: Name of the triggered task to execute
    ...    - test_input_file: Input file parameter override
    [Tags]    snowflake    task_execution    triggered_task
    [Template]    Run Triggered Task With Parameters From Template
    ${unique_id}    ${PIPELINES_LOCATION_PATH}    ${pipeline_name}    ${task_name}    test_input_file=${input_file1_name}
    # Additional executions with different input files (uncomment as needed):
    # ${unique_id}    ${PIPELINES_LOCATION_PATH}    ${pipeline_name}    ${task_name}    test_input_file=${input_file2_name}
    # ${unique_id}    ${PIPELINES_LOCATION_PATH}    ${pipeline_name}    ${task_name}    test_input_file=${input_file3_name}
```

### File 2: README — `test/suite/pipeline_tests/snowflake/TRIGGERED_TASK_README.md`
````markdown
# Snowflake Triggered Task Tests

This test suite creates AND executes triggered tasks for Snowflake pipeline testing.

## Purpose
Creates triggered task(s) for Snowflake pipeline execution with configurable parameters, then executes them with optional parameter overrides.

## Two Key Operations

| Operation | Keyword | Purpose |
|-----------|---------|---------|
| **Create Task** | `Create Triggered Task From Template` | Defines the task with default parameters |
| **Execute Task** | `Run Triggered Task With Parameters From Template` | Runs the task, optionally overriding parameters |

## File Structure
```
project-root/
├── test/
│   └── suite/
│       └── pipeline_tests/
│           └── snowflake/
│               ├── snowflake_triggered_task.robot             ← Test case file
│               └── TRIGGERED_TASK_README.md                   ← This file
└── .env                                                       ← Environment configuration
```

## Prerequisites
1. Snowflake account must be created (`/create-account`)
2. Pipeline must be imported (`/import-pipeline`)
3. Environment variables configured in `.env`

## Task Parameters (Set at Creation)
The following parameters are passed to the pipeline when the task is created:
- `snowflake_acct` — Reference to the Snowflake account
- `schema` — Database schema name
- `table` — Target table name
- `isTest` — Test mode flag
- `test_input_file` — Default input file

## Parameter Overrides (At Execution)
You can override parameters when executing the task:
```robotframework
[Template]    Run Triggered Task With Parameters From Template
${unique_id}    ${PIPELINES_LOCATION_PATH}    ${pipeline_name}    ${task_name}    test_input_file=different_file.json
```

## How to Run
```bash
# Run both create and execute
make robot-run-all-tests TAGS="snowflake AND triggered_task" PROJECT_SPACE_SETUP=True

# Run only task creation
make robot-run-all-tests TAGS="task_creation" PROJECT_SPACE_SETUP=True

# Run only task execution
make robot-run-all-tests TAGS="task_execution" PROJECT_SPACE_SETUP=True
```
````

**Claude: The above is a COMPLETE example. When creating triggered task test cases for ANY type, follow the same pattern — always create all files.**

---

## Template Keyword Arguments

### Create Triggered Task From Template

| Argument | Description | Required | Example |
|----------|-------------|----------|---------|
| `${unique_id}` | Unique test execution identifier | Yes | `test_20240115_143022` |
| `${PIPELINES_LOCATION_PATH}` | SnapLogic path where pipeline is stored | Yes | `org/project_space/project` |
| `${pipeline_name}` | Name of the pipeline | Yes | `snowflake_keypair` |
| `${task_name}` | Name to assign to the task | Yes | `Task` |
| `${GROUNDPLEX_NAME}` | Snaplex where task will execute | Optional | `my_snaplex` |
| `${task_params_set}` | Dictionary of parameters | Optional | `&{params}` |
| `${task_notifications}` | Notification settings | Optional | `&{notifications}` |
| `execution_timeout` | Timeout in seconds | Optional | `300` |

### Run Triggered Task With Parameters From Template

| Argument | Description | Required | Example |
|----------|-------------|----------|---------|
| `${unique_id}` | Unique test execution identifier | Yes | `test_20240115_143022` |
| `${PIPELINES_LOCATION_PATH}` | SnapLogic path where pipeline is stored | Yes | `org/project_space/project` |
| `${pipeline_name}` | Name of the pipeline | Yes | `snowflake_keypair` |
| `${task_name}` | Name of the task to execute | Yes | `Task` |
| `key=value` | Parameter overrides | Optional | `test_input_file=input.json` |

---

## Test Case Examples

### Basic Create and Execute

```robotframework
*** Variables ***
${pipeline_name}                snowflake_demo
${task_name}                    Task
${input_file_name}              test_input.json

*** Test Cases ***
Create Triggered Task
    [Documentation]    Creates a triggered task.
    [Tags]    snowflake    task_creation
    [Template]    Create Triggered Task From Template
    ${unique_id}    ${PIPELINES_LOCATION_PATH}    ${pipeline_name}    ${task_name}

Execute Triggered Task
    [Documentation]    Executes the triggered task.
    [Tags]    snowflake    task_execution
    [Template]    Run Triggered Task With Parameters From Template
    ${unique_id}    ${PIPELINES_LOCATION_PATH}    ${pipeline_name}    ${task_name}    test_input_file=${input_file_name}
```

### Execute with Multiple Input Files

```robotframework
*** Variables ***
${pipeline_name}                snowflake_demo
${task_name}                    Task
${input_file1_name}             test_input_file1.json
${input_file2_name}             test_input_file2.json
${input_file3_name}             test_input_file3.json

*** Test Cases ***
Execute Triggered Task With Multiple Files
    [Documentation]    Executes the triggered task multiple times with different input files.
    [Tags]    snowflake    task_execution    multiple_files
    [Template]    Run Triggered Task With Parameters From Template
    ${unique_id}    ${PIPELINES_LOCATION_PATH}    ${pipeline_name}    ${task_name}    test_input_file=${input_file1_name}
    ${unique_id}    ${PIPELINES_LOCATION_PATH}    ${pipeline_name}    ${task_name}    test_input_file=${input_file2_name}
    ${unique_id}    ${PIPELINES_LOCATION_PATH}    ${pipeline_name}    ${task_name}    test_input_file=${input_file3_name}
```

### Execute with Multiple Parameter Overrides

```robotframework
*** Variables ***
${pipeline_name}                snowflake_demo
${task_name}                    Task

*** Test Cases ***
Execute With Custom Parameters
    [Documentation]    Executes the triggered task with multiple parameter overrides.
    [Tags]    snowflake    task_execution
    [Template]    Run Triggered Task With Parameters From Template
    ${unique_id}    ${PIPELINES_LOCATION_PATH}    ${pipeline_name}    ${task_name}    schema=PROD    table=PROD.CUSTOMERS    mode=production
```

### Create with Notifications, Then Execute

```robotframework
*** Variables ***
${pipeline_name}                snowflake_demo
${task_name}                    Task

@{notification_states}          Completed    Failed
&{task_notifications}
...    recipients=notify@example.com
...    states=${notification_states}

&{task_params_set}
...    snowflake_acct=../shared/${SNOWFLAKE_ACCOUNT_NAME}

*** Test Cases ***
Create Triggered Task With Notifications
    [Documentation]    Creates triggered task with email notifications.
    [Tags]    snowflake    task_creation    notifications
    [Template]    Create Triggered Task From Template
    ${unique_id}    ${PIPELINES_LOCATION_PATH}    ${pipeline_name}    ${task_name}    ${GROUNDPLEX_NAME}    ${task_params_set}    ${task_notifications}    execution_timeout=300

Execute Notified Task
    [Documentation]    Executes the task that has notifications configured.
    [Tags]    snowflake    task_execution    notifications
    [Template]    Run Triggered Task With Parameters From Template
    ${unique_id}    ${PIPELINES_LOCATION_PATH}    ${pipeline_name}    ${task_name}
```

---

## Parameter Configuration

### Defining Task Parameters (for Create)

Task parameters are defined as a Robot Framework dictionary:

```robotframework
*** Variables ***
&{task_params_set}
...    account_param=../shared/${ACCOUNT_NAME}
...    schema_param=DEMO
...    table_param=TEST_TABLE
...    input_file=${input_file_name}
```

### Overriding Parameters (at Execute)

Parameters can be overridden at execution time using key=value syntax:

```robotframework
[Template]    Run Triggered Task With Parameters From Template
${unique_id}    ${PIPELINES_LOCATION_PATH}    ${pipeline_name}    ${task_name}    input_file=different_file.json    schema=PROD
```

### Common Parameter Patterns

| Parameter | Description | Example Value |
|-----------|-------------|---------------|
| Account reference | Path to account in SnapLogic | `../shared/snowflake_acct` |
| Schema | Database schema | `DEMO` |
| Table | Table name | `DEMO.TEST_TABLE` |
| Input file | Input file name | `test_input.json` |
| Mode flag | Test/prod mode | `test` |

---

## Notification Configuration

### Setting Up Notifications

```robotframework
*** Variables ***
# Define which states trigger notifications
@{notification_states}          Completed    Failed

# Configure notification settings
&{task_notifications}
...    recipients=email1@example.com,email2@example.com
...    states=${notification_states}
```

### Available Notification States
- `Completed` — Task completed successfully
- `Failed` — Task execution failed
- `Started` — Task started execution
- `Stopped` — Task was stopped

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
│  4. Import Pipeline     │
│  (.slp file)            │
└───────────┬─────────────┘
            │
            ▼
┌─────────────────────────┐
│  5. Create Triggered    │  ◄── CREATE TASK
│     Task                │
└───────────┬─────────────┘
            │
            ▼
┌─────────────────────────┐
│  6. Execute Triggered   │  ◄── EXECUTE TASK
│     Task                │
└───────────┬─────────────┘
            │
            ▼
┌─────────────────────────┐
│  7. Verify Results      │
└─────────────────────────┘
```

---

## MANDATORY: TRIGGERED_TASK_README.md with File Structure

**IMPORTANT: Every time you create triggered task test cases, you MUST also create a TRIGGERED_TASK_README.md in the same directory with a file structure diagram.**

This is required for ALL triggered tasks. No exceptions.

### README Template

````markdown
# [Type] Triggered Task Tests

This test suite creates AND executes triggered tasks for [Type] pipeline testing.

## Purpose
Creates triggered task(s) for [Type] pipeline execution with configurable parameters, then executes them with optional parameter overrides.

## Two Key Operations

| Operation | Keyword | Purpose |
|-----------|---------|---------|
| **Create Task** | `Create Triggered Task From Template` | Defines the task with default parameters |
| **Execute Task** | `Run Triggered Task With Parameters From Template` | Runs the task, optionally overriding parameters |

## File Structure
```
project-root/
├── test/
│   └── suite/
│       └── pipeline_tests/
│           └── [type]/
│               ├── [type]_triggered_task.robot                ← Test case file
│               └── TRIGGERED_TASK_README.md                   ← This file
└── .env                                                       ← Environment configuration
```

## Prerequisites
1. [Type] account must be created (`/create-account`)
2. Pipeline must be imported (`/import-pipeline`)
3. Environment variables configured in `.env`

## Task Parameters (Set at Creation)
- `[param1]` — Description
- `[param2]` — Description

## Parameter Overrides (At Execution)
- `[param1]` — Override description
- `[param2]` — Override description

## How to Run
```bash
make robot-run-all-tests TAGS="[type] AND triggered_task" PROJECT_SPACE_SETUP=True
```
````

---

## Troubleshooting

### Common Issues

| Issue | Cause | Solution |
|-------|-------|----------|
| `Pipeline not found` | Pipeline not imported | Run `/import-pipeline` first |
| `Account not found` | Account not created | Run `/create-account` first |
| `Task not found` | Task not created | Run Create Triggered Task first |
| `Invalid parameter` | Parameter name mismatch | Check pipeline parameter names |
| `Task creation failed` | Permission issue | Verify SnapLogic permissions |
| `Execution timeout` | Long-running pipeline | Increase `execution_timeout` |
| `Parameter override ignored` | Wrong key name | Check parameter name matches pipeline |

### Debug Tips

1. **Verify task exists before executing:**
   ```robotframework
   Log    Task: ${task_name}    console=yes
   Log    Pipeline: ${pipeline_name}    console=yes
   ```

2. **Log execution parameters:**
   ```robotframework
   Log    Executing with input_file: ${input_file_name}    console=yes
   ```

3. **Log task parameters:**
   ```robotframework
   Log Dictionary    ${task_params_set}    console=yes
   ```

4. **Check environment variables:**
   ```bash
   make check-env
   ```

---

## Checklist Before Committing

- [ ] Pipeline is imported first
- [ ] Required accounts are created
- [ ] Task parameters match pipeline parameters
- [ ] `${task_name}` variable defined
- [ ] Create Triggered Task test case included
- [ ] Execute Triggered Task test case included (if needed)
- [ ] Parameter overrides use correct key names
- [ ] Test has appropriate tags (`task_creation`, `task_execution`, `triggered_task`)
- [ ] Documentation describes both create and execute operations
- [ ] **TRIGGERED_TASK_README.md created with file structure diagram**
