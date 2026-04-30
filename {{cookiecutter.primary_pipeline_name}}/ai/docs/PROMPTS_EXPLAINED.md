# System Prompt vs User Prompt in RFForge — Complete Reference

> How Claude receives instructions in RFForge. Covers what the system prompt contains, what the user prompt contains, how they combine, and what a "preset" is.

---

## TL;DR

Every Claude API request has **two prompt slots**: **system prompt** (persistent rules/identity) and **user prompt** (specific task). They're kept separate in the API, but Claude reads both before replying.

In RFForge:
- **System prompt** = `claude_code` preset + `qa-testing.md` + `SKILL.md` body (Few-Shot examples live here)
- **User prompt** = skill command + args + Chain-of-Thought instructions + report format template

The `preset` is a pre-written system prompt maintained by Anthropic. You use it so you don't have to write thousands of lines from scratch.

---

## The 2 prompt slots every Claude request has

| Slot | Role | In RFForge |
|---|---|---|
| **System prompt** | Persistent instructions — "who you are, what rules to follow" | `claude_code` preset + `qa-testing.md` + `SKILL.md` body |
| **User prompt** | The actual task — "do THIS specific thing" | The `/create-account` slash command + args + CoT instructions + report format |

Claude reads the system prompt FIRST (as context), then the user prompt (as the task). It does NOT forget the system prompt — it's present for every turn of the conversation.

**They're not literally concatenated into one string.** Claude's API keeps them separate fields. But functionally, Claude reads both before replying.

---

## In RFForge — what goes where?

### The SYSTEM prompt gets these 3 things

```
┌─────────────────────────────────────────────────┐
│  SYSTEM PROMPT (persistent for whole session)   │
│                                                 │
│  ① Claude Code's base preset system prompt      │
│     (from system_prompt={"preset":"claude_code"})│
│                                                 │
│  ② Your qa-testing.md content                   │
│     (from context_files=[qa-testing.md])        │
│                                                 │
│  ③ Your SKILL.md body                           │
│     (loaded automatically from plugins/)        │
└─────────────────────────────────────────────────┘
```

### The USER prompt gets these 3 things

```
┌─────────────────────────────────────────────────┐
│  USER PROMPT (the task message)                 │
│                                                 │
│  ④ The skill command + args                     │
│     (from skill.format_prompt(args))            │
│                                                 │
│  ⑤ Chain-of-Thought instructions                │
│     (from skill.cot_instructions — appended     │
│      by format_prompt() after the args)         │
│                                                 │
│  ⑥ The report format instructions               │
│     (from report_mode.get_report_instructions)  │
└─────────────────────────────────────────────────┘
```

---

## Looking at the code — exactly where each goes

### `skills.py` — `format_prompt()` builds ④ and ⑤

```python
def format_prompt(self, args: dict[str, str]) -> str:
    lines = [f"/{self.name}"]                            # ④ slash command
    for arg_name in self.positional_args:
        lines.append(f"{arg_name}: {args[arg_name]}")    # ④ key-value args

    if self.cot_instructions:                             # ⑤ Chain-of-Thought
        lines.append("")
        lines.append(self.cot_instructions)

    return "\n".join(lines)
```

### `runner.py` — combines everything and sends to Claude

```python
# USER PROMPT being built:
prompt = skill.format_prompt(args)                     # ④ + ⑤ (command + args + CoT)
report_instructions = get_report_instructions(skill.name)
prompt += f"\n\n{report_instructions}"                 # ⑥ appended to same user prompt

agent = ClaudeGenAgent(
    # SYSTEM PROMPT components:
    system_prompt={"type": "preset", "preset": "claude_code"},  # ①
    context_files=all_context_files,                             # ② qa-testing.md + extras
    plugins=[str(plugins_dir)],                                  # ③ SKILL.md (Few-Shot examples)

    # ... other kwargs ...
)

# Pass user prompt to agent
asyncio.run(agent.run(prompt, mode=mode))   # ← the variable `prompt` is the USER prompt
```

**Key observation:** In your code:
- `system_prompt=...`, `context_files=...`, `plugins=...` → all become **system prompt**
- The `prompt` variable (first arg of `agent.run()`) → is the **user prompt**
- `format_prompt()` produces both the task (④) AND the CoT reasoning steps (⑤)
- `report_mode` produces the output format instructions (⑥)

