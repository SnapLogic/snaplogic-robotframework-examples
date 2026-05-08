# Importing a SnapLogic Pipeline — Two Ways

> **What is "importing" a pipeline?**
> Uploading a `.slp` file into your SnapLogic project space so that tests
> (and the SnapLogic UI) can see it as a registered asset.

> ⚠ **Prerequisites — do these first**
> Before importing a pipeline, make sure:
> 1. **Accounts are created** — every account the pipeline references (databases, S3, Kafka, etc.) must already exist in the project space. See [`../accounts/create_account_explained.md`](../accounts/create_account_explained.md).
> 2. **Required files are uploaded to SLDB** — any expression libraries (`.expr`), JDBC JARs, or other supporting files referenced by the pipeline must already be in SLDB. See [`../upload_files/upload_files.robot`](../upload_files/upload_files.robot).
>
> If you skip either step, the pipeline will import successfully but **will fail at execution time** with "asset not found" errors that look like infrastructure problems but are really setup-order problems.

---

## The two import keywords

The framework gives you two choices, both imported from the `snaplogic-common-robot` pip package:

```
┌────────────────────────────────────────┐         ┌─────────────────────────────────────────┐
│  Import Pipelines From Template        │   VS    │  Import Pipeline With Original Name     │
│  Appends `_<unique_id>` to the name    │         │  Uses the EXACT name you give           │
└────────────────────────────────────────┘         └─────────────────────────────────────────┘
```

Both upload the same `.slp` file — they differ in **what name the pipeline ends up with in SnapLogic**.

---

## When to use which

```
                  ┌──────────────────────────────────────┐
                  │  Will another asset reference this   │
                  │       pipeline by name?              │
                  └──────────────────────────────────────┘
                                  │
        ┌─────────────────────────┼─────────────────────────┐
        │ YES                     │ NO                      │ Parallel CI
        │ (triggered task,        │ (just running           │ runs on the
        │  another pipeline,      │  tests in isolation)    │ same env
        │  hardcoded path)        │                         │
        ▼                         ▼                         ▼
┌──────────────────┐    ┌──────────────────┐    ┌──────────────────┐
│ Import Pipeline  │    │ Import Pipelines │    │ Import Pipelines │
│ With Original    │    │ From Template    │    │ From Template    │
│ Name             │    │                  │    │                  │
└──────────────────┘    └──────────────────┘    └──────────────────┘
```

| Scenario | Pick |
|---|---|
| Triggered task / another pipeline references it by exact name | `Import Pipeline With Original Name` |
| Multiple test runs on the same SnapLogic org (parallel CI, dev iteration) | `Import Pipelines From Template` |
| Pipeline name appears in a customer doc or external system | `Import Pipeline With Original Name` |
| Demos, tutorials, dev iteration | Either; `From Template` is safer |

---

## `Import Pipelines From Template`

### Signature

```robot
[Arguments]    ${unique_id}    ${project_path}    ${pipeline_name}    ${slp_file_name}    ${duplicate_check}=false
```

### Arguments

| # | Argument | Required | Default | Purpose |
|---|----------|----------|---------|---------|
| 1 | `unique_id` | ✅ | — | Suffix appended to pipeline name. Usually generated once per suite via `Get Unique Id`. |
| 2 | `project_path` | ✅ | — | Where the pipeline lands. Usually `${PIPELINES_LOCATION_PATH}`. |
| 3 | `pipeline_name` | ✅ | — | **Base** name. The keyword appends `_${unique_id}` automatically. |
| 4 | `slp_file_name` | ✅ | — | Filename of the `.slp` (looked up in `src/pipelines/`). |
| 5 | `duplicate_check` | ❌ | `false` | `false` = overwrite, `true` = fail-if-exists. |

### Resulting pipeline name

```
<pipeline_name>_<unique_id>
```

**Example:** `pipeline_name = oracle`, `unique_id = abc123` → SnapLogic shows **`oracle_abc123`**.

### Side effect

A suite variable is set, keyed by the **suffixed** name:

```
${<pipeline_name>_<unique_id>_snode_id} = <pipeline_id>
```

So `${oracle_abc123_snode_id}` is now usable in downstream test cases.

### Example call

```robot
*** Test Cases ***
Import Pipeline
    [Tags]    import_pipeline_sample
    [Template]    Import Pipelines From Template
    ${unique_id}    ${PIPELINES_LOCATION_PATH}    oracle    oracle.slp
```

After the run, SnapLogic shows: `oracle_abc123` (where `abc123` is the suite-wide `unique_id`).

---

## `Import Pipeline With Original Name`

### Signature

```robot
[Arguments]    ${project_path}    ${pipeline_name}    ${slp_file_name}    ${duplicate_check}=false
```

### Arguments

| # | Argument | Required | Default | Purpose |
|---|----------|----------|---------|---------|
| 1 | `project_path` | ✅ | — | Where the pipeline lands. Usually `${PIPELINES_LOCATION_PATH}`. |
| 2 | `pipeline_name` | ✅ | — | **Exact** name. No suffix appended. |
| 3 | `slp_file_name` | ✅ | — | Filename of the `.slp` (looked up in `src/pipelines/`). |
| 4 | `duplicate_check` | ❌ | `false` | `false` = overwrite, `true` = fail-if-exists. |

### Resulting pipeline name

```
<pipeline_name>     (exactly what you typed)
```

### Side effect

```
${<pipeline_name>_snode_id} = <pipeline_id>
```

### Example call

