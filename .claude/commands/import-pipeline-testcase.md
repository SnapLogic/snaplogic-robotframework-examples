---
description: Guide for creating Robot Framework test cases that import SnapLogic pipelines
---

# Pipeline Import Test Case Guide

## Agentic Workflow (Claude: Follow these steps in order)

### Step 1: Load the Complete Guide
```
ACTION: Use the Read tool to load:
{{cookiecutter.primary_pipeline_name}}/.claude/commands/import-pipeline-testcase.md
```
**Do not proceed until you have read the complete guide.**

### Step 2: Understand the User's Request
Parse what the user wants:
- Import a single pipeline or multiple pipelines?
- Need prerequisites checklist?
- Show template or examples?
- Questions about pipeline parameterization?

### Step 3: Follow the Guide
Use the detailed instructions from the file you loaded in Step 1 to:
- Show the prerequisites for pipeline import
- Verify pipeline .slp file location
- Create or explain the test case
- Provide troubleshooting if needed

### Step 4: Respond to User
Provide the requested information or create the test case based on the complete guide.

---

## Quick Reference

**Prerequisites:**
1. Build and test pipeline in SnapLogic Designer
2. Export pipeline as `.slp` file
3. Upload `.slp` file to `src/pipelines/`
4. Configure test variables

**Pipeline file location:**
```
src/pipelines/your_pipeline.slp
```

**Required variables:**
- `${pipeline_name}` - Logical name (without .slp extension)
- `${pipeline_file_name}` - Physical file name (with .slp extension)
- `${PIPELINES_LOCATION_PATH}` - SnapLogic destination path
- `${unique_id}` - Generated in suite setup

**Baseline test references:**
- `test/suite/pipeline_tests/snowflake/snowflake_baseline_tests.robot`
- `test/suite/pipeline_tests/oracle/oracle_baseline_tests.robot`