---

## Worked example — create-account run

When you run this command:
```bash
rf-forge create-account "Create Oracle and Snowflake accounts" \
    --codebase-path /path/to/rf-project
```

Claude receives these 2 prompt slots:

### System prompt (invisible persistent context)

```
[Claude Code base instructions — thousands of lines about tools, formatting, etc.]

[qa-testing.md contents]
# QA Testing — Shared Knowledge for RF Forge Agents
Core Testing Principles:
1. Test Independence
2. AAA Pattern
...

[SKILL.md body from plugins/skills/create-account/]
# Create Account Test Case Guide
## Claude Instructions
MANDATORY WORKFLOW: When creating account test cases...
The 4 required files are:
1. Payload file (acc_[type].json)
2. Env file (.env.[type])
3. Robot test file (.robot)
4. ACCOUNT_SETUP_README.md
...
```

### User prompt (the actual task message)

```
/create-account                                              ← ④ skill command
instruction: Create Oracle and Snowflake accounts            ← ④ args
codebase_path: /path/to/rf-project                           ← ④ args

Think step by step before generating any files:              ← ⑤ Chain-of-Thought
1. First, read the codebase to understand the existing       │
   project structure                                         │
2. Check which of the 4 required files already exist         │
   (payload, env, .robot, README)                            │
3. For existing files, read their content to understand      │
   current patterns                                          │
4. Only create files that are missing — do NOT overwrite     │
   existing correct files                                    │
5. Follow the exact naming conventions used in existing      │
   account types                                             ← end of CoT

## Report Format: Unified (Summary + Technical Details)      ← ⑥ report format

Generate a unified report with two parts in a single markdown file:
### Part 1: Human-Readable Summary ...
### Part 2: Technical Details ...
```

Claude reads **both** before replying. The system prompt gives it identity + rules + the specific account creation patterns (with Few-Shot examples); the user prompt gives it the specific task + CoT reasoning steps + output format.

---

## The 3 layers of Claude's system prompt in RFForge

```
Claude's system prompt (what it reads every turn):

┌──────────────────────────────────────────────────────┐
│  LAYER 1 — claude_code preset                         │
│  (Anthropic-maintained, ~2000+ lines)                 │
│  "You are Claude. Use tools responsibly. Format..."   │
└──────────────────────────────────────────────────────┘
          ↓ (appended below)
┌──────────────────────────────────────────────────────┐
│  LAYER 2 — context_files (qa-testing.md)              │
│  "Testing principles, coverage targets, DO NOTs..."   │
└──────────────────────────────────────────────────────┘
          ↓ (appended below)
┌──────────────────────────────────────────────────────┐
│  LAYER 3 — SKILL.md body (via plugins)                │
│  "Create Account Test Case Guide. 4 required files..."│
└──────────────────────────────────────────────────────┘

         All 3 layers combined = Claude's system prompt
```

All three contribute:
- The preset handles **generic tool usage** (how to use Read, Write, Bash, etc.)
- `qa-testing.md` handles **testing conventions** (AAA pattern, coverage targets)
- `SKILL.md` handles **skill-specific behavior** (account creation patterns, file templates, workflows)

---

## What is a `preset`?

A **preset** is a **pre-written, maintained-by-Anthropic system prompt** you can use instead of writing your own from scratch. In `runner.py`:

```python
system_prompt={"type": "preset", "preset": "claude_code"}
```

You're saying: *"Don't make me write the system prompt myself. Use Anthropic's official 'claude_code' preset — the same one that powers the Claude Code CLI."*

### What does the `claude_code` preset contain?

| Category | What's in it |
|---|---|
| **Identity** | "You are Claude, built by Anthropic..." |
| **Tool usage rules** | How to use Read, Write, Bash, etc. |
| **Output formatting** | When to use markdown, code blocks, etc. |
| **Error handling** | What to do when a tool fails |
| **Safety** | Never modify system files, ask before destructive actions |
| **Conventions** | Matching project styles, using idiomatic code |

You don't see it directly (it's internal to Claude Code), but it's there. **99% of Forge-style apps use this preset.**

---

## The visual flow for every run

