---
description: Guide for creating Robot Framework test cases that upload files to SnapLogic SLDB
---

# Upload File Test Case

## Agentic Workflow (Claude: Follow these steps in order)

### Step 1: Load the Complete Guide
```
ACTION: Use the Read tool to load:
{{cookiecutter.primary_pipeline_name}}/.claude/commands/upload-file-testcase.md
```
**Do not proceed until you have read the complete guide.**

### Step 2: Understand the User's Request
Parse what the user wants:
- What file type? (JSON, CSV, expression library, pipeline, JAR, etc.)
- Upload to which location? (project, shared folder, etc.)
- Single file or multiple files?
- Natural language request?

### Step 3: Follow the Guide
Use the detailed instructions from the file you loaded in Step 1 to:
- Identify the correct destination path variable
- Check baseline tests for reference if needed
- Create or explain the test case

### Step 4: Respond to User
Provide the requested information or create the requested file.

---

## Quick Reference

| Command | Action |
|---------|--------|
| `/upload-file-testcase` | Default menu with quick options |
| `/upload-file-testcase info` | Full menu with all commands |
| `/upload-file-testcase template` | Generic upload test case template |
| `/upload-file-testcase create json` | Create JSON file upload test case |
| `/upload-file-testcase create expr` | Create expression library upload test case |

## Supported File Types

`json`, `csv`, `slp` (pipeline), `expr` (expression library), `jar`, `txt`, `xml`, and any other file type

## Key Environment Variables

| Variable | Description |
|----------|-------------|
| `${PIPELINES_LOCATION_PATH}` | Project folder path (e.g., `org/project_space/project`) |
| `${ACCOUNT_LOCATION_PATH}` | Shared folder path (e.g., `org/project_space/shared`) |