```robot
*** Test Cases ***
Import existing child Pipeline Wihout Unique ID
    [Tags]    import_pipeline_sample
    [Template]    Import Pipeline With Original Name
    ${PIPELINES_LOCATION_PATH}    email    email.slp    duplicate_check=true
```

After the run, SnapLogic shows: `email` (no suffix). If `email` already existed, the test row fails because of `duplicate_check=true`.

---

## The `duplicate_check` flag — the same in both keywords

| Value | Behavior |
|-------|----------|
| `false` *(default)* | **Overwrite.** Replaces existing pipeline content; preserves `snode_id` so triggered tasks keep working. |
| `true` | **Fail-if-exists.** API returns an error; the test row fails. |

> 💡 **Practical:** keep the default (`false`) most of the time. Use `true` only when you need a "don't clobber my colleague's pipeline" guard on a shared org.

---

## Side-by-side comparison

| Aspect | `Import Pipelines From Template` | `Import Pipeline With Original Name` |
|---|---|---|
| Argument count | 5 (4 required + 1 optional) | 4 (3 required + 1 optional) |
| Final pipeline name | `<name>_<unique_id>` | `<name>` |
| Re-run on same env | ✅ Safe (different `unique_id` per run) | ⚠ Will collide → use `duplicate_check=true` to guard |
| Suffix appended | ✅ Yes | ❌ No |
| Suite variable key | `${<name>_<unique_id>_snode_id}` | `${<name>_snode_id}` |
| Best for | Parallel CI, isolated runs | Pipelines referenced by exact name |

---

## What both keywords do under the hood

Both are thin wrappers around the lower-level `Import Pipeline` keyword. The flow is the same — only the name handling differs:

```
        ┌─────────────────────────────────────────────────┐
        │ Read .slp file from                             │
        │ ${PIPELINE_PAYLOAD_PATH}/<filename>             │
        └────────────────────────┬────────────────────────┘
                                 ▼
                  ┌──────────────────────────┐
                  │     Which keyword?       │
                  └──────────────────────────┘
                    │                       │
    From Template   │                       │  With Original Name
                    ▼                       ▼
        ┌────────────────────────┐    ┌────────────────────┐
        │ Suffix:                │    │ Use name as-is     │
        │ name = name +          │    │                    │
        │ "_" + unique_id        │    │                    │
        └───────────┬────────────┘    └─────────┬──────────┘
                    │                           │
                    └───────────┬───────────────┘
                                ▼
                ┌────────────────────────────────┐
                │   Call Import Pipeline API     │
                └────────────────┬───────────────┘
                                 ▼
                    ┌────────────────────────┐
                    │   duplicate_check?     │
                    └────────────────────────┘
                       │                    │
              false    │                    │  true
                       ▼                    ▼
        ┌────────────────────────┐  ┌────────────────────┐
        │ Overwrite if exists    │  │ Fail if exists     │
        └───────────┬────────────┘  └─────────┬──────────┘
                    │                         │
                    └───────────┬─────────────┘
                                ▼
                ┌────────────────────────────────┐
                │ Store snode_id as              │
                │ suite variable                 │
                └────────────────┬───────────────┘
                                 ▼
                          ┌─────────────┐
                          │   ✅ Done   │
                          └─────────────┘
```

---

## Common pitfalls

| Symptom | Cause | Fix |
|---|---|---|
| `Asset already exists` error from the API | `duplicate_check=true` and the pipeline really does exist | Drop the flag (use the default `false`) — or delete it manually first |
| Triggered task can't find pipeline | Used `Import Pipelines From Template`, but the task config references the bare name | Switch to `Import Pipeline With Original Name`, **or** suffix the task name too |
| `${oracle_snode_id}` is undefined in a later test | You imported with the `From Template` keyword but reference the bare name | Reference `${oracle_<unique_id>_snode_id}` instead |
| `.slp` not found | Filename wrong, or the file isn't in `src/pipelines/` | Check `${PIPELINE_PAYLOAD_PATH}` (set in `__init__.robot`) and confirm the file exists there |

---

## Usage example

Run only this test file using its tag:

```bash
make robot-run-tests-no-gp TAGS="tag_name"     # eg: TAGS="import_pipeline_sample"
```

What happens:

1. Robot loads `.env` and `env_files/...`
2. Suite Setup runs in `__init__.robot` → exposes `${PIPELINES_LOCATION_PATH}`, `${PIPELINE_PAYLOAD_PATH}`
3. Each row in the `[Template]` triggers one upload
4. After all rows succeed, suite variables are set:
   `${<pipeline_name>_snode_id}` (or `${<pipeline_name>_<unique_id>_snode_id}`)
5. ✅ The pipelines appear in the SnapLogic UI under
   `<ORG> → <project_space> → <project>`

To run against a different environment (e.g. stage):

```bash
make robot-run-tests-no-gp TAGS="tag_name" ENV=.env.stage     # eg: TAGS="import_pipeline_sample"
```

---

## TL;DR cheat sheet

- **`Import Pipelines From Template`** — appends `_<unique_id>`. Use for isolated/parallel runs.
- **`Import Pipeline With Original Name`** — keeps the name exact. Use when other assets reference the pipeline by name.
- Both default to **overwrite** on existing pipeline. Pass `duplicate_check=true` to fail instead.
- Both auto-store the `snode_id` as a suite variable for downstream test cases.
- Both look for the `.slp` file inside `src/pipelines/` (path set in `__init__.robot`).

---

*Companion to [`import_pipeline.robot`](./import_pipeline.robot).*
*HTML version (recommended for demo recording): [`import_pipeline_explained.html`](./import_pipeline_explained.html).*