```
User types: rf-forge create-account "Create Oracle account" --codebase-path ...
                        │
                        ▼
            cli.py parses the CLI args
                        │
                        ▼
            runner.py is called
                        │
    ┌───────────────────┴──────────────────┐
    │                                      │
    ▼                                      ▼
BUILD SYSTEM PROMPT                   BUILD USER PROMPT
                                            │
• claude_code preset              ①   • /create-account           ④
• qa-testing.md content           ②   • instruction: "..."        ④
• SKILL.md body (Few-Shot)        ③   • codebase_path: "..."      ④
                                      • + CoT instructions        ⑤
                                      • + report format template  ⑥
    │                                      │
    └──────────────┬───────────────────────┘
                   │
                   ▼
          ClaudeGenAgent(...)
                   │
                   ▼
         Both prompts sent to Claude
                   │
                   ▼
         Claude reads system prompt
         Then reads user prompt
         Then responds + uses tools
                   │
                   ▼
         Generates .robot files,
         payload JSONs, env files,
         READMEs in user's codebase
```

---

## Prompting patterns used in RFForge

RFForge applies 6 of the 8 standard prompting patterns. Here's where each one lives:

### Pattern 1 — Basic Prompting

**What:** Send a clear, specific message to Claude.

**Where:** `format_prompt()` builds a clear, unambiguous task message:

```
/create-account
instruction: Create Oracle and Snowflake accounts
codebase_path: /path/to/project
```

Key-value format (not space-separated) so Claude knows exactly what each value is.

### Pattern 2 — System vs User Prompts

**What:** Separate persistent identity/rules from the specific task.

**Where:**
- System prompt = `ClaudeGenAgent(system_prompt=..., context_files=..., plugins=...)`
- User prompt = `agent.run(prompt)` — the `prompt` variable

Claude reads both. System prompt stays constant across all turns; user prompt is the one-time task.

### Pattern 3 — Prompt Templates

**What:** Reusable prompts with placeholders filled in at runtime.

**Where:** `format_prompt()` is literally a template engine:

```python
# Template (defined in skills.py):
positional_args = ["instruction", "codebase_path"]

# Filled at runtime (different values each run):
args = {"instruction": "Create Oracle account", "codebase_path": "/path/to/project"}

# Output (same structure, different values):
"/create-account\ninstruction: Create Oracle account\ncodebase_path: /path/to/project"
```

Same template, different values each run — like calling `SYSTEM_TEMPLATE.format(domain="...", tone="...")`.

### Pattern 4 — Few-Shot Prompting

**What:** Teach by showing examples before asking.

**Where:** Inside each `SKILL.md` file. For example, `create-account/SKILL.md` contains full working examples:

```
Here's a complete Oracle account test case:     ← example 1
  (full .robot file, full .json payload, full .env file)

Here's a complete Snowflake account test case:  ← example 2
  (full .robot file, full .json payload, full .env file)

Now create one for: {whatever the user asked}   ← the actual task
```

Claude sees 2-3 complete examples in the system prompt, then applies the pattern to the user's request. This is Few-Shot — "here are examples, now do the same."

**Key insight:** The examples live in `SKILL.md` (system prompt, Layer 3), NOT in the user prompt. This is intentional — system prompt examples persist across all turns of a multi-turn conversation.

### Pattern 5 — Chain-of-Thought

**What:** Ask Claude to reason step-by-step before answering.

**Where:** The `cot_instructions` field in each `SkillDef`, appended by `format_prompt()`:

```python
# In skills.py:
"create-account": SkillDef(
    ...
    cot_instructions=(
        "Think step by step before generating any files:\n"
        "1. First, read the codebase to understand the existing project structure\n"
        "2. Check which of the 4 required files already exist\n"
        "3. For existing files, read their content to understand current patterns\n"
        "4. Only create files that are missing\n"
        "5. Follow the exact naming conventions used in existing account types"
    ),
)
```

This gets appended to the user prompt after the args, before the report format. Claude reads these steps and follows them in order — reducing errors like overwriting existing files or using wrong naming conventions.

**Why CoT makes output more stable:**

| Without CoT | With CoT |
|---|---|
| Claude jumps to writing files | Claude reads existing patterns first |
| Might overwrite correct files | Checks what exists before creating |
| Naming inconsistency | Follows existing conventions |
| Output varies between runs | Same reasoning steps → more predictable |

