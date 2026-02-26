---
name: create-account
description: Creates Robot Framework test cases for SnapLogic account creation. Use when the user wants to create accounts (Oracle, PostgreSQL, Snowflake, Kafka, S3, etc.), needs to know what environment variables to configure, or wants to see account test case examples.
user-invocable: true
---

# SnapLogic Account Creation Skill

## Agentic Workflow (Claude: Follow these steps in order)

### Step 1: Load the Complete Guide
```
ACTION: Use the Read tool to load:
{{cookiecutter.primary_pipeline_name}}/.claude/skills/create-account/SKILL.md
```
**Do not proceed until you have read the complete guide.**

### Step 2: Follow the Complete Guide
Follow all instructions from the guide loaded in Step 1.

---

## Quick Reference

**Supported account types:**
`oracle`, `postgres`, `mysql`, `sqlserver`, `snowflake`, `snowflake-keypair`, `db2`, `teradata`, `kafka`, `jms`, `s3`, `email`, `salesforce`

**Invoke with:** `/create-account`
