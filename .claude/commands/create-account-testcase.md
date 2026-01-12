---
description: Guide for creating Robot Framework test cases that create SnapLogic accounts
---

# Create Account Test Case

## Agentic Workflow (Claude: Follow these steps in order)

### Step 1: Load the Complete Guide
```
ACTION: Use the Read tool to load:
{{cookiecutter.primary_pipeline_name}}/.claude/commands/create-account-testcase.md
```
**Do not proceed until you have read the complete guide.**

### Step 2: Understand the User's Request
Parse what the user wants:
- Which account type? (oracle, postgres, snowflake, etc.)
- Create test case? Check env variables? Show template?
- Natural language request?

### Step 3: Follow the Guide
Use the detailed instructions from the file you loaded in Step 1 to:
- Identify the correct env file
- Read the env file to understand available variables
- Check baseline tests for reference if needed
- Create or explain the test case

### Step 4: Respond to User
Provide the requested information or create the requested file.

---

## Quick Reference

| Command | Action |
|---------|--------|
| `/create-account-testcase` | Default menu with quick options |
| `/create-account-testcase info` | Full menu with all commands |
| `/create-account-testcase list` | Table of supported account types |
| `/create-account-testcase create oracle` | Create Oracle account test case |
| `/create-account-testcase check snowflake` | Check Snowflake env variables |

## Supported Account Types

`oracle`, `postgres`, `mysql`, `sqlserver`, `snowflake`, `snowflake-keypair`, `db2`, `teradata`, `kafka`, `jms`, `s3`, `email`, `salesforce`