### Pattern 6 — Structured Output

**What:** Force the output into a specific format.

**Where:** `report_mode.py` — appended as the last part of the user prompt:

```
## Report Format: Unified (Summary + Technical Details)

Generate a unified report with two parts:
### Part 1: Human-Readable Summary (top)
### Part 2: Technical Details (bottom)
```

This ensures every skill produces consistently structured output — not freeform text.

### Pattern 7 — Multi-Turn Conversations

**What:** Maintain context across multiple back-and-forth exchanges.

**Where:** Handled entirely by `ClaudeGenAgent`. A single `agent.run(prompt)` call typically generates 10-50 internal turns:

```
Turn 1:  Claude → "I'll check existing files" → tool_use: Glob
Turn 2:  Library → sends file list back → tool_result
Turn 3:  Claude → "Reading existing Oracle test" → tool_use: Read
Turn 4:  Library → sends file content → tool_result
Turn 5:  Claude → "Creating acc_oracle.json" → tool_use: Write
...
Turn 12: Claude → "Done — 4 files created"
```

You don't manage these turns. The library handles the `role: assistant` and `role: user` messages for each tool call automatically.

### Pattern 8 — RAG

**What:** Search a knowledge base to find relevant context.

**Where:** NOT used. RFForge uses static context injection (same files every run), not dynamic retrieval. With only 8 skills, direct lookup by subcommand name is sufficient — no vector search needed.

---

### Summary: all 6 components of a RFForge prompt

```
┌─────────────────────────────────────────────────────────────────┐
│  SYSTEM PROMPT                                                  │
│                                                                 │
│  ① Preset (claude_code)         — Basic Prompting              │
│  ② Context files (qa-testing.md) — System vs User              │
│  ③ SKILL.md (with examples)     — Few-Shot                     │
├─────────────────────────────────────────────────────────────────┤
│  USER PROMPT                                                    │
│                                                                 │
│  ④ Skill command + args         — Prompt Templates             │
│  ⑤ CoT instructions             — Chain-of-Thought             │
│  ⑥ Report format template       — Structured Output            │
├─────────────────────────────────────────────────────────────────┤
│  RUNTIME (handled by library)                                   │
│                                                                 │
│  ⑦ Multi-turn tool calls        — Multi-Turn                   │
└─────────────────────────────────────────────────────────────────┘
```

---

## All 8 skills — complete prompt examples

Each skill produces a user prompt with the same structure: slash command + args + CoT + report format. Only ONE SKILL.md is active per run — Claude sees the matching SKILL.md in its system prompt, not the other 7.

### CLI flags that affect the prompt

| Flag | Affects | How |
|---|---|---|
| `instruction` (positional) | User prompt ④ | Becomes `instruction: <text>` |
| `--file PATH` | User prompt ④ | File content replaces positional text in `instruction:` |
| `--codebase-path PATH` | User prompt ④ | Becomes `codebase_path: <path>` |
| `--context-file PATH` | System prompt ② | Extra file added alongside `qa-testing.md` |
| `--model NAME` | Agent config | Which Claude model runs (not in prompt text) |
| `--max-budget FLOAT` | Agent config | Dollar cap (not in prompt text) |
| `--output-dir PATH` | Post-run | Where SESSION_SUMMARY.md is saved (not in prompt text) |
| `--json-log PATH` | Agent config | Where JSONL audit log is written (not in prompt text) |
| `--raw-json` | Agent config | Output format — raw JSON vs pretty colors (not in prompt text) |

---

### Skill 1 — `create-account`

**CLI:**
```bash
rf-forge create-account "Create Oracle and Snowflake accounts" \
    --codebase-path "/path/to/rf-project"
```

**User prompt Claude sees:**
```
/create-account
instruction: Create Oracle and Snowflake accounts
codebase_path: /path/to/rf-project

Think step by step before generating any files:
1. First, read the codebase to understand the existing project structure
2. Check which of the 4 required files already exist (payload, env, .robot, README)
3. For existing files, read their content to understand current patterns
4. Only create files that are missing — do NOT overwrite existing correct files
5. Follow the exact naming conventions used in existing account types

## Report Format: Unified (Summary + Technical Details)
...
```

