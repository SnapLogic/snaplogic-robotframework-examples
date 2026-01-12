---
description: Guide for debugging test failures and viewing logs
---

# Debug Logs

## Agentic Workflow (Claude: Follow these steps in order)

### Step 1: Load the Complete Guide
```
ACTION: Use the Read tool to load:
{{cookiecutter.primary_pipeline_name}}/.claude/commands/debug-logs.md
```
**Do not proceed until you have read the complete guide.**

### Step 2: Understand the User's Request
Parse what the user wants:
- View test results?
- Check container/service logs?
- Debug a specific test failure?
- Environment diagnostics?
- Network troubleshooting?

### Step 3: Follow the Guide
Use the detailed instructions from the file you loaded in Step 1 to:
- Provide correct log viewing commands
- Guide through debugging checklist
- Help interpret error messages

### Step 4: Respond to User
Provide debugging guidance and commands based on the complete guide.

---

## Quick Reference

This guide covers:
- Quick debugging checklist
- Viewing test results
- Container and service logs
- Environment diagnostics
- Network troubleshooting
- Common error patterns
