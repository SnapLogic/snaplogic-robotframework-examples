---
description: Guide for running Robot Framework tests in this SnapLogic project
---

# Robot Framework Test Execution Guide

## Claude Instructions

**IMPORTANT:** When user asks a simple question like "How do I run Oracle tests?", provide a **concise answer first** with just the command(s), then offer to explain more if needed. Do NOT dump all documentation.

**Response format for simple questions:**
1. Give the direct command(s) first
2. Add a brief note if relevant
3. Offer "Want me to explain more?" only if appropriate

---

## Quick Command Reference

| Test Type | Command |
|-----------|---------|
| Oracle | `make robot-run-all-tests TAGS="oracle" PROJECT_SPACE_SETUP=True` |
| PostgreSQL | `make robot-run-all-tests TAGS="postgres" PROJECT_SPACE_SETUP=True` |
| Snowflake | `make robot-run-all-tests TAGS="snowflake" PROJECT_SPACE_SETUP=True` |
| Kafka | `make robot-run-all-tests TAGS="kafka" PROJECT_SPACE_SETUP=True` |
| MySQL | `make robot-run-all-tests TAGS="mysql" PROJECT_SPACE_SETUP=True` |
| Multiple | `make robot-run-all-tests TAGS="oracle OR postgres" PROJECT_SPACE_SETUP=True` |

**Note:** Use `PROJECT_SPACE_SETUP=True` for first run, omit for subsequent runs.

---

## Usage Examples

| What You Want | Example Prompt |
|---------------|----------------|
| Explain test execution | `/run-tests Explain how to run robot tests in this project` |
| Run specific tests | `/run-tests How do I run Oracle tests?` |
| First time setup | `/run-tests I'm running tests for the first time, what should I do?` |
| Understand tags | `/run-tests What tags are available for running tests?` |
| Run multiple tests | `/run-tests How do I run both Snowflake and Kafka tests?` |
| View results | `/run-tests Where are the test results stored?` |
| Troubleshoot | `/run-tests My tests are failing, how do I debug?` |
| Quick iteration | `/run-tests I want to run tests quickly without Groundplex setup` |

---

## Agentic Workflow (Claude: Follow these steps in order)

### Step 1: Load the Complete Guide
```
ACTION: Use the Read tool to load:
{{cookiecutter.primary_pipeline_name}}/.claude/commands/run-tests.md
```
**Do not proceed until you have read the complete guide.**

### Step 2: Understand the User's Request
Parse what the user wants:
- How to run tests with specific tags?
- Full workflow with environment setup?
- Understanding PROJECT_SPACE_SETUP parameter?
- Viewing test results?
- Troubleshooting test runs?

### Step 3: Follow the Guide
Use the detailed instructions from the file you loaded in Step 1 to:
- Provide correct make commands
- Explain tag usage and options
- Guide through the complete workflow

### Step 4: Respond to User
Provide clear commands and explanations based on the complete guide.

---

## Quick Reference

**Why Make Commands?**
This project uses a dockerized environment. Tests run inside Docker containers, not on your local machine. The `make` commands handle container orchestration, networking, and environment setup.

**Key Commands:**
```bash
# Full setup (first time)
make robot-run-all-tests TAGS="snowflake_demo" PROJECT_SPACE_SETUP=True

# Subsequent runs
make robot-run-all-tests TAGS="snowflake_demo"

# Quick iteration (Groundplex already running)
make robot-run-tests-no-gp TAGS="snowflake_demo"
```

**Related slash command:** `/run-tests`