**System prompt includes:** `create-account/SKILL.md` (1043 lines — account types, payload templates, env file patterns, .robot examples for Oracle, Snowflake, PostgreSQL, etc.)

---

### Skill 2 — `import-pipeline`

**CLI:**
```bash
rf-forge import-pipeline "Import the MySQL pipeline" \
    --codebase-path "/path/to/rf-project"
```

**User prompt Claude sees:**
```
/import-pipeline
instruction: Import the MySQL pipeline
codebase_path: /path/to/rf-project

Think step by step before generating any files:
1. First, check what .slp pipeline files exist in src/pipelines/
2. Read existing pipeline import tests to understand the project's patterns
3. Identify the pipeline name, task names, and account references
4. Generate the .robot file following existing conventions

## Report Format: Unified (Summary + Technical Details)
...
```

---

### Skill 3 — `upload-file`

**CLI:**
```bash
rf-forge upload-file "Upload MySQL JDBC driver JAR and expression libraries" \
    --codebase-path "/path/to/rf-project"
```

**User prompt Claude sees:**
```
/upload-file
instruction: Upload MySQL JDBC driver JAR and expression libraries
codebase_path: /path/to/rf-project

Think step by step before generating any files:
1. First, identify what files need to be uploaded and their types
2. Check existing upload tests to understand the project's upload patterns
3. Determine the correct destination path based on file type
4. Generate the .robot file using the correct upload keyword and protocol

## Report Format: Unified (Summary + Technical Details)
...
```

---

### Skill 4 — `create-triggered-task`

**CLI:**
```bash
rf-forge create-triggered-task "Create and execute MySQL triggered task with date parameters" \
    --codebase-path "/path/to/rf-project"
```

**User prompt Claude sees:**
```
/create-triggered-task
instruction: Create and execute MySQL triggered task with date parameters
codebase_path: /path/to/rf-project

Think step by step before generating any files:
1. First, read the pipeline file to understand its parameters
2. Check existing triggered task tests for naming and parameter conventions
3. Identify the Groundplex name, task parameters, and notification settings
4. Generate the .robot file with correct task creation and execution keywords

## Report Format: Unified (Summary + Technical Details)
...
```

---

### Skill 5 — `compare-csv`

**CLI:**
```bash
rf-forge compare-csv "Compare Oracle pipeline CSV output against expected results" \
    --codebase-path "/path/to/rf-project"
```

**User prompt Claude sees:**
```
/compare-csv
instruction: Compare Oracle pipeline CSV output against expected results
codebase_path: /path/to/rf-project

Think step by step before generating any files:
1. First, identify the actual output CSV location and expected CSV location
2. Check existing comparison tests for the project's comparison patterns
3. Determine if order matters, which columns to compare, and tolerance settings
4. Generate the .robot file using the correct comparison template keyword

## Report Format: Unified (Summary + Technical Details)
...
```

---

### Skill 6 — `verify-data-in-db`

**CLI:**
```bash
rf-forge verify-data-in-db "Verify employee data loaded into MySQL employees table" \
    --codebase-path "/path/to/rf-project"
```

**User prompt Claude sees:**
```
/verify-data-in-db
instruction: Verify employee data loaded into MySQL employees table
codebase_path: /path/to/rf-project

Think step by step before generating any files:
1. First, identify which database and tables to verify
2. Read existing verification tests to understand the query patterns
3. Check the queries resource file for existing SQL queries
4. Determine what assertions are needed (row counts, specific values, exports)
5. Generate the .robot file with correct database keywords and assertions

## Report Format: Unified (Summary + Technical Details)
...
```

---

### Skill 7 — `export-data-to-csv`

**CLI:**
```bash
rf-forge export-data-to-csv "Export Oracle employees table to CSV for comparison" \
    --codebase-path "/path/to/rf-project"
```

**User prompt Claude sees:**
```
/export-data-to-csv
instruction: Export Oracle employees table to CSV for comparison
codebase_path: /path/to/rf-project

Think step by step before generating any files:
1. First, identify the database type and connection details
2. Read existing export tests to understand the project's export patterns
3. Determine the SQL query, output path, and file naming convention
4. Generate the .robot file using the correct export keyword

## Report Format: Unified (Summary + Technical Details)
...
```

