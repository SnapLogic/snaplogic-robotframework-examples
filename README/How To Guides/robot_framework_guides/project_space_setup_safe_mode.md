# Project Space Setup — Safe Mode Logic

This guide documents the non-destructive project-space/project setup behavior
used by the Robot Framework harness during `make robot-run-all-tests` (or
`make robot-run-tests-no-gp`).

`PROJECT_SPACE_SETUP=True` is now the **default** — you don't need to pass it.
The setup is idempotent: it creates only what's missing and never deletes
existing assets. Pass `PROJECT_SPACE_SETUP=False` only when you want
**verify-only** mode (fast-fail if the project space doesn't exist).

This replaces the earlier destructive behavior, which deleted the entire project
space — and every project inside it — whenever the flag was set. That destructive
behavior is now opt-in via `FORCE_RECREATE_PROJECT_SPACE=True` (with a
confirmation prompt).

---

## Parameters at a glance

| Parameter | Default | Meaning |
|-----------|---------|---------|
| `PROJECT_SPACE_SETUP` | `True` | `True` → idempotent ensure (safe; creates only what's missing). `False` → verify-only / fast-fail (no creation, no Snaplex re-registration). |
| `FORCE_RECREATE_PROJECT_SPACE` | `False` | `True` → destructive legacy behavior. Opt-in only. |
| `FORCE_CONFIRM` | unset | `yes` → bypass the interactive confirmation prompt (CI mode). |
| `RETENTION_DAYS` | `7` | Cleanup retention window for legacy timestamped projects. |
| `DRY_RUN` | `False` | `True` → cleanup previews deletions without calling the API. |

---

## CASE 1 — `PROJECT_SPACE_SETUP=False` (verify-only, opt-in)

```
make robot-run-all-tests TAGS=oracle PROJECT_SPACE_SETUP=False
                │
                ▼
   ┌─────────────────────────────┐
   │ Phase 1.1: verify-only path │
   │ Runs test with tag:         │
   │ verify_project_space_exists │
   │ (skips Snaplex registration │
   │  and .slpropz download)     │
   └──────────────┬──────────────┘
                  │
                  ▼
         ┌────────────────┐
         │ Does project   │
         │ space exist?   │
         └────┬──────┬────┘
              │      │
         YES  │      │  NO
              ▼      ▼
      ┌──────────┐  ┌────────────────────────────────────┐
      │ ✅ Pass  │  │ ❌ Fail with multi-line guidance:  │
      │ continue │  │ "Project space '<X>' is not        │
      │ to tests │  │  created. To create it, run ONE    │
      └──────────┘  │  of these: ...                     │
                    │  • make robot-run-all-tests        │
                    │      TAGS=\"<your-tags>\"          │
                    │  • make robot-run-tests-no-gp      │
                    │      TAGS=\"<your-tags>\"          │
                    │  ...                               │
                    │  (full message in env_setup.robot) │
                    └────────────────────────────────────┘

No writes to SnapLogic besides a list API call. Zero risk.

When to use this mode:
  • Shared org where you don't have create permissions.
  • CI smoke tests that just verify setup is already in place.
  • Quick iterations where you want to skip Snaplex re-registration
    and .slpropz re-download.
```

---

## CASE 2 — `PROJECT_SPACE_SETUP=True` (DEFAULT, no FORCE flag)

The `Ensure Project Setup Safe` keyword branches into **three sub-cases**:

```
make robot-run-all-tests TAGS=oracle
                               │
                               ▼
                  ┌────────────────────────────┐
                  │ FORCE_RECREATE_PROJECT_    │
                  │ SPACE == True ?            │
                  └────────┬───────────────────┘
                           │ NO (default)
                           ▼
                  ┌────────────────────────────┐
                  │ Get Org List → does        │
                  │ project_space exist?       │
                  └──┬──────────────┬──────────┘
                     │              │
                 NO  │              │  YES
                     ▼              ▼
          ┌─────────────────┐   ┌──────────────────────┐
          │   Sub-case 2A   │   │ Get Project List →   │
          │  Space missing  │   │ does ${project_name} │
          └────────┬────────┘   │ exist in space?      │
                   │            └──┬─────────────┬─────┘
                   │               │             │
                   │           NO  │             │ YES
                   │               ▼             ▼
                   │      ┌────────────────┐  ┌──────────────────┐
                   │      │  Sub-case 2B   │  │  Sub-case 2C     │
                   │      │ Space exists,  │  │ Space exists &   │
                   │      │ project missing│  │ project exists   │
                   │      └────────┬───────┘  └────────┬─────────┘
                   ▼               ▼                   ▼
```

### Sub-case 2A — project space MISSING

```
┌─────────────────────────────────────────┐
│ State BEFORE:                           │
│   <project_space> does not exist        │
├─────────────────────────────────────────┤
│ Action:                                 │
│   1. Create Project Space               │
│   2. Create Project (${PROJECT_NAME})   │
│   3. Set ${PROJECT_NAME} global = same  │
├─────────────────────────────────────────┤
│ State AFTER:                            │
│   <project_space>/                      │
│     └── ${PROJECT_NAME}   ◄── NEW       │
├─────────────────────────────────────────┤
│ Console log:                            │
│   ℹ️  Project space [X] does not        │
│       exist — creating fresh.           │
└─────────────────────────────────────────┘
```

### Sub-case 2B — space EXISTS, project MISSING

```
┌─────────────────────────────────────────┐
│ State BEFORE:                           │
│   <project_space>/                      │
│     ├── project_A       (other user)    │
│     └── project_B       (other user)    │
├─────────────────────────────────────────┤
│ Action:                                 │
│   1. Reuse existing project space       │
│   2. Create Project (${PROJECT_NAME})   │
│   3. Set ${PROJECT_NAME} global = same  │
├─────────────────────────────────────────┤
│ State AFTER:                            │
│   <project_space>/                      │
│     ├── project_A                  ✅   │
│     ├── project_B                  ✅   │
│     └── ${PROJECT_NAME}   ◄── NEW       │
├─────────────────────────────────────────┤
│ Console log:                            │
│   ℹ️  Project space [X] already exists  │
│       — reusing it. Other projects in   │
│       this space will NOT be touched.   │
│   ℹ️  Project [X/Y] does not exist —    │
│       creating it.                      │
└─────────────────────────────────────────┘
```

### Sub-case 2C — space EXISTS, project EXISTS (the fix for the incident)

```
┌─────────────────────────────────────────────────────┐
│ State BEFORE:                                       │
│   <project_space>/                                  │
│     ├── project_A                  (other user)    │
│     ├── project_B                  (other user)    │
│     └── ${PROJECT_NAME}            (existing)      │
├─────────────────────────────────────────────────────┤
│ Action:                                             │
│   No changes. Project space and project both       │
│   already exist — the run simply reuses them.       │
│   No delete, no rename, no timestamped copy.        │
├─────────────────────────────────────────────────────┤
│ State AFTER:                                        │
│   <project_space>/                                  │
│     ├── project_A                           ✅      │
│     ├── project_B                           ✅      │
│     └── ${PROJECT_NAME}                     ✅      │
│         (unchanged — this run targets this one)     │
├─────────────────────────────────────────────────────┤
│ Console log:                                        │
│   ℹ️ Project space [X] and project [Y] both        │
│      already exist — leaving them as-is. No        │
│      changes made.                                  │
└─────────────────────────────────────────────────────┘
```

---

## CASE 3 — `PROJECT_SPACE_SETUP=True` + `FORCE_RECREATE_PROJECT_SPACE=True` (destructive, opt-in)

```
make robot-run-all-tests TAGS=oracle \
      PROJECT_SPACE_SETUP=True \
      FORCE_RECREATE_PROJECT_SPACE=True
                           │
                           ▼
              ┌──────────────────────────────┐
              │ Makefile guard:              │
              │ Is FORCE_CONFIRM=yes ?       │
              └──────┬────────────────┬──────┘
                     │                │
                YES  │                │  NO (default / interactive)
                     │                ▼
                     │    ┌──────────────────────────────────┐
                     │    │ Read PROJECT_SPACE from .env     │
                     │    │ Print ⚠️ DESTRUCTIVE banner      │
                     │    │ Prompt:                          │
                     │    │   "Type project space name to    │
                     │    │    confirm (or Ctrl+C to abort):"│
                     │    └────────────┬─────────────────────┘
                     │                 │
                     │          ┌──────┴──────┐
                     │          │             │
                     │    Typed │             │ Wrong / Ctrl+C
                     │  correctly             │
                     │          ▼             ▼
                     │   ┌────────────┐  ┌──────────────┐
                     │   │ Proceed... │  │ ❌ Abort.    │
                     │   └─────┬──────┘  │ exit 1       │
                     │         │         └──────────────┘
                     ▼         ▼
        ┌──────────────────────────────┐
        │ Robot: FORCE_RECREATE branch │
        └──────────────┬───────────────┘
                       │
                       ▼
        ┌─────────────────────────────────────────┐
        │ State BEFORE:                           │
        │   <project_space>/                      │
        │     ├── project_A                       │
        │     ├── project_B                       │
        │     └── ${PROJECT_NAME}                 │
        ├─────────────────────────────────────────┤
        │ Action:                                 │
        │   1. Delete ENTIRE project space        │
        │      (and every project inside)         │
        │   2. Create Project Space               │
        │   3. Create Project (${PROJECT_NAME})   │
        │   4. Set ${PROJECT_NAME} global = same  │
        ├─────────────────────────────────────────┤
        │ State AFTER:                            │
        │   <project_space>/                      │
        │     └── ${PROJECT_NAME}   ◄── NEW       │
        │   (everything else GONE)                │
        ├─────────────────────────────────────────┤
        │ Console log:                            │
        │   ⚠️  FORCE_RECREATE_PROJECT_SPACE=True │
        │       — deleting entire project space   │
        │       [X] and ALL projects inside it.   │
        └─────────────────────────────────────────┘
```

### Confirmation decision matrix

| FORCE_RECREATE | FORCE_CONFIRM | User types correct name? | Result |
|----------------|---------------|--------------------------|--------|
| `True` | unset/no   | Yes   | ✅ Proceeds with destructive recreate |
| `True` | unset/no   | No    | ❌ Aborts with exit 1 |
| `True` | `yes`      | (not prompted) | ✅ Proceeds immediately (CI mode) |
| `False` (default) | any | (not prompted) | Falls through to safe Case 2 |

---

## CASE 4 — `make cleanup-stale-projects` (legacy housekeeping, optional)

> **Legacy note:** an earlier iteration of the safe-mode logic created
> `${PROJECT_NAME}_<timestamp>` projects whenever the base name already existed.
> The current logic (Sub-case 2C) no longer does this — it simply reuses the
> existing project. This cleanup target remains for purging legacy timestamped
> projects that were created by older versions of the framework and may still
> be lying around in your project space. New runs do not produce timestamped
> projects, so most users will never need to invoke this.

```
make cleanup-stale-projects RETENTION_DAYS=7 DRY_RUN=False
                           │
                           ▼
              ┌────────────────────────────┐
              │ Makefile target passes:    │
              │   RETENTION_DAYS=7         │
              │   DRY_RUN=False            │
              │ Runs tag:                  │
              │   cleanup_stale_projects   │
              └─────────────┬──────────────┘
                            │
                            ▼
              ┌────────────────────────────┐
              │ Keyword:                   │
              │ Cleanup Old Timestamped    │
              │ Projects                   │
              └─────────────┬──────────────┘
                            │
                            ▼
              ┌────────────────────────────┐
              │ cutoff = now − RETENTION   │
              │ Get Project List(space)    │
              └─────────────┬──────────────┘
                            │
                            ▼
         ┌──────────────────────────────────────┐
         │ For each project in the space:       │
         └───────────────┬──────────────────────┘
                         │
                         ▼
         ┌──────────────────────────────────────────┐
         │ Regex match:                             │
         │  ^${PROJECT_NAME}_(\d{8}_\d{6})$         │
         └───┬──────────────────────────────────┬───┘
             │                                  │
        NO match                            MATCH
             │                                  │
             ▼                                  ▼
     ┌─────────────────┐         ┌──────────────────────────┐
     │ ✅ SKIP          │         │ Parse timestamp          │
     │ (never touched) │         │ (Convert Date)           │
     │                 │         └────────────┬─────────────┘
     │ Covers:         │                      │
     │ • other users' │           ┌──────────┴──────────┐
     │   projects     │           │                     │
     │ • base project │      PARSE OK                PARSE FAIL
     │   itself (no   │           │                     │
     │   suffix)      │           │                     ▼
     │ • differently- │           │          ┌───────────────────┐
     │   named        │           │          │ ⚠️  Log warning   │
     │   projects     │           │          │ SKIP project      │
     └─────────────────┘           │          └───────────────────┘
                                   │
                                   ▼
                     ┌─────────────────────────┐
                     │ ts < cutoff ?           │
                     └───┬─────────────────┬───┘
                         │                 │
                     NO (recent)        YES (stale)
                         │                 │
                         ▼                 ▼
              ┌───────────────────┐   ┌──────────────────────┐
              │ Append to @{kept} │   │ DRY_RUN == True ?    │
              │ continue          │   └──┬──────────────┬────┘
              └───────────────────┘      │              │
                                      YES│              │NO
                                         ▼              ▼
                               ┌──────────────────┐  ┌──────────────────┐
                               │ 🔎 Log "would    │  │ 🗑️  Delete      │
                               │ delete: X/Y"     │  │ Project(space/Y) │
                               │ Append to        │  │ Append to        │
                               │ @{deleted}       │  │ @{deleted}       │
                               │ (no API call)    │  │ (ignore errors)  │
                               └──────────────────┘  └──────────────────┘
                         │                                │
                         └────────────┬───────────────────┘
                                      ▼
                        ┌─────────────────────────────┐
                        │ Log final counts:           │
                        │   deleted=N kept_recent=M   │
                        │ Return @{deleted}           │
                        └─────────────────────────────┘
```

### Cleanup safety matrix

| Project name example | Matches regex? | Older than retention? | DRY_RUN | Action |
|----------------------|---------------|----------------------|---------|--------|
| `my_project` (base) | ❌ no suffix | — | — | ✅ SKIP (never deleted) |
| `other_team_project` (different base) | ❌ different base | — | — | ✅ SKIP |
| `my_project_20260414_163000` | ✅ | No (recent) | — | ✅ KEEP |
| `my_project_20260101_120000` | ✅ | Yes (stale) | `True` | 🔎 Logged only |
| `my_project_20260101_120000` | ✅ | Yes (stale) | `False` | 🗑️ Deleted |
| `my_project_notatimestamp` | ❌ bad suffix | — | — | ✅ SKIP |
| `my_project_20260101_999999` | ✅ but parse fails | — | — | ⚠️ SKIP + warn |

---

## Complete entry-point matrix

| Command | Behavior |
|---------|----------|
| `make robot-run-all-tests TAGS=oracle` | **Case 2** (A/B/C based on state) — safe, idempotent. This is the default; `PROJECT_SPACE_SETUP=True` is implicit. |
| `make robot-run-all-tests TAGS=oracle PROJECT_SPACE_SETUP=False` | **Case 1** — verify only. Skips Snaplex registration + `.slpropz` download. Fast-fail if project space is missing. |
| `make robot-run-all-tests TAGS=oracle FORCE_RECREATE_PROJECT_SPACE=True` | **Case 3** — destructive. Prompts for confirmation. |
| `make robot-run-all-tests TAGS=oracle FORCE_RECREATE_PROJECT_SPACE=True FORCE_CONFIRM=yes` | **Case 3** — destructive, no prompt (CI). |
| `make cleanup-stale-projects` | **Case 4** — delete legacy timestamped projects (7d default). |
| `make cleanup-stale-projects RETENTION_DAYS=14 DRY_RUN=True` | **Case 4** — preview only. |

---

## Snaplex name-collision failure (HTTP 409 — early-fail guard)

Snaplex names are **unique within a SnapLogic org**. If `GROUNDPLEX_NAME` in
your `.env` matches an existing Snaplex that lives under a *different* project
space (typical: a previous run left it behind in another space), the create
call returns HTTP 409. The framework no longer treats this as success — it
fails the `Create Snaplex In Project Space` test loudly with a multi-line
console message:

```
============================================================
❌ Snaplex '<name>' could NOT be created at requested path.
============================================================

💥 Why this failed (HTTP 409 Conflict):
  A Snaplex named '<name>' already exists somewhere in this org.
  Snaplex names are unique within an org. The existing Snaplex is
  NOT under the requested path:
    <project_space>/shared
  so the downstream .slpropz download would fail with 404.

💡 Fix one of these:
  1) Change GROUNDPLEX_NAME in your .env to a value that is
     unique within the org (e.g. add a suffix that matches your
     project space).
  2) Delete the existing Snaplex '<name>' from its current
     location in the SnapLogic UI, then re-run.
  3) Set PROJECT_SPACE in .env to the project space where the
     existing Snaplex already lives, then re-run.
============================================================
```

Defined in `snaplogic-common-robot` → keyword `Create Snaplex` → 409 branch.

---

## Where the logic lives

| Concern | File |
|---------|------|
| Safe idempotent branching | `snaplogic-common-robot` library → `snaplogic_apis_keywords/snaplogic_keywords.resource` → keyword `Ensure Project Setup Safe` |
| Destructive override | same file → keyword `Ensure Project Setup Safe` (FORCE_RECREATE branch) |
| Snaplex 409 early-fail | same file → keyword `Create Snaplex` |
| Cleanup keyword | same file → keyword `Cleanup Old Timestamped Projects` (legacy) |
| Confirmation prompt | `{{cookiecutter.primary_pipeline_name}}/makefiles/common_services/Makefile.testing` → target `robot-run-tests` |
| Cleanup make target | same file → target `cleanup-stale-projects` |
| Verify-only test + helpful failure message | `{{cookiecutter.primary_pipeline_name}}/test/suite/pipeline_tests/env_setup.robot` → `Validate Project Space Exists` |
| Cleanup test wrapper | same file → `Cleanup Stale Timestamped Projects` |
