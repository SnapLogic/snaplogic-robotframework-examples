# `robot-run-all-tests` — End-to-End Flow Guide

This guide walks through everything that happens when you run:

```bash
make robot-run-all-tests TAGS=oracle
```

It covers project space creation, project creation, Snaplex registration,
Groundplex startup, and how each piece is wired together across the Makefile,
Robot Framework suite setup, and the `snaplogic-common-robot` library.

For the destructive / safe-mode semantics specifically, see
[`project_space_setup_safe_mode.md`](./project_space_setup_safe_mode.md).

> **Default behavior:** `PROJECT_SPACE_SETUP=True` is the **default** —
> you don't need to pass it. The setup is idempotent and non-destructive
> (creates only what's missing, never deletes existing assets).
> Pass `PROJECT_SPACE_SETUP=False` only when you want **verify-only** mode
> (fast-fail if the project space doesn't exist; skip Snaplex registration
> and `.slpropz` download).

---

## Complete flow

```
make robot-run-all-tests TAGS=oracle
                              │
                              ▼
┌──────────────────────────────────────────────────────────────────────────────┐
│ Phase 1 — Runs robot with tag: createplex                                    │
│           (because PROJECT_SPACE_SETUP defaults to True; pass =False to      │
│            switch to verify-only mode — see "Verify-only mode" below)        │
└──────────────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌──────────────────────────────────────────────────────────────────────────────┐
│ STEP A — Before Suite (__init__.robot, fires automatically for ANY tag)      │
│                                                                              │
│   1. Load Environment Variables                                              │
│        • env_files/* (low precedence) → root .env (high) → ENV_OVERRIDE (top)│
│   2. Detect Auth Method (basic / jwt / oauth2 / sltoken)                     │
│   3. Validate required env vars (URL, ORG_NAME, PROJECT_SPACE,               │
│      PROJECT_NAME, GROUNDPLEX_NAME, credentials)                             │
│   4. Set Up Global Variables (paths for accounts, pipelines, …)              │
│   5. Call Set Up Data  →  Ensure Project Setup Safe                          │
└──────────────────┬───────────────────────────────────────────────────────────┘
                   │
                   ▼
┌──────────────────────────────────────────────────────────────────────────────┐
│ Ensure Project Setup Safe (non-destructive by default)                       │
│                                                                              │
│   ┌─────────────────────────────────────────────────────────────┐            │
│   │ FORCE_RECREATE_PROJECT_SPACE == True ?                      │            │
│   └───────────────────────────┬─────────────────────────────────┘            │
│                               │ NO (default / safe)                          │
│                               ▼                                              │
│           Get Org List → does ${PROJECT_SPACE} exist?                        │
│                               │                                              │
│      ┌────────────────────────┼────────────────────────┐                     │
│      ▼ (NO)                   │                        ▼ (YES)               │
│  ┌──────────────┐              │         Get Project List → does              │
│  │ Sub-case 2A  │              │         ${PROJECT_NAME} exist inside?        │
│  │ Space MISSING│              │                 │                           │
│  ├──────────────┤              │      ┌──────────┼──────────┐                │
│  │ Create Space │              │      ▼ (NO)              ▼ (YES)            │
│  │ Create       │              │ ┌────────────┐      ┌──────────────────┐    │
│  │  Project     │              │ │Sub-case 2B │      │ Sub-case 2C      │    │
│  └──────────────┘              │ │Space OK,   │      │ Both exist       │    │
│                                │ │Project NEW │      ├──────────────────┤    │
│                                │ ├────────────┤      │ NO-OP.           │    │
│                                │ │Reuse space │      │ Leave both       │    │
│                                │ │Create      │      │ as-is. Run       │    │
│                                │ │ ${PROJECT_ │      │ reuses the       │    │
│                                │ │  NAME} in  │      │ existing project.│    │
│                                │ │  it        │      │                  │    │
│                                │ └────────────┘      └──────────────────┘    │
│                                ▼ (YES → destructive override)                │
│                       ┌─────────────────────────────────┐                    │
│                       │ Sub-case FORCE_RECREATE         │                    │
│                       │  ⚠️ Delete ENTIRE project space │                    │
│                       │  Create Space, Create Project   │                    │
│                       │  (Makefile already prompted for │                    │
│                       │   confirmation before reaching  │                    │
│                       │   here — or FORCE_CONFIRM=yes)  │                    │
│                       └─────────────────────────────────┘                    │
└──────────────────┬───────────────────────────────────────────────────────────┘
                   │
                   │  At this point the SnapLogic org has:
                   │    ${PROJECT_SPACE}/
                   │        └── ${PROJECT_NAME}  (created if missing, reused if existing)
                   │
                   ▼
┌──────────────────────────────────────────────────────────────────────────────┐
│ STEP B — createplex-tagged tests (env_setup.robot)                           │
│                                                                              │
│   1. "Create Snaplex In Project Space"                                       │
│      → REST call into SnapLogic org                                          │
│      → Registers a Snaplex *definition* (metadata only) inside the           │
│        project space using env vars:                                         │
│           GROUNDPLEX_NAME, GROUNDPLEX_ENV, ORG_NAME,                         │
│           RELEASE_BUILD_VERSION, GROUNDPLEX_LOCATION_PATH                    │
│                                                                              │
│   2. "Download And Save slpropz File"                                        │
│      → Fetches the config blob the Docker container needs to boot            │
│      → Saves to ./.config/${GROUNDPLEX_NAME}.slpropz                         │
└──────────────────┬───────────────────────────────────────────────────────────┘
                   │
                   ▼
          ┌────────┴────────┐
          │ Phase 1 OK?     │
          └────┬────────┬───┘
               │        │
       YES ────┘        └──── NO (failure)
               │                │
               │      ┌─────────┴────────────────────────────┐
               │      │ Error contains                       │
               │      │ "cannot be deleted while it          │
               │      │  contains active nodes" ?            │
               │      └────┬────────────────────────────┬────┘
               │       YES │                            │ NO
               │           ▼                            ▼
               │  ┌──────────────────────┐    ┌───────────────┐
               │  │ 1. stop-groundplex   │    │ Exit 1        │
               │  │ 2. sleep 60 s        │    │ (different    │
               │  │ 3. retry createplex  │    │  reason)      │
               │  └──────────┬───────────┘    └───────────────┘
               │             │
               ▼             ▼
┌──────────────────────────────────────────────────────────────────────────────┐
│ Phase 2 — Start the Groundplex container                                     │
│ Calls: make launch-groundplex                                                │
│                                                                              │
│   • docker compose --profile gp up -d snaplogic-groundplex                   │
│   • Container mounts ./.config/${GROUNDPLEX_NAME}.slpropz                    │
│   • JCC inside container boots, calls home to SnapLogic Cloud,               │
│     registers itself as an ACTIVE NODE attached to the Snaplex               │
│     definition created in STEP B                                             │
│   • Container joins the snaplogicnet Docker bridge so it can                 │
│     reach oracle-db, postgres-db, etc. by container name                     │
└──────────────────┬───────────────────────────────────────────────────────────┘
                   │
                   ▼
┌──────────────────────────────────────────────────────────────────────────────┐
│ Phase 2.1 — Travis-only: fix permissions (no-op locally)                     │
└──────────────────┬───────────────────────────────────────────────────────────┘
                   │
                   ▼
┌──────────────────────────────────────────────────────────────────────────────┐
│ Phase 3 — Run YOUR tests                                                     │
│ Calls: make robot-run-tests TAGS=oracle PROJECT_SPACE_SETUP=False            │
│                                                                              │
│   • Before Suite fires AGAIN for this sub-invocation, BUT because            │
│     PROJECT_SPACE_SETUP=False is passed internally, Ensure Project           │
│     Setup Safe is NOT called; we only re-authenticate and re-populate        │
│     globals (Phase 1 already did the setup, no need to redo it).             │
│   • Oracle tests run, triggering pipelines that execute on the               │
│     Groundplex from Phase 2.                                                 │
│   • Account creation, pipeline imports, and triggered task creations         │
│     all target the project that exists in ${PROJECT_NAME} (created or        │
│     reused in Phase 1).                                                      │
└──────────────────────────────────────────────────────────────────────────────┘
```

---

## Two concepts often confused

| Concept | Where it lives | What creates it |
|---------|----------------|-----------------|
| **Snaplex** (the definition) | Inside SnapLogic org, under your project space | Phase 1 Step B — a REST API call triggered by the `createplex` tag |
| **Groundplex** (the runtime) | Docker container on your machine | Phase 2 — `docker compose up` via `make launch-groundplex` |

The Snaplex is just metadata describing an execution endpoint. The Groundplex
is the actual JCC process that picks up pipeline execution requests. The
`.slpropz` file is the credential that binds the running container to the
Snaplex definition.

---

## Entities created, when, and where

| # | Entity | Where it lives | Created by | Phase | Destructive default? |
|---|--------|----------------|------------|-------|----------------------|
| 1 | Project space | SnapLogic org | `Ensure Project Setup Safe` → `Create Project Space` | Phase 1 Step A (only if missing) | ✅ No — reused if exists |
| 2 | Project (the folder inside the space) | SnapLogic project space | `Ensure Project Setup Safe` → `Create Project` | Phase 1 Step A | ✅ No — created if missing, reused if already exists |
| 3 | Snaplex definition (metadata) | SnapLogic project space | `Create Snaplex In Project Space` test | Phase 1 Step B | n/a — idempotent create-or-update |
| 4 | `.slpropz` config file | `./.config/` on host | `Download And Save Config File` test | Phase 1 Step B | Overwrites local file |
| 5 | Groundplex container (runtime) | Docker on `snaplogicnet` | `make launch-groundplex` | Phase 2 | Starts fresh if stopped; no-op if running |
| 6 | Accounts (Oracle, S3, etc.) | Inside the project | `Create All Accounts` (called from suite setup or user tests) | Phase 3 or earlier | Depends on `overwrite_if_exists` |

---

## Sub-case outcomes — what your org looks like before vs after Phase 1

Given `PROJECT_SPACE_SETUP=True` (the default), `FORCE_RECREATE_PROJECT_SPACE` not set, and:
- `ORG_NAME=my_org`
- `PROJECT_SPACE=shared`
- `PROJECT_NAME=sl_project`

### Sub-case 2A — first run ever

```
BEFORE                         AFTER Phase 1
(empty)                        shared/
                                 ├── sl_project    (new)
                                 └── [Snaplex: myplex registered]
```

### Sub-case 2B — space reused, your project missing

```
BEFORE                         AFTER Phase 1
shared/                        shared/
  ├── other_team_project         ├── other_team_project     (untouched)
                                 ├── sl_project             (new)
                                 └── [Snaplex: myplex registered]
```

### Sub-case 2C — space and project both already exist

```
BEFORE                         AFTER Phase 1
shared/                        shared/
  ├── other_team_project         ├── other_team_project     (untouched)
  └── sl_project                 └── sl_project             (unchanged)
     [accts/pipelines/tasks]        [accts/pipelines/tasks still there]
                                 └── [Snaplex: myplex registered]
```

No changes are made to the project space or the project. The run simply
reuses the existing `sl_project`. Account creation, pipeline imports, and
triggered task creations all target the same `sl_project`.

### Sub-case FORCE_RECREATE — destructive opt-in

```
BEFORE                         AFTER Phase 1
shared/                        shared/
  ├── other_team_project         └── sl_project            (new, everything else GONE)
  └── sl_project                 └── [Snaplex: myplex re-registered]
     [accts/pipelines/tasks]
```

Only runs after the Makefile interactive confirmation passes (or
`FORCE_CONFIRM=yes`). Succeeds only if no Groundplex is currently attached —
otherwise the active-nodes recovery branch kicks in.

---

## Phase 1 failure recovery — the active-nodes case

This path only fires when the project space deletion step runs (i.e.
`FORCE_RECREATE_PROJECT_SPACE=True`) and a Groundplex is still attached:

```
Phase 1 fails with: "cannot be deleted while it contains active nodes"
          │
          ▼
   1. make stop-groundplex
        • docker exec … jcc.sh stop
        • wait for JCC PID file to disappear (up to 20 × 10 s)
        • docker compose --profile gp down --remove-orphans
   2. sleep 60 s   (SnapLogic Cloud deregisters the node)
   3. retry make robot-run-tests TAGS="createplex" PROJECT_SPACE_SETUP=True
          │
          ▼
      Success → continue to Phase 2
      Failure → exit 1
```

In **safe mode** (the new default) this error cannot occur, because no
project space deletion is attempted.

---

## Subsequent runs — what happens on re-run

```bash
# Subsequent runs are identical to the first — the safe-mode setup is
# idempotent, so re-running is harmless:
make robot-run-all-tests TAGS=oracle
  # Phase 1 Step A → Sub-case 2C: both space and project exist, no-op
  # Phase 1 Step B → Snaplex re-asserted (idempotent), .slpropz re-downloaded
  # Phase 2        → Groundplex container already running, no-op
  # Phase 3        → tests run
```

### Verify-only mode (opt-in)

If you explicitly want **fast-fail** behavior — e.g., to assert in CI that
setup was already done by an earlier job, or to avoid Snaplex re-registration —
pass `PROJECT_SPACE_SETUP=False`:

```bash
make robot-run-all-tests TAGS=oracle PROJECT_SPACE_SETUP=False
  # Phase 1 → runs verify_project_space_exists tag instead of createplex
  #            • Snaplex registration is SKIPPED
  #            • .slpropz download is SKIPPED
  #            • If project space is missing → fails with the helpful
  #              error message shown in the next section
  # Phase 2 → Groundplex container started (assumes .slpropz already on disk)
  # Phase 3 → tests run
```

### Helpful failure message when verify-only mode finds nothing

If `PROJECT_SPACE_SETUP=False` is passed and the project space does not exist,
the `Validate Project Space Exists` keyword fails with a self-explanatory
console message (printed via `Log To Console` so it survives Robot's summary
truncation):

```
============================================================
❌ Project space '<name>' is not created in org '<org>'.
============================================================

💡 To create the project space and project, run ONE of these:

  1) Full setup (creates project space + project + Snaplex, launches Groundplex):
      make robot-run-all-tests TAGS="<your-tags>"
      Example: make robot-run-all-tests TAGS="oracle"

  2) Without Groundplex (use when a Groundplex is already running externally):
      make robot-run-tests-no-gp TAGS="<your-tags>"
      Example: make robot-run-tests-no-gp TAGS="oracle"

ℹ️ PROJECT_SPACE_SETUP defaults to True (safe, idempotent — creates only what's missing).
   You explicitly passed PROJECT_SPACE_SETUP=False, which only VERIFIES the space exists.
   Drop the flag (or omit it) to let the framework create the project space for you.
============================================================
```

The keyword is defined at
`{{cookiecutter.primary_pipeline_name}}/test/suite/pipeline_tests/env_setup.robot`.

---

## Contrast with `robot-run-tests-no-gp`

| Phase | `robot-run-all-tests` | `robot-run-tests-no-gp` |
|-------|----------------------|-------------------------|
| 1a — Project space + project setup (Before Suite) | ✅ | ✅ |
| 1b — Register Snaplex definition (`createplex` tag) | ✅ | ❌ (uses `verify_project_space_exists` instead) |
| 1c — Download `.slpropz` config | ✅ | ❌ |
| 2 — Start Groundplex container | ✅ | ❌ — explicit skip banner printed |
| 3 — Run your tests | ✅ | ✅ |

`robot-run-tests-no-gp` assumes a Groundplex is already running (managed by
you or a separate CI job). It never creates, starts, or stops one.

---

## Where each piece of logic lives

| Logic | File |
|-------|------|
| Orchestration (`robot-run-all-tests`, Phase 2 dispatch) | `{{cookiecutter.primary_pipeline_name}}/makefiles/common_services/Makefile.testing` |
| `launch-groundplex` target | `{{cookiecutter.primary_pipeline_name}}/makefiles/common_services/Makefile.groundplex` |
| `stop-groundplex` target (used by recovery branch) | `Makefile.testing` |
| `Before Suite` keyword chain | `{{cookiecutter.primary_pipeline_name}}/test/suite/__init__.robot` |
| `Set Up Data`, `Ensure Project Setup Safe`, `Create Project Space`, `Create Project` | `snaplogic-common-robot` library — `snaplogic_keywords.resource` |
| `Create Snaplex In Project Space`, `Download And Save slpropz File` (createplex tag) | `{{cookiecutter.primary_pipeline_name}}/test/suite/pipeline_tests/env_setup.robot` |
| `Create Snaplex`, `Download And Save Config File` keywords | `snaplogic-common-robot` library |
| Confirmation prompt for destructive path | `Makefile.testing` inside `robot-run-tests` target |

---

## Related guides

- [`project_space_setup_safe_mode.md`](./project_space_setup_safe_mode.md) —
  deeper dive into `PROJECT_SPACE_SETUP` / `FORCE_RECREATE_PROJECT_SPACE` /
  `cleanup-stale-projects` semantics, including the full case matrix and the
  cleanup keyword.
- [`robot_framework_test_execution_flow.md`](./robot_framework_test_execution_flow.md) —
  general Robot Framework test flow for this project.
- [`robot_tests_make_commands.md`](./robot_tests_make_commands.md) —
  full reference of all make commands.