---

### Skill 8 — `end-to-end-pipeline-verification`

**CLI:**
```bash
rf-forge end-to-end-pipeline-verification \
    "Create complete E2E tests for MySQL data pipeline — accounts, uploads, import, execute, verify" \
    --codebase-path "/path/to/rf-project"
```

**User prompt Claude sees:**
```
/end-to-end-pipeline-verification
instruction: Create complete E2E tests for MySQL data pipeline — accounts, uploads, import, execute, verify
codebase_path: /path/to/rf-project

Think step by step before generating any files:
1. First, read the full codebase structure to understand all existing patterns
2. Identify: which accounts are needed, which pipelines to import, what tasks to create
3. Check existing E2E tests (oracle.robot, mysql.robot, etc.) as reference patterns
4. Plan the test execution order: accounts → uploads → import → tasks → verify
5. Generate a single .robot file with all steps in the correct order
6. Include proper Suite Setup, Variables, Test Cases, and Keywords sections

## Report Format: Unified (Summary + Technical Details)
...
```

---

## All CLI flag combinations — how each affects the prompt

### Basic — just instruction + codebase

```bash
rf-forge create-account "Create Oracle account" --codebase-path /path
```

| Component | Value |
|---|---|
| System prompt Layer ② | `qa-testing.md` only |
| User prompt `instruction:` | `Create Oracle account` |
| Agent cwd | `/path` |
| Session log | None |

---

### With `--file` — load instruction from markdown

```bash
rf-forge create-account \
    --file /Users/.../requirements/JIRA-4567.md \
    --codebase-path /path
```

| Component | Value |
|---|---|
| User prompt `instruction:` | Full content of `JIRA-4567.md` (replaces positional text) |

⚠️ Cannot use both `--file` and positional instruction — mutually exclusive.

---

### With `--context-file` — extra knowledge for Claude

```bash
rf-forge create-account "Create Oracle account" \
    --codebase-path /path \
    --context-file /Users/.../company-conventions.md
```

| Component | Value |
|---|---|
| System prompt Layer ② | `qa-testing.md` + `company-conventions.md` (both injected) |

Claude reads your custom conventions alongside the default QA testing knowledge.

---

### With `--output-dir` — save session log

```bash
rf-forge create-account "Create Oracle account" \
    --codebase-path /path \
    --output-dir ./session-logs/oracle
```

| Component | Value |
|---|---|
| `./session-logs/oracle/SESSION_SUMMARY.md` | What was done, cost, duration |
| `./session-logs/oracle/session.jsonl` | Full audit trail (auto-created) |

Prompt is unchanged — `--output-dir` only affects post-run artifact saving.

---

### With `--model` — change Claude model

```bash
rf-forge create-account "Create Oracle account" \
    --codebase-path /path \
    --model opus
```

| Model | Quality | Cost | When to use |
|---|---|---|---|
| `haiku` | Good | Cheapest | Quick experiments |
| `sonnet` (default) | Very good | Medium | Daily use |
| `opus` | Best | Most expensive | Complex E2E suites, demos |

Prompt text is unchanged — model selection is a `ClaudeGenAgent` config, not a prompt field.

---

### With `--max-budget` — hard dollar cap

```bash
rf-forge create-account "Create Oracle account" \
    --codebase-path /path \
    --max-budget 0.50
```

Claude stops if the session cost exceeds $0.50. Prompt is unchanged.

---

### With `--json-log` — explicit JSONL audit path

```bash
rf-forge create-account "Create Oracle account" \
    --codebase-path /path \
    --json-log /tmp/oracle-session.jsonl
```

Every tool call, response, and cost is logged to the JSONL file. Prompt is unchanged.

---

### Kitchen sink — all flags combined

```bash
rf-forge end-to-end-pipeline-verification \
    --file ./requirements/mysql-e2e.md \
    --codebase-path "/path/to/rf-project" \
    --context-file ./docs/company-test-standards.md \
    --model opus \
    --max-budget 2.0 \
    --output-dir ./session-logs/mysql-e2e \
    --json-log ./session-logs/mysql-e2e/detailed.jsonl
```

