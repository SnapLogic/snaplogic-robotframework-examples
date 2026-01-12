---
description: Guide for setting up database containers for testing
---

# Setup Database

## Agentic Workflow (Claude: Follow these steps in order)

### Step 1: Load the Complete Guide
```
ACTION: Use the Read tool to load:
{{cookiecutter.primary_pipeline_name}}/.claude/commands/setup-database.md
```
**Do not proceed until you have read the complete guide.**

### Step 2: Understand the User's Request
Parse what the user wants:
- Which database? (Oracle, PostgreSQL, MySQL, SQL Server, DB2, Teradata, Snowflake)
- Start/stop/status commands?
- Load test data?
- Troubleshoot connection issues?

### Step 3: Follow the Guide
Use the detailed instructions from the file you loaded in Step 1 to:
- Provide correct make commands for the database
- Guide through configuration steps
- Help with data loading

### Step 4: Respond to User
Provide database setup commands and guidance based on the complete guide.

---

## Quick Reference

This guide covers:
- Available databases (Oracle, PostgreSQL, MySQL, SQL Server, DB2, Teradata, Snowflake)
- Quick start commands
- Database-specific configurations
- Loading test data
- Troubleshooting database connections
