# RF Forge — AI-Powered Test Generation

Generate Robot Framework test cases for SnapLogic pipeline testing using Claude AI.

## Setup

```bash
# From the project root:
pip install -e ai/

# Or if your network blocks GitHub:
pip install -e /path/to/claude-gen-agent
pip install -e ai/
```

## Skills

| Skill | Command | What it generates |
|---|---|---|
| `create-account` | `rf-forge create-account` | Account test cases (payload JSON, env file, .robot, README) |
| `import-pipeline` | `rf-forge import-pipeline` | Pipeline import .robot test cases |
| `upload-file` | `rf-forge upload-file` | File upload .robot test cases |
| `create-triggered-task` | `rf-forge create-triggered-task` | Triggered task .robot test cases |
| `compare-csv` | `rf-forge compare-csv` | CSV comparison .robot test cases |
| `verify-data-in-db` | `rf-forge verify-data-in-db` | Database verification .robot test cases |
| `export-data-to-csv` | `rf-forge export-data-to-csv` | Data export .robot test cases |
| `end-to-end-pipeline-verification` | `rf-forge end-to-end-pipeline-verification` | Complete E2E .robot test suite |

## Usage

```bash
# Load AWS Bedrock credentials
set -a; source .env; set +a

# Generate account test cases
rf-forge create-account "Create Oracle and Snowflake accounts" --codebase-path .

# Generate complete E2E test suite
rf-forge end-to-end-pipeline-verification "MySQL E2E tests" --codebase-path .

# With extra context
rf-forge create-account "Create Oracle account" \
    --codebase-path . \
    --context-file ./docs/company-conventions.md

# With session log
rf-forge create-account "Create Oracle account" \
    --codebase-path . \
    --output-dir ./ai-session-logs/oracle
```

## Via Makefile

```bash
make rf-create-account INSTRUCTION="Create Oracle account"
make rf-e2e INSTRUCTION="MySQL E2E tests"
```

## Architecture

```
ai/                              ← this folder
├── pyproject.toml               ← package config (rf-forge CLI)
├── context/
│   └── qa-testing.md            ← shared QA knowledge
├── plugins → ../.claude/skills  ← symlink (no duplication)
└── src/rf_forge/
    ├── cli.py                   ← 8 subcommands, one generic handler
    ├── skills.py                ← 8 SkillDef entries
    ├── runner.py                ← ClaudeGenAgent wrapper
    └── report_mode.py           ← output format instructions
```

SKILL.md files live in `../.claude/skills/` (the RF repo's existing skills). The `plugins` symlink points there — zero duplication.