| Component | Source | Value |
|---|---|---|
| System ① | Preset | `claude_code` (always) |
| System ② | `--context-file` + default | `qa-testing.md` + `company-test-standards.md` |
| System ③ | Auto-matched from plugins | `end-to-end-pipeline-verification/SKILL.md` |
| User ④ instruction | `--file` | Content of `mysql-e2e.md` |
| User ④ codebase_path | `--codebase-path` | `/path/to/rf-project` |
| User ⑤ | `cot_instructions` | 6-step reasoning chain |
| User ⑥ | `report_mode.py` | 2-part format template |
| Agent model | `--model` | `opus` |
| Agent budget cap | `--max-budget` | $2.00 |
| Session log | `--output-dir` | `./session-logs/mysql-e2e/SESSION_SUMMARY.md` |
| Audit log | `--json-log` | `./session-logs/mysql-e2e/detailed.jsonl` |

---

## Why split into 2 slots?

### Reason 1 — Scope

| System prompt | User prompt |
|---|---|
| Rules that apply to EVERY message | Just this one request |
| "You know how to create account files. The 4 required files are..." | "Now create Oracle and Snowflake accounts." |

### Reason 2 — Caching

Anthropic's API **caches the system prompt** across requests. If you run RFForge 10 times, the long system prompt (with qa-testing.md and SKILL.md) is cached — cheaper and faster. The user prompt changes each time, so it's NOT cached.

### Reason 3 — Priority

When instructions conflict, the system prompt wins. If SKILL.md says "always create 4 files" and the user asks "just create the .robot file," Claude follows the SKILL.md and creates all 4.

---

## What happens across multiple turns?

Claude's conversation can have many turns (tool_use → tool_result → text → tool_use → ...). Through all of them:

| Element | Behavior across turns |
|---|---|
| **System prompt** | Stays **exactly the same** for every turn |
| **User prompt** (initial task) | Stays in the conversation history |
| **Assistant responses** | All appended to history |
| **Tool results** | Appended to history as user messages |

The system prompt is like a constant — always present. The conversation grows turn by turn, but the system prompt never changes during a single skill run.

---

## Summary table

| Question | Answer |
|---|---|
| What is a system prompt? | Persistent instructions Claude reads every turn |
| What is a user prompt? | The specific task for this request |
| What's in RFForge's system prompt? | `claude_code` preset + `qa-testing.md` + `SKILL.md` body (with Few-Shot examples) |
| What's in RFForge's user prompt? | Skill command + args + CoT instructions + report format |
| What is Chain-of-Thought (CoT)? | Step-by-step reasoning instructions appended to the user prompt — makes output more stable |
| Where is CoT defined? | `cot_instructions` field in each `SkillDef` in `skills.py` |
| Where are Few-Shot examples? | Inside each `SKILL.md` file (system prompt, Layer 3) |
| What is a preset? | Anthropic's pre-written, maintained system prompt |
| Which preset does RFForge use? | `claude_code` |
| Does system prompt change during multi-turn? | No — stays static |
| How many SKILL.md files are active per run? | ONE — matched by slash command name |
| What flags affect the prompt text? | `instruction`, `--file`, `--codebase-path`, `--context-file` |
| What flags affect the agent but NOT the prompt? | `--model`, `--max-budget`, `--output-dir`, `--json-log`, `--raw-json` |

---

## Bottom line

> Every Claude request has **two prompt slots** — system (persistent identity + rules) and user (specific task). They're kept separate in the API, but Claude reads both before replying.
>
> In RFForge: the **system prompt combines 3 layers** (claude_code preset + qa-testing.md + SKILL.md with Few-Shot examples) into Claude's "identity and context." The **user prompt combines 3 layers** (skill command + args, Chain-of-Thought instructions, and report format template) into "today's specific task."
>
> A **preset** is Anthropic's pre-written, battle-tested system prompt. Using `{"type": "preset", "preset": "claude_code"}` saves you from writing thousands of lines of rules yourself. Your custom instructions (SKILL.md, qa-testing.md) layer on top of the preset — they don't replace it.
>
> **Chain-of-Thought (CoT)** makes output stable and predictable — each skill has explicit step-by-step reasoning instructions that make Claude check existing files before creating new ones.
>
> **6 of 8 standard prompting patterns** are used: Basic Prompting, System vs User, Prompt Templates, Few-Shot (in SKILL.md), Chain-of-Thought (in cot_instructions), and Structured Output (in report_mode.py). Multi-Turn is handled by the library. RAG is not needed for 8 skills.
>
> All 8 skills share the same prompt structure — only the slash command name, CoT steps, and SKILL.md content differ. All CLI flags (`--file`, `--context-file`, `--model`, `--max-budget`, `--output-dir`) layer on top of this base structure without changing the pattern.

