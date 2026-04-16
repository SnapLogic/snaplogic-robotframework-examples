# Robot Framework Test Execution Flow

This guide describes the framework-internal sequence of what happens when
Robot Framework tests are executed in this project — the phases, the
initialization steps, the keyword calls, and the files involved.

### When to read this vs the other guides

| If you want to... | Read this |
|-------------------|-----------|
| Understand each phase the framework walks through at runtime (dev / debugging perspective) | **This guide** |
| See a ready-to-copy reference of every `make` command and its flags | [`robot_tests_make_commands.md`](./robot_tests_make_commands.md) |
| Understand the `PROJECT_SPACE_SETUP` / `FORCE_RECREATE_PROJECT_SPACE` semantics | [`project_space_setup_safe_mode.md`](./project_space_setup_safe_mode.md) |
| See the full `robot-run-all-tests` end-to-end diagram | [`robot_run_all_tests_flow.md`](./robot_run_all_tests_flow.md) |
| Understand the Groundplex network pre-flight check | [`network_preflight_check.md`](./network_preflight_check.md) |
| Understand Groundplex lifecycle, container swaps, and the `FORCE_REPLACE` flag | [`groundplex_lifecycle.md`](./groundplex_lifecycle.md) |

---

## Table of Contents
- [Project Structure Overview](#project-structure-overview)
- [Test Execution Initialization Process](#test-execution-initialization-process)
  - [Phase 1: Suite Setup Initialization](#phase-1-suite-setup-initialization)
  - [Phase 2: Environment Configuration](#phase-2-environment-configuration)
  - [Phase 3: Project Infrastructure Setup](#phase-3-project-infrastructure-setup)
  - [Phase 4: Test Execution](#phase-4-test-execution)
  - [Phase 5: Output Generation](#phase-5-output-generation)
- [Key Features of the Initialization Process](#key-features-of-the-initialization-process)
- [Best Practices for Test Development](#best-practices-for-test-development)

---

## Project Structure Overview

### Test Directory Structure

```
{{cookiecutter.primary_pipeline_name}}/
├── test/                                   # All tests and test data
│   ├── suite/
│   │   ├── __init__.robot                  # Suite initialization file (CRITICAL)
│   │   ├── pipeline_tests/                 # Tests grouped by service / system
│   │   │   ├── env_setup.robot             # createplex + verify_project_space_exists
│   │   │   ├── oracle/
│   │   │   ├── postgres/
│   │   │   ├── snowflake/
│   │   │   ├── kafka/
│   │   │   ├── minio/
│   │   │   └── …
│   │   └── test_data/
│   │       ├── accounts_payload/           # Account JSON templates
│   │       │   ├── acc_oracle.json
│   │       │   ├── acc_postgres.json
│   │       │   └── …
│   │       └── queries/                    # SQL queries per DB
│   ├── resources/
│   │   └── common/                         # Shared keywords
│   ├── libraries/                          # Custom Python libraries
│   ├── robot_output/                       # Test execution results (HTML/XML)
│   └── .config/                            # Groundplex .slpropz config files
└── src/
    └── pipelines/                          # SnapLogic pipeline files (.slp)
```

---

## Test Execution Initialization Process

When Robot Framework starts for any test tag, execution always flows through
the same five phases below. Understanding where each phase runs and what it
touches is the fastest way to debug a failing run.

### Phase 1: Suite Setup Initialization

The **entry point** for every Robot run is `test/suite/__init__.robot`, which
Robot Framework automatically loads before any test body executes.

**File:** `{{cookiecutter.primary_pipeline_name}}/test/suite/__init__.robot`

#### 1. Library and Resource Loading

```robot
*** Settings ***
Library         OperatingSystem
Library         BuiltIn
Library         Process
Library         JSONLibrary
Resource        snaplogic_common_robot/snaplogic_apis_keywords/snaplogic_keywords.resource
```

The `snaplogic_common_robot` package is installed via pip (see
`requirements.txt`). It provides the reusable SnapLogic-specific keywords
(`Set Up Data`, `Ensure Project Setup Safe`, `Create Snaplex`,
`Download And Save Config File`, account/pipeline/task helpers, etc.).

#### 2. Global Variable Declaration

```robot
*** Variables ***
${account_payload_path}             ${CURDIR}/test_data/accounts_payload
${env_file_path}                    ${CURDIR}/../../.env
${env_files_dir}                    ${CURDIR}/../../env_files
${pipeline_payload_path}            ${CURDIR}/../../src/pipelines
${generative_slp_pipelines_path}    ${CURDIR}/../../src/generative_pipelines
${ENV_OVERRIDE_FILE}                ${EMPTY}
```

Paths use `${CURDIR}` so they resolve correctly whether Robot is invoked
from the repo root, the container's `/app/test`, or a CI runner's workspace.

#### 3. Suite Setup Execution

```robot
Suite Setup     Before Suite
```

The `Before Suite` keyword (defined in the same file) fires automatically
before any test body in any sub-folder runs — regardless of which tag you
selected via `TAGS=…`.

---

### Phase 2: Environment Configuration

`Before Suite` calls these keywords in order:

```robot
Before Suite
    Log To Console    env_file_path is:${env_file_path}
    Load Environment Variables
    Detect Auth Method
    Validate Environment Variables
    Set Up Global Variables
    Project Set Up-Delete Project Space-Create New Project space-Create Accounts
```

#### `Load Environment Variables`

Loads `.env` files in precedence order (lowest → highest):

1. Every `.env*` file under `env_files/` and its subdirectories
   (`database_accounts`, `messaging_service_accounts`, `mock_service_accounts`,
   `external_accounts`, `groundplex/`).
2. The root `.env` file.
3. An optional override file passed via `--variable ENV_OVERRIDE_FILE=…`
   (activated by the Makefile when you use `ENV=.env.stage`).

Each file is parsed line-by-line; comments and blanks are skipped. Every
value is tried as JSON first and, if it parses:

| Parsed type | Becomes |
|-------------|---------|
| Dictionary  | `&{lowercase_var_name}` global |
| List        | `@{lowercase_var_name}` global |
| Primitive (number / bool / string) | `${var_name}` global |
| Plain string (JSON parse failed)   | `${var_name}` global |

Each variable is also exported as an OS environment variable so Python
libraries (e.g., `auth_manager`) can read it.

#### `Detect Auth Method`

Auto-detects the authentication method if `AUTH_METHOD` is not already
set in `.env`:

| Signal in `.env` | Detected `AUTH_METHOD` |
|------------------|------------------------|
| `OAUTH2_TOKEN_URL` is set | `oauth2` |
| `BEARER_TOKEN` is set (but no OAUTH2_TOKEN_URL) | `jwt` |
| Neither is set | `basic` (default) |

Supported values: `basic`, `jwt`, `oauth2`, `sltoken`.

#### `Validate Environment Variables`

Required vars (always):

- `URL`
- `ORG_NAME`
- `PROJECT_SPACE`
- `PROJECT_NAME`
- `GROUNDPLEX_NAME`

Plus auth-method-specific vars:

| Auth method | Additional required vars |
|-------------|--------------------------|
| `basic`     | `ORG_ADMIN_USER`, `ORG_ADMIN_PASSWORD` |
| `jwt`       | `BEARER_TOKEN` |
| `oauth2`    | `OAUTH2_TOKEN_URL`, `OAUTH2_CLIENT_ID`, `OAUTH2_CLIENT_SECRET` |
| `sltoken`   | `ORG_ADMIN_USER`, `ORG_ADMIN_PASSWORD` |

If any are missing, the suite fails fast with:

```
Missing required environment variables for AUTH_METHOD=<method>: <list>.
Please check your .env file and ensure all required variables are defined.
```

#### `Set Up Global Variables`

Re-registers the path variables declared in the `*** Variables ***` section
as globals so they're accessible across test files.

---

### Phase 3: Project Infrastructure Setup

This phase is gated by the `PROJECT_SPACE_SETUP` variable, which defaults
to **`True`** (idempotent, non-destructive).

> **Terminology note:** "Setup mode" = `PROJECT_SPACE_SETUP=True`.
> "Verify-only mode" = `PROJECT_SPACE_SETUP=False`.

The `Before Suite` keyword calls
`Project Set Up-Delete Project Space-Create New Project space-Create Accounts`,
which dispatches to `Set Up Data` with the correct auth payload. `Set Up Data`
then calls `Ensure Project Setup Safe`, which handles Phase 3 semantics.

#### Setup mode — `PROJECT_SPACE_SETUP=True` (DEFAULT)

Idempotent, non-destructive:

| State found in SnapLogic org | Action |
|------------------------------|--------|
| Project space MISSING | Create project space + create project |
| Project space EXISTS, target project MISSING | Reuse space, create only the target project |
| BOTH already exist | No-op — the run simply reuses them. No delete, no rename. |

No existing project space or project is ever deleted in this mode. Other
projects in the same space are never touched.

```bash
# Most common — default, no flag needed
make robot-run-all-tests TAGS="oracle"

# Multiple tags (OR semantics — run tests tagged with ANY of these)
make robot-run-all-tests TAGS="oracle,minio,snowflake_demo"
```

#### Destructive override — `FORCE_RECREATE_PROJECT_SPACE=True` (opt-in)

Falls back to the legacy behavior that **deletes the entire project space**
(and every project inside) before recreating. Intended ONLY for
dedicated CI/regression project spaces. The Makefile prompts for
confirmation (type the project space name) unless `FORCE_CONFIRM=yes` is
also set.

```bash
# Interactive — prompts for confirmation
make robot-run-all-tests TAGS="oracle" FORCE_RECREATE_PROJECT_SPACE=True

# CI-friendly — bypass prompt
make robot-run-all-tests TAGS="oracle" FORCE_RECREATE_PROJECT_SPACE=True FORCE_CONFIRM=yes
```

#### Verify-only mode — `PROJECT_SPACE_SETUP=False` (opt-in)

Skips Snaplex registration and `.slpropz` download; just asserts the
project space exists and fails fast with an actionable multi-line console
message if not (listing the exact `make` commands that would create it).
Useful for shared orgs without create permissions and for CI smoke checks.

```bash
make robot-run-all-tests TAGS="oracle" PROJECT_SPACE_SETUP=False
```

See [`project_space_setup_safe_mode.md`](./project_space_setup_safe_mode.md)
for the complete case matrix.

#### Snaplex 409 conflict — fail-loud early guard

`Create Snaplex` used to treat an HTTP 409 Conflict as silent success,
which caused a downstream `.slpropz` 404. It now fails the test
immediately with a multi-line console message explaining that the
`GROUNDPLEX_NAME` already exists under a DIFFERENT project space and
listing three fixes (rename, delete, or switch project space).

#### Phase 3 failure recovery — active-nodes branch

Only fires when `FORCE_RECREATE_PROJECT_SPACE=True` is set and a
Groundplex is still attached to the space being deleted. Both
`robot-run-all-tests` and `robot-run-tests-no-gp` handle this — but with
different policies:

**`robot-run-all-tests` — auto-stop and retry** (framework manages the
Groundplex, so it's safe to auto-stop):

```
Phase 1 fails with: "cannot be deleted while it contains active nodes"
     → make stop-groundplex
     → sleep 60 s (let SnapLogic Cloud deregister the node)
     → retry make robot-run-tests TAGS="createplex" PROJECT_SPACE_SETUP=True
```

**`robot-run-tests-no-gp` — local-vs-external detection** (framework
stays hands-off for external Groundplexes):

- If a local `snaplogic-groundplex` container exists → same auto-stop +
  retry as above, but the container is left STOPPED afterwards (the
  `-no-gp` target never auto-starts Groundplexes).
- If no local container exists → the Groundplex is external; fails fast
  with an `ACTION REQUIRED: stop it externally` message and does NOT
  touch the external plex.

In the safe default mode (no `FORCE_RECREATE_PROJECT_SPACE=True`) this
error cannot occur because no project space deletion is attempted.

---

### Phase 4: Test Execution

After Phase 3 finishes, the Makefile orchestrator (`robot-run-all-tests`)
takes over Phases 4-5:

1. **createplex tagged tests** (`env_setup.robot`) register the Snaplex
   in SnapLogic Cloud and download `.slpropz` — only runs under
   `PROJECT_SPACE_SETUP=True`.
2. **`make launch-groundplex`** starts the Groundplex Docker container.
   This step is itself a multi-step pre-flight — see
   [`groundplex_lifecycle.md`](./groundplex_lifecycle.md) and
   [`network_preflight_check.md`](./network_preflight_check.md) for
   details. Actual ordering of the pre-flight (before `docker compose up`):
   - 🛑 External-plex guard: if `.env` has `EXTERNAL_GROUNDPLEX=yes`,
     fail fast and steer the user to `robot-run-tests-no-gp`.
     If the flag is not set but no local container or `.slpropz` exists,
     a soft warning is printed (5s pause, then continues).
   - 🌐 `check-network` (DNS / HTTPS / TLS trust probes)
     · skip with `SKIP_NETWORK_CHECK=1`
   - 🔎 Pre-swap check: if an existing `snaplogic-groundplex` container
     is attached to a different Snaplex than the new `.env` requests,
     print a prominent REPLACING banner and (in interactive shells)
     prompt for confirmation · skip with `FORCE_REPLACE=yes`.
     `robot-run-all-tests` already runs this as Phase 0 and passes
     `SWAP_CHECK_DONE=1` here to avoid double-prompting.
   - 🧹 clean up stale `.slpropz` directory (Docker bind-mount pitfall)
   - 📥 auto-run `createplex` if `.slpropz` is missing (self-healing)
     · skip with `SKIP_CREATEPLEX=1`

   > **Ordering matters:** the pre-swap check runs BEFORE auto-createplex
   > so declining the swap creates NO cloud resources.
3. **User-tagged tests** run against the live Groundplex.

> **For `robot-run-tests-no-gp`:** Phase 2 (Groundplex start) is skipped
> entirely. The target also prints a prominent warning if no local
> `snaplogic-groundplex` container is running, because tests that wait
> on Snaplex readiness will hang until a Groundplex registers. See
> [`robot_run_all_tests_flow.md`](./robot_run_all_tests_flow.md) for
> the full contrast table.

#### Tag-based execution

Tests are selected by `[Tags]` attached to each `*** Test Cases ***` entry.
Example from `oracle/oracle_baseline_tests.robot`:

```robot
*** Test Cases ***
Create Account
    [Tags]    oracle    create_account
    …

Import Pipelines
    [Tags]    oracle    import_pipeline
    …

Execute Triggered Task With Parameters
    [Tags]    oracle    regression
    …
```

Selecting tags via the Makefile:

```bash
# Run every test tagged with 'oracle'
make robot-run-all-tests TAGS="oracle"

# OR multiple tags — matches tests tagged with ANY of these
make robot-run-all-tests TAGS="oracle,minio,postgres"

# Always-on internal tags
# (usually you wouldn't invoke these directly — they're used by the
# framework to structure setup/verify phases)
make robot-run-all-tests TAGS="createplex"             # Phase 1B (Snaplex + slpropz)
make robot-run-all-tests TAGS="verify_project_space_exists"  # Verify-only check
make robot-run-all-tests TAGS="cleanup_stale_projects" # Legacy timestamped-project cleanup
```

> **Note on tag syntax:** the Makefile splits `TAGS` on whitespace via
> `foreach`, so Robot Framework's `AND`/`OR`/`NOT` keyword expressions
> (which contain spaces) do NOT work. Use comma-separated values for
> OR semantics. See
> [`robot_tests_make_commands.md`](./robot_tests_make_commands.md) for
> advanced filtering.

#### Resource utilization

- Account payloads: `test/suite/test_data/accounts_payload/*.json`
- Pipelines: `src/pipelines/*.slp`
- SQL queries / resources: `test/suite/test_data/queries/*.resource`
- Shared keywords: `test/resources/common/*.resource`
- Python helpers: `test/libraries/*.py`

---

### Phase 5: Output Generation

Results are written by Robot Framework to `test/robot_output/`:

| File | Purpose |
|------|---------|
| `report-<timestamp>.html` | Summary report with pass/fail stats |
| `log-<timestamp>.html`    | Detailed execution log (keyword-level) |
| `output-<timestamp>.xml`  | Machine-readable XML for CI |

Open the HTML files in any browser:

```bash
open test/robot_output/report-*.html    # macOS
xdg-open test/robot_output/report-*.html # Linux
```

---

## Key Features of the Initialization Process

### ✅ Fail-Fast Validation

Missing `.env` vars fail the suite before any SnapLogic API call is made.
A missing `URL` also blocks `make check-network`, so you get a clear
error instead of spending a minute waiting for an HTTP timeout.

### 🔄 Dynamic Variable Handling

JSON values in `.env` are auto-parsed into dictionaries, lists, or
primitives. Plain strings fall back to `${var}`. No manual type conversion
in your test code.

### 🛡️ Non-destructive by default

`PROJECT_SPACE_SETUP=True` — the default — never deletes existing project
spaces or projects. Destructive recreate is opt-in via
`FORCE_RECREATE_PROJECT_SPACE=True` + confirmation prompt.

### 🛑 External-plex guard

When `.env` has `EXTERNAL_GROUNDPLEX=yes`, both `robot-run-all-tests` and
`launch-groundplex` fail fast with a message directing the user to
`robot-run-tests-no-gp` (the correct tool for externally managed plexes).

If the flag is not set, a soft heuristic warns when no local container or
`.slpropz` exists (suggesting the plex may be external), but continues
after a 5-second pause — covering legitimate first-run scenarios.

To remove the guard, simply delete `EXTERNAL_GROUNDPLEX` from `.env`.

### 🌐 Pre-flight Network Check

`make launch-groundplex` probes DNS, HTTPS, and TLS trust against the
SnapLogic URL from `.env` BEFORE starting the Docker container.
Prevents the 200 s JCC timeout on corporate networks with SSL inspection.

### 🔁 Self-healing Groundplex launch

If `.slpropz` is missing, `launch-groundplex` auto-runs `createplex` to
fetch it — no need to run `robot-run-all-tests` first just to seed the
Groundplex config.

### ⚠️ Groundplex swap warning

When `.env` changes in a way that would replace the currently-running
Groundplex container with a different Snaplex,
`launch-groundplex` prints a multi-line banner naming the CURRENT and
NEW Snaplex, explains the orphan-node consequence, and prompts for
confirmation (bypass with `FORCE_REPLACE=yes`).

### 📊 Comprehensive Logging

Every phase logs to both Robot Framework's output and console. Auto-parsed
JSON, detected auth method, project-space state, Snaplex registration
status, and Groundplex container swap all appear in the stream.

---

## Best Practices for Test Development

### ✅ Environment Configuration

- Put ALL required keys in `.env` (see the Validate Environment Variables
  table above for the canonical list).
- Prefer JSON literals in `.env` for complex values — they're auto-parsed.
- Keep per-service overrides in `env_files/<category>/` so the root `.env`
  stays short. Root `.env` wins on conflicts (loaded last).
- When pointing at a new SnapLogic pod or project space, **change
  `GROUNDPLEX_NAME` too** — that's what triggers the clean Groundplex
  swap path (see [`groundplex_lifecycle.md`](./groundplex_lifecycle.md)
  for why).

### 🧱 Test Organization

- Group tests by service under `test/suite/pipeline_tests/<service>/`.
- Tag tests by service AND by action (e.g., `[Tags] oracle import_pipeline`)
  so users can select broadly or narrowly.
- Share setup/verify helpers via `test/resources/common/*.resource`.

### 🧪 Pipeline Management

- Store `.slp` files under `src/pipelines/` (or `src/generative_pipelines/`
  for SLIM-generated ones).
- Use parameterized paths so a pipeline can be reused across project
  spaces by changing `.env`.

### 🧪 Test-case hygiene

- **Verifications in test cases, logic in keywords.** A test case should
  call keywords and then assert results. `FOR`/`IF` blocks, query
  execution, and data transformations belong inside keywords.
- No customer/person names in code, comments, test data, or output
  fixtures — use generic placeholders.

---

## Related guides

- [`robot_run_all_tests_flow.md`](./robot_run_all_tests_flow.md) — full
  `robot-run-all-tests` end-to-end flow diagram
- [`project_space_setup_safe_mode.md`](./project_space_setup_safe_mode.md) —
  `PROJECT_SPACE_SETUP` / `FORCE_RECREATE_PROJECT_SPACE` semantics
- [`network_preflight_check.md`](./network_preflight_check.md) — DNS /
  HTTPS / TLS check and `SKIP_*` flags
- [`groundplex_lifecycle.md`](./groundplex_lifecycle.md) — Groundplex
  container swap behavior and `FORCE_REPLACE`
- [`robot_tests_make_commands.md`](./robot_tests_make_commands.md) —
  reference of every `make` command and flag
