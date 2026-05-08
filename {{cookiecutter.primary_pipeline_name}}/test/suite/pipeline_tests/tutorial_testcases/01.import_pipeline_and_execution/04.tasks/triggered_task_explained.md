# Creating a Triggered Task — Two Ways

> **What is a triggered task?**
> A SnapLogic asset that wraps a pipeline so it can be executed on demand —
> via an HTTP URL, a scheduler, or another test step. Think of it as the
> "Run" button for a pipeline, plus the configuration around it (which
> Snaplex to run on, parameters, notifications, timeouts).

> 📚 **Concept to understand before reading this tutorial**
> Robot Framework supports **positional** and **named** arguments. Several rows
> in this tutorial mix the two styles to demonstrate which optional arguments
> can be skipped and how. If those terms are new, skim the section
> [*"Are these arguments positional or named?"*](#are-these-arguments-positional-or-named)
> below first — it explains the rules in 60 seconds.

> ⚠ **Prerequisites — do these first**
> Before creating a triggered task:
> 1. **The pipeline must already exist** in the project space — imported via
>    one of the keywords described in `../03.pipelines/import_pipeline_explained.md`.
> 2. **The Groundplex must be running and registered** to the project space —
>    the task needs a Snaplex to execute on.
> 3. **`${unique_id}` must be set** as a suite variable (Suite Setup).
>
> If you skip step 1 the task creation fails with `pipeline_snode_id is None`.

---

## The two task-creation keywords

The framework gives you two choices, both imported from the `snaplogic-common-robot` pip package:

```
┌────────────────────────────────────────────┐         ┌────────────────────────────────────────────┐
│  Create Triggered Task From Template       │   VS    │  Create Triggered Task For Original        │
│  Pairs with:                                │         │  Pipeline Name                              │
│   Import Pipelines From Template            │         │  Pairs with:                                │
│  Looks up:                                  │         │   Import Pipeline With Original Name        │
│   ${pipeline_name}_${unique_id}_snode_id    │         │  Looks up:                                  │
│                                             │         │   ${pipeline_name}_snode_id                 │
└────────────────────────────────────────────┘         └────────────────────────────────────────────┘
```

Both create the same kind of triggered task and take the **same 8 arguments**.
The **only difference** is which suite variable they read to find the
pipeline's `snode_id`.

---

## When to use which

```
                  ┌──────────────────────────────────────┐
                  │  How was the pipeline imported?      │
                  └──────────────────────────────────────┘
                                   │
              ┌────────────────────┴────────────────────┐
              │                                         │
              ▼                                         ▼
   With "Import Pipelines                    With "Import Pipeline
   From Template"                            With Original Name"
   (name has _<unique_id>                    (name is exact, no suffix)
    suffix in SnapLogic)                          │
              │                                   │
              ▼                                   ▼
   ┌─────────────────────────────┐    ┌──────────────────────────────────┐
   │ Create Triggered Task From  │    │ Create Triggered Task For        │
   │ Template                    │    │ Original Pipeline Name           │
   └─────────────────────────────┘    └──────────────────────────────────┘
```

| Scenario                                                           | Pick                                               |
| ------------------------------------------------------------------ | -------------------------------------------------- |
| You used `Import Pipelines From Template`                          | `Create Triggered Task From Template`              |
| You used `Import Pipeline With Original Name`                      | `Create Triggered Task For Original Pipeline Name` |
| Mixed — you imported child as original-name and parent with suffix | Use the matching task keyword for each             |

> 💡 **Mental model:** the import keyword sets a suite variable; the task keyword reads it. They have to match.

---

## The 8 arguments (same for both keywords)

```robot
[Arguments]
...    ${unique_id}                                   # required
...    ${project_path}                                # required
...    ${pipeline_name}                               # required
...    ${task_name}                                   # required
...    ${plex_name}=${groundplex_name}                # optional
...    ${pipeline_params}=${None}                     # optional
...    ${notification}=${None}                        # optional
...    ${execution_timeout}=${None}                   # optional
```

| #   | Argument            | Required | Default              | Purpose                                                                                                                              |
| --- | ------------------- | -------- | -------------------- | ------------------------------------------------------------------------------------------------------------------------------------ |
| 1   | `unique_id`         | ✅        | —                    | Suffix appended to the **task name** (always — even with the "Original Name" keyword). Generated once per suite via `Get Unique Id`. |
| 2   | `project_path`      | ✅        | —                    | Where the task lands. Usually `${PIPELINES_LOCATION_PATH}`.                                                                          |
| 3   | `pipeline_name`     | ✅        | —                    | Used to (a) build the task name and (b) look up the pipeline's `snode_id`.                                                           |
| 4   | `task_name`         | ✅        | —                    | Middle part of the resulting task name. Becomes `<pipeline_name>_<task_name>_<unique_id>` in SnapLogic.                              |
| 5   | `plex_name`         | ❌        | `${groundplex_name}` | Which Snaplex executes the task. Defaults to the global Groundplex from `.env`.                                                      |
| 6   | `pipeline_params`   | ❌        | `${None}`            | Dictionary of pipeline parameters (`&{...}`). Passed at task-creation time, can be overridden at execution time.                     |
| 7   | `notification`      | ❌        | `${None}`            | Dictionary describing notification config (e.g. emails on Completed / Failed states).                                                |
| 8   | `execution_timeout` | ❌        | `${None}`            | Maximum task execution time in seconds. `None` means no timeout.                                                                     |

---

## Are these arguments positional or named?

**All of them are *positional-or-named*** — Robot Framework lets you supply each one either by its slot in the row or by `name=value`. None of them are "named-only".

### Quick reference

| #   | Argument            | Positional? | Named (`name=value`)? |            Required?             |
| --- | ------------------- | :---------: | :-------------------: | :------------------------------: |
| 1   | `unique_id`         |      ✅      |           ✅           |                ✅                 |
| 2   | `project_path`      |      ✅      |           ✅           |                ✅                 |
| 3   | `pipeline_name`     |      ✅      |           ✅           |                ✅                 |
| 4   | `task_name`         |      ✅      |           ✅           |                ✅                 |
| 5   | `plex_name`         |      ✅      |           ✅           | ❌ (default `${groundplex_name}`) |
| 6   | `pipeline_params`   |      ✅      |           ✅           |      ❌ (default `${None}`)       |
| 7   | `notification`      |      ✅      |           ✅           |      ❌ (default `${None}`)       |
| 8   | `execution_timeout` |      ✅      |           ✅           |      ❌ (default `${None}`)       |

> 💡 The "required" column only affects whether you can **omit** the arg — not **how** you pass it. Even required args can be supplied by name (e.g. `pipeline_name=oracle`).

Robot has three argument categories:

| Category                 | Marker in `[Arguments]`        | Required? | Caller can pass...           |
| ------------------------ | ------------------------------ | --------- | ---------------------------- |
| **Positional, required** | `${name}`                      | ✅ Yes     | Position only                |
| **Positional-or-named**  | `${name}=default`              | ❌ No      | Position **or** `name=value` |
| **Named-only**           | `${name}` after a `@{varargs}` | ❌ No      | `name=value` only            |

Looking at the keyword's signature, **none** of the arguments come after a `@{varargs}` — so all 8 are accessible positionally. The four with `=default` (`plex_name`, `pipeline_params`, `notification`, `execution_timeout`) can also be passed by name.

### Three rules for skipping arguments

1. **Trailing optionals** can always be omitted — they take their default.
2. **Middle optionals** can only be skipped if the next one you DO pass is given as `name=value`.
3. **Required positional args** must always come first, in order.

### What happens when you omit `plex_name`?

A common case worth calling out: when you skip `plex_name`, Robot **does not raise an error**. It evaluates the default `${groundplex_name}` — a global variable Robot loads from your `.env` files (case-insensitive, so it matches `GROUNDPLEX_NAME`).

Example — Case 6 below skips `plex_name` and `pipeline_params`:

```robot
${unique_id}    ${path}    ${pl}    ${tn}    notification=${task_notifications}
```

Resolves to:

| Slot                | Value                                          |
| ------------------- | ---------------------------------------------- |
| `plex_name`         | **default → `${groundplex_name}`** ← from .env |
| `pipeline_params`   | default → `${None}`                            |
| `notification`      | `${task_notifications}` (named)                |
| `execution_timeout` | default → `${None}`                            |

So the task still runs on the same Groundplex you'd get by passing it positionally — you just didn't have to type it.

> ⚠ **Edge case:** if `GROUNDPLEX_NAME` is missing or empty in `.env`, the default resolves to empty string and the API call fails with "plex not found". If you want a non-default plex for one specific row, pass it explicitly (positionally or as `plex_name=<value>`).

---


> 💡 **Rule of thumb:** as soon as you want to skip an optional argument that's not at the very end, switch to `name=value` syntax for the args after it.

The `triggered_task.robot` test case [`Create Triggered Task For Pipeline`](./triggered_task.robot) demonstrates all 9 patterns as 9 separate rows — useful for scanning visually during a demo.

---

## Resulting task name

**Both** keywords build the task name the same way:

```
<pipeline_name>_<task_name>_<unique_id>
```

For example, with `pipeline_name = oracle`, `task_name = MyTask`, `unique_id = abc123`:

```
oracle_MyTask_abc123
```

The task name **always** has the unique suffix — it's the only thing keeping concurrent test runs from colliding on task names.

### `unique_id` is appended ONLY to the task — never to the pipeline

This is a common point of confusion, especially with `Create Triggered Task For Original Pipeline Name`. The `unique_id` argument is used **twice**:

1. To **build the task name** → appended as a suffix
2. To **look up the pipeline** (in `Create Triggered Task From Template` only) → appended as a suffix to the variable name

It is **never** appended to the actual pipeline name in SnapLogic. So with `Create Triggered Task For Original Pipeline Name`:

| Asset in SnapLogic | Has `_<unique_id>` suffix?                      |
| ------------------ | ----------------------------------------------- |
| Pipeline           | ❌ No — used the bare name as imported           |
| Triggered task     | ✅ Yes — name is `<pipeline>_<task>_<unique_id>` |

Concrete example with `pipeline_name = oracle_child`, `task_name = MyTask`, `unique_id = abc123`:

| Step                        | Built / Looked up                                           | Resolved value                            |
| --------------------------- | ----------------------------------------------------------- | ----------------------------------------- |
| Build full task name        | `<pl>_<task>_<uid>`                                         | `oracle_child_MyTask_abc123`              |
| Look up pipeline `snode_id` | `${oracle_child_snode_id}`                                  | (no suffix in the variable name)          |
| Final result in SnapLogic   | Pipeline `oracle_child` + task `oracle_child_MyTask_abc123` | The task points at the bare-name pipeline |

This is by design — the test framework wants tasks to be unique per run (so parallel runs don't fight) but still attached to a "well-known" pipeline that other things can reference by exact name.

---

## The KEY difference — how the pipeline `snode_id` is looked up

This is the single line that differs between the two keywords:

| Keyword                                            | Lookup variable                             |
| -------------------------------------------------- | ------------------------------------------- |
| `Create Triggered Task From Template`              | `${${pipeline_name}_${unique_id}_snode_id}` |
| `Create Triggered Task For Original Pipeline Name` | `${${pipeline_name}_snode_id}`              |

The variable is **set** by the matching `Import` keyword:

| Import keyword                       | Sets variable               | Read by task keyword                               |
| ------------------------------------ | --------------------------- | -------------------------------------------------- |
| `Import Pipelines From Template`     | `${oracle_abc123_snode_id}` | `Create Triggered Task From Template`              |
| `Import Pipeline With Original Name` | `${oracle_snode_id}`        | `Create Triggered Task For Original Pipeline Name` |

If you mix-and-match the wrong pair, the lookup returns `None` and the task creation fails with the friendly-but-confusing error you saw earlier:

```
Expecting type of asset [None] to be Pipeline but was Org
```

---

## Suite variables created (both keywords)

After successful task creation, two suite variables are set, keyed by the **full task name** (`<pipeline_name>_<task_name>_<unique_id>`):

```
${<full_task_name>_payload}    = <task API response JSON>
${<full_task_name>_snodeid}    = <task snode ID>
```

These are used by the downstream `Run Triggered Task With Parameters From Template` keyword in execution test cases.

---

## Example calls

### `Create Triggered Task From Template`

```robot
*** Test Cases ***
Create Triggered Task For Pipeline
    [Tags]    baseline    task    pipeline
    [Template]    Create Triggered Task From Template
    ${unique_id}    ${PIPELINES_LOCATION_PATH}    ${pipeline_name}    ${task1}    ${GROUNDPLEX_NAME}    ${task_params_set}    ${task_notifications}
```

8 columns map directly to the 8 arguments. The pipeline at `${pipeline_name}_${unique_id}` (e.g. `oracle_abc123`) must already exist.

### `Create Triggered Task For Original Pipeline Name`

```robot
*** Test Cases ***
Create Triggered Task For Pipelines WithOut UniqueID Appended
    [Tags]    oracle_2    baseline    task    pipeline    no_suffix
    [Template]    Create Triggered Task For Original Pipeline Name
    ${unique_id}    ${PIPELINES_LOCATION_PATH}    ${pipeline_name}    ${task1}    ${GROUNDPLEX_NAME}    ${task_params_set}    ${task_notifications}
```

Same 8 columns. The pipeline at `${pipeline_name}` (e.g. `oracle`, no suffix) must already exist.

---

## Side-by-side comparison

| Aspect                    | `Create Triggered Task From Template` | `Create Triggered Task For Original Pipeline Name`                   |
| ------------------------- | ------------------------------------- | -------------------------------------------------------------------- |
| Argument count            | 8 (4 required + 4 optional)           | 8 (4 required + 4 optional)                                          |
| Task name format          | `<pipeline>_<task>_<unique_id>`       | `<pipeline>_<task>_<unique_id>`                                      |
| Pipeline lookup variable  | `${<pipeline>_<unique_id>_snode_id}`  | `${<pipeline>_snode_id}`                                             |
| Pairs with import keyword | `Import Pipelines From Template`      | `Import Pipeline With Original Name`                                 |
| Best for                  | Most use cases (parallel/CI runs)     | Pipelines with fixed names (referenced by tasks/pipelines elsewhere) |

---

## What both keywords do under the hood

```
        ┌─────────────────────────────────────────────────────────┐
        │ Build full task name:                                   │
        │   <pipeline_name>_<task_name>_<unique_id>               │
        └────────────────────────┬────────────────────────────────┘
                                 ▼
                  ┌──────────────────────────┐
                  │     Which keyword?       │
                  └──────────────────────────┘
                    │                       │
   From Template    │                       │   For Original Pipeline Name
                    ▼                       ▼
   ┌─────────────────────────────┐    ┌─────────────────────────────┐
   │ Look up pipeline_snode_id   │    │ Look up pipeline_snode_id   │
   │ from suite var:             │    │ from suite var:             │
   │   ${<pipeline>_<uid>        │    │   ${<pipeline>_snode_id}    │
   │     _snode_id}              │    │                             │
   └────────────┬────────────────┘    └────────────┬────────────────┘
                │                                  │
                └──────────────────┬───────────────┘
                                   ▼
                ┌────────────────────────────────────┐
                │ Call low-level Create Triggered    │
                │ Task keyword with:                 │
                │  - full_task_name                  │
                │  - pipeline_snode_id               │
                │  - plex_name                       │
                │  - project_path                    │
                │  - pipeline_params                 │
                │  - notification                    │
                │  - execution_timeout               │
                └────────────────┬───────────────────┘
                                 ▼
                ┌────────────────────────────────────┐
                │ POST to SnapLogic Task API         │
                └────────────────┬───────────────────┘
                                 ▼
                ┌────────────────────────────────────┐
                │ Set suite variables:               │
                │  ${<full_task_name>_payload}       │
                │  ${<full_task_name>_snodeid}       │
                └────────────────┬───────────────────┘
                                 ▼
                          ┌─────────────┐
                          │   ✅ Done   │
                          └─────────────┘
```

---

## Optional arguments — when do you need them?

### `pipeline_params` — pass values into the pipeline at task creation

If your pipeline has parameters (e.g. `oracle_acct`, `target_table`), you can wire them up at task creation time so the task always passes them:

```robot
*** Variables ***
&{task_params_set}
...    oracle_acct=../shared/${oracle_acct_name}
...    target_table=DEMO.TEST_TABLE1
```

Pass `${task_params_set}` as the 6th argument. The task will run with these values unless overridden at execution time.

### `notification` — send emails on completion / failure

```robot
*** Variables ***
@{notification_states}    Completed    Failed
&{task_notifications}
...    recipients=test@example.com
...    states=${notification_states}
```

Pass `${task_notifications}` as the 7th argument. SnapLogic will email on the listed states.

### `execution_timeout` — cap how long the task can run

```robot
${task_timeout}    300       # 5 minutes
```

Pass `${task_timeout}` as the 8th argument. If the pipeline doesn't finish in time, the task is killed and reports a Failed state.

> 💡 If you don't need any of the optional ones, omit the trailing arguments — Robot will use the defaults.

---

## Executing the task — `Run Triggered Task With Parameters From Template`

After creating a task with one of the two `Create Triggered Task ...` keywords, the next step is to actually **run** it. The framework provides one keyword for that:

```robot
Run Triggered Task With Parameters From Template
```

It does three things in order:
1. Looks up the task payload + `snode_id` from suite variables (set by the create-task keyword).
2. **Merges** any new `key=value` pairs you pass into the pipeline's parameters.
3. Calls the SnapLogic API to **update** the task definition, then **triggers** execution.

### Signature

```robot
[Arguments]
...    ${unique_id}
...    ${project_path}
...    ${pipeline_name}
...    ${task_name}
...    &{new_parameters}
```

### Arguments

| # | Argument | Type | Required | Purpose |
|---|----------|------|----------|---------|
| 1 | `unique_id` | scalar | ✅ | Same `unique_id` that was used to create the task — used to find the suite variables. |
| 2 | `project_path` | scalar | ✅ | Where the task lives. Usually `${PIPELINES_LOCATION_PATH}`. |
| 3 | `pipeline_name` | scalar | ✅ | Pipeline name (used to reconstruct the full task name). |
| 4 | `task_name` | scalar | ✅ | Task name prefix (used to reconstruct the full task name). |
| 5 | `&{new_parameters}` | **kwargs collector** | ❌ | Any number of `key=value` pairs. Each pair is treated as a pipeline-parameter override merged into the existing parameters. Pass none and the task runs with whatever parameters were set at creation time. |

### What's special about `&{new_parameters}`

This is a **kwargs collector** (the `&{...}` syntax). Anything you pass after `${task_name}` as `key=value` is collected into a dictionary called `new_parameters`. It's not a single argument — it's a "catch all the extra named args" bucket.

So all of these are valid:

```robot
# No overrides — task runs with parameters set at creation time
${unique_id}    ${path}    ${pipeline_name}    ${task_name}

# Override a single parameter
${unique_id}    ${path}    ${pipeline_name}    ${task_name}    input_file=data.csv

# Override multiple parameters
${unique_id}    ${path}    ${pipeline_name}    ${task_name}    env=prod    debug=${FALSE}    target_table=DEMO.OUT
```

The keyword then **merges** these into the task's existing `pipeline_parameters` (set when the task was created):

```
existing pipeline_parameters     new_parameters             merged result
─────────────────────────        ────────────────           ─────────────
{                                {                          {
  oracle_acct: "shared/A"          input_file: "data.csv"     oracle_acct: "shared/A",
}                                }                            input_file: "data.csv"
                                                            }
```

Existing keys are preserved; new keys are added; matching keys are overwritten by the new value.

### Required suite variables (set by the create-task keyword)

The keyword reads these two suite variables to find the task it should run. They're set automatically by `Create Triggered Task From Template` (or the "Original Pipeline Name" variant) when the task was created:

```
${<pipeline_name>_<task_name>_<unique_id>_payload}    ← the full task JSON
${<pipeline_name>_<task_name>_<unique_id>_snodeid}    ← the task's snode ID
```

The full task name is reconstructed inside the keyword as:

```
<pipeline_name>_<task_name>_<unique_id>
```

> ⚠ The same `${unique_id}`, `${pipeline_name}`, and `${task_name}` you passed to the create-task keyword **must** be passed here too — otherwise the lookup fails and the task can't be found.

### Returns

A tuple of two values:

| Position | Value | Use it for |
|----------|-------|------------|
| 1 | Updated task payload (dict) | Inspecting the final task config; logging |
| 2 | Job ID (string) | Polling execution status; correlating logs |

Most tests don't capture the return — they let the framework log it and assert the run succeeded by checking the database afterwards.

### Example call (from `02.execute_trigger_task.robot`)

```robot
Execute Triggered Task With Parameters
    [Tags]    execute_triggered_task_sample
    [Template]    Run Triggered Task With Parameters From Template
    ${unique_id}    ${PIPELINES_LOCATION_PATH}    ${pipeline_name}    ${task1}
```

No parameter overrides — the task runs with the parameters it was created with.

### Example with parameter overrides

```robot
Execute Triggered Task With Overrides
    [Tags]    execute_triggered_task_sample
    [Template]    Run Triggered Task With Parameters From Template
    # required args                                                          # &{new_parameters} collector
    ${unique_id}    ${PIPELINES_LOCATION_PATH}    ${pipeline_name}    ${task1}    input_file=monthly.csv    env=stage
```

`input_file` and `env` are merged into the task's existing pipeline_parameters before execution.

### Under the hood

```
   ┌──────────────────────────────────────────────────────────┐
   │ Reconstruct full_task_name:                              │
   │   <pipeline_name>_<task_name>_<unique_id>                │
   └────────────────────────┬─────────────────────────────────┘
                            ▼
   ┌──────────────────────────────────────────────────────────┐
   │ Read suite variables set by Create Triggered Task:       │
   │   ${<full_task_name>_payload}                            │
   │   ${<full_task_name>_snodeid}                            │
   └────────────────────────┬─────────────────────────────────┘
                            ▼
   ┌──────────────────────────────────────────────────────────┐
   │ Extract pipeline_parameters from payload                 │
   │ Merge &{new_parameters} into it (overrides win)          │
   └────────────────────────┬─────────────────────────────────┘
                            ▼
   ┌──────────────────────────────────────────────────────────┐
   │ Update Task API with the merged payload                  │
   └────────────────────────┬─────────────────────────────────┘
                            ▼
   ┌──────────────────────────────────────────────────────────┐
   │ Trigger task execution → returns job_id                  │
   └────────────────────────┬─────────────────────────────────┘
                            ▼
                   ┌──────────────────┐
                   │ ✅ Returns:       │
                   │   payload, jobId │
                   └──────────────────┘
```

---

## Common pitfalls

| Symptom                                                   | Cause                                                          | Fix                                                                      |
| --------------------------------------------------------- | -------------------------------------------------------------- | ------------------------------------------------------------------------ |
| `pipeline_snode_id is None`                               | Wrong task keyword for the import keyword used                 | Match the pair (see "When to use which")                                 |
| `Asset [None] to be Pipeline but was Org`                 | Same as above — task creation got `null` for the pipeline      | Match the import / task keyword pair                                     |
| `Variable '${unique_id}' not found`                       | Suite Setup didn't run `Initialize Variables`                  | Add `Suite Setup    Initialize Variables` to `*** Settings ***`          |
| Task created but execution fails with "Snaplex not found" | `plex_name` is wrong or Groundplex isn't registered            | Check `${GROUNDPLEX_NAME}` in `.env` and run `make groundplex-status`    |
| Notifications not sent                                    | `recipients` empty or `states` list missing                    | Build the `&{notification}` dict with both keys                          |
| `${oracle_MyTask_abc123_snodeid}` undefined later         | Task creation failed silently OR using a different `unique_id` | Check the suite log; confirm `unique_id` is the same suite-wide variable |
| `Run Triggered Task With Parameters From Template` fails with "task not found" | Mismatched `unique_id` / `pipeline_name` / `task_name` between create and execute keywords | All four args must be identical to the ones used during create — they reconstruct the suite-variable key |
| Pipeline-parameter override doesn't take effect | Passed it positionally instead of as `key=value` | The `&{new_parameters}` collector ONLY accepts named pairs — anything positional after the 4th arg is ignored |

---

## Usage example

Run this test case:

```bash
make robot-run-tests-no-gp TAGS="tag_name"     # eg: TAGS="baseline"
```

What happens:

1. Robot loads `.env` and `env_files/...`
2. Suite Setup → `Initialize Variables` generates `${unique_id}`
3. The pipeline must already be imported (run `Import Pipeline` test before this one)
4. Task-creation keyword:
   - Builds `full_task_name = <pipeline>_<task>_<unique_id>`
   - Looks up pipeline `snode_id` from the appropriate suite variable
   - Calls SnapLogic API to create the task
5. Suite variables `${<full_task_name>_payload}` and `${<full_task_name>_snodeid}` are set
6. ✅ The task appears in the SnapLogic UI under the project space → Manager tab

To run against a different environment (e.g. stage):

```bash
make robot-run-tests-no-gp TAGS="tag_name" ENV=.env.stage     # eg: TAGS="baseline"
```

---

## TL;DR cheat sheet

- Two keywords, **same 8 arguments**, only the pipeline-lookup variable differs.
- Use **`Create Triggered Task From Template`** when you imported with `Import Pipelines From Template` (suffixed name).
- Use **`Create Triggered Task For Original Pipeline Name`** when you imported with `Import Pipeline With Original Name` (bare name).
- The **task name always includes `_<unique_id>`** — only the pipeline lookup differs.
- Pipeline must exist before task creation (run import test first).
- Optional args (`plex_name`, `pipeline_params`, `notification`, `execution_timeout`) can be omitted; sensible defaults apply.
- Suite variables `${<task>_payload}` and `${<task>_snodeid}` are set automatically for downstream test cases.
- **To execute** the task, use `Run Triggered Task With Parameters From Template` — same first 4 args as create, plus optional `key=value` pairs to override pipeline parameters at run time.

---

*Companion to [`triggered_task.robot`](./triggered_task.robot).*