---

## Using via Makefile (recommended for this repo)

Instead of calling `rf-forge` directly, use the Makefile targets. They set `--codebase-path` automatically and pass optional flags through.

### Makefile targets → CLI → prompt mapping

```
make rf-create-account INSTRUCTION="Create Oracle account" MODEL=opus
                │                        │                      │
                ▼                        ▼                      ▼
rf-forge create-account "Create Oracle account" --codebase-path $(pwd) --model opus
                │                        │                                │
                ▼                        ▼                                ▼
         ④ /create-account    ④ instruction: Create Oracle account    Agent config
         ⑤ CoT instructions
         ⑥ Report format
```

### All Makefile targets

| Target | Skill | Example |
|---|---|---|
| `rf-create-account` | create-account | `make rf-create-account INSTRUCTION="Create Oracle account"` |
| `rf-import-pipeline` | import-pipeline | `make rf-import-pipeline INSTRUCTION="Import MySQL pipeline"` |
| `rf-upload-file` | upload-file | `make rf-upload-file INSTRUCTION="Upload MySQL JAR"` |
| `rf-create-task` | create-triggered-task | `make rf-create-task INSTRUCTION="Create MySQL task"` |
| `rf-compare-csv` | compare-csv | `make rf-compare-csv INSTRUCTION="Compare Oracle output"` |
| `rf-verify-db` | verify-data-in-db | `make rf-verify-db INSTRUCTION="Verify employee data"` |
| `rf-export-csv` | export-data-to-csv | `make rf-export-csv INSTRUCTION="Export Oracle table"` |
| `rf-e2e` | end-to-end-pipeline-verification | `make rf-e2e INSTRUCTION="MySQL E2E tests"` |

### Makefile optional flags → CLI flags → prompt mapping

| Makefile flag | CLI flag | Affects |
|---|---|---|
| `INSTRUCTION="..."` | positional arg | User prompt ④ `instruction:` |
| `FILE=./req.md` | `--file` | User prompt ④ `instruction:` (from file) |
| `CONTEXT_FILE=./docs/x.md` | `--context-file` | System prompt ② (extra context) |
| `MODEL=opus` | `--model` | Agent config (not in prompt text) |
| `MAX_BUDGET=2.0` | `--max-budget` | Agent config (not in prompt text) |
| `OUTPUT_DIR=./logs` | `--output-dir` | Post-run (SESSION_SUMMARY.md saved here) |

### Examples with all flags

```bash
# Simple
make rf-create-account INSTRUCTION="Create Oracle account"

# With model + budget
make rf-e2e INSTRUCTION="MySQL E2E" MODEL=opus MAX_BUDGET=3.0

# From requirement file
make rf-create-account FILE=./requirements/JIRA-4567.md

# With extra context + session log
make rf-verify-db INSTRUCTION="Verify data" CONTEXT_FILE=./docs/standards.md OUTPUT_DIR=./ai-logs

# Show all targets
make rf-help
```

### Where SKILL.md files live in this repo

```
{{cookiecutter.primary_pipeline_name}}/
├── .claude/skills/                    ← SKILL.md source of truth
│   ├── create-account/SKILL.md        │
│   ├── import-pipeline/SKILL.md       │  runner.py finds these
│   ├── upload-file/SKILL.md           │  automatically — no symlink
│   └── ... (8 skills)                 │  needed
│
└── ai/
    ├── src/rf_forge/runner.py         ← walks up to find .claude/skills/
    └── docs/PROMPTS_EXPLAINED.md      ← this file
```

No duplication. The SKILL.md files in `.claude/skills/` are the same ones used by both Claude Code (slash commands) and RF Forge (AI test generation). Edit them once, both tools pick up the changes.
