# Groundplex Lifecycle & Configuration Changes

This guide documents how the framework-managed Groundplex container behaves
across test runs — especially when you change Groundplex-related settings
in `.env` between runs. It also explains the "one container per machine"
constraint and the trade-offs behind it.

Related guides:
- [`network_preflight_check.md`](./network_preflight_check.md) — the
  `check-network` probe that runs before every `launch-groundplex`.
- [`robot_run_all_tests_flow.md`](./robot_run_all_tests_flow.md) — full
  end-to-end workflow including Phase 0 (external-plex guard + pre-swap)
  and Phase 2 (Groundplex start).
- [`project_space_setup_safe_mode.md`](./project_space_setup_safe_mode.md) —
  idempotent project-space/project setup.
- [`robot_framework_test_execution_flow.md`](./robot_framework_test_execution_flow.md) —
  phase-by-phase Robot Framework execution flow.

---

## TL;DR

> **One Docker Groundplex container per machine, always named `snaplogic-groundplex`.
> Changing `.env` configs = the framework swaps out the old container for a new one.
> Parallel Groundplexes = not supported by the current framework.**

---

## The one-container constraint

The container name is **hardcoded** in
`docker/groundplex/docker-compose.groundplex.yml`:

```yaml
services:
  snaplogic-groundplex:
    container_name: snaplogic-groundplex   # ← same name every time
```

Docker does not allow two running containers to share the same name. So:

- **Run 1** starts `snaplogic-groundplex` → it owns that name on your host.
- **Run 2 with different `.env` values** → docker-compose detects an
  existing container with that name, sees the mount path has changed, and
  **replaces it** (stops + removes + recreates with the new mount).
- The old JCC process dies in the swap. You cannot keep both alive at the
  same time through this framework.

This is a deliberate design choice: the framework is optimized for the
single-dev-laptop workflow where each engineer tests against one
Groundplex at a time. It is not a cluster-management tool.

---

## Three scenarios and what the framework does

The examples below assume `PROJECT_SPACE_SETUP=True` (the default),
`EXTERNAL_GROUNDPLEX` is NOT set in `.env` (the plex is framework-managed),
and that `launch-groundplex` self-healing is active (current behavior).

### Scenario A — You change nothing and re-run

```bash
make launch-groundplex   # run 1
make launch-groundplex   # run 2, same .env
```

**Behavior:** fast path.

1. External-plex guard: `EXTERNAL_GROUNDPLEX` not set → passes.
   No local container or `.slpropz` missing? Soft heuristic warning on
   first run only (5s pause, then continues). On re-runs both exist → skipped.
2. `check-network` passes (~5 s).
3. Pre-swap check: same mount → `✅ already attached` → no prompt.
4. `.slpropz` already exists on disk → auto-createplex skipped.
5. `docker compose up` — same mount as before → **no-op**.
6. `groundplex-status` — JCC already running → immediate ✅.

**Total:** ~5–10 s. Zero side effects. Zero cloud-side changes.

---

### Scenario B — You change ONLY `GROUNDPLEX_NAME` (or any other non-NAME value that would trigger a fresh slpropz)

Actually, the mount path in `docker-compose.groundplex.yml` is keyed to
`GROUNDPLEX_NAME`, so only `GROUNDPLEX_NAME` changes force a container
recreate. (See Scenario C for the gotcha when the NAME stays but other
values change.)

```
# Run 1
GROUNDPLEX_NAME=plex_A → make launch-groundplex

# Edit .env → GROUNDPLEX_NAME=plex_B

# Run 2
make launch-groundplex
```

**Behavior — clean path.**

1. External-plex guard passes (no `EXTERNAL_GROUNDPLEX` set).
2. `check-network` passes.
3. Pre-swap check: mount path changed → **REPLACING banner** + prompt
   (bypass with `FORCE_REPLACE=yes`, auto-proceed in CI).
4. Slpropz guard reads new `GROUNDPLEX_NAME=plex_B` → looks for
   `test/.config/plex_B.slpropz` → **not found**.
5. **Auto-createplex fires** (the self-healing branch):
   - Registers a NEW Snaplex `plex_B` in the org (HTTP 409 failure if
     the name collides with an existing Snaplex elsewhere in the org —
     see [`project_space_setup_safe_mode.md`](./project_space_setup_safe_mode.md)
     for the collision handling).
   - Downloads `plex_B.slpropz`.
6. `docker compose --profile gp up -d snaplogic-groundplex`.
7. Docker detects the mount path changed (`plex_A.slpropz` → `plex_B.slpropz`)
   → **recreates** the container.
8. Old JCC dies. New JCC boots reading `plex_B.slpropz` → registers as
   node of `plex_B`.

#### State transition

```
BEFORE                                  AFTER
─────────────────────                  ─────────────────────
snaplogic-groundplex container         snaplogic-groundplex container
  └── JCC attached to plex_A             └── JCC attached to plex_B  ✅
SnapLogic Cloud:                       SnapLogic Cloud:
  plex_A [1 active node]                 plex_A [node=offline]  ← orphan, auto-cleaned
                                         plex_B [1 active node]  ✅
```

**⚠️ Cloud-side residue:**

- The old `plex_A` Snaplex still EXISTS in SnapLogic Cloud; only its node
  record goes offline. Cloud auto-deregisters the stale node in ~5–15 min.
- The old `plex_A.slpropz` file remains on your disk (harmless; safe to
  delete manually: `rm test/.config/plex_A.slpropz`).

---

### Scenario C — You change `GROUNDPLEX_ENV`, `RELEASE_BUILD_VERSION`, or `SNAP_PLEX_LOCATION` but keep the SAME `GROUNDPLEX_NAME`

```bash
# Run 1
GROUNDPLEX_NAME=plex_A, GROUNDPLEX_ENV=dev1 → make launch-groundplex

# Edit .env → GROUNDPLEX_ENV=dev2 (GROUNDPLEX_NAME unchanged)

# Run 2
make launch-groundplex
```

**Behavior — silent stale config bug.**

1. `check-network` passes.
2. Slpropz guard reads `GROUNDPLEX_NAME=plex_A` →
   `test/.config/plex_A.slpropz` → **exists from run 1** → auto-createplex
   is skipped.
3. ⚠️ **The `.slpropz` on disk still has the OLD `dev1` config** — the
   framework does not detect that other `.env` vars changed.
4. `docker compose up` sees the mount path hasn't changed → **no-op**; the
   same container keeps running with the OLD JCC still attached to the
   OLD config.
5. Your test run executes pipelines on the OLD Groundplex. The `.env`
   change is **silently ignored**.

#### How to force a refresh

| Option | Command |
|--------|---------|
| Delete the stale slpropz; self-healing will re-fetch | `rm test/.config/plex_A.slpropz && make launch-groundplex` |
| Stop + restart the Groundplex explicitly | `make restart-groundplex` |
| Full clean re-run with createplex | `make robot-run-all-tests TAGS="<tags>"` |

---

### Scenario D — You change MULTIPLE values including `GROUNDPLEX_NAME`

Example: `GROUNDPLEX_NAME`, `GROUNDPLEX_ENV`, AND `SNAP_PLEX_LOCATION` all change.

**Behavior — Scenario B wins.** Because `GROUNDPLEX_NAME` changed, the
slpropz filename changes, auto-createplex fires, and the new slpropz picks
up ALL the new values (env, location, version, etc.) when it's generated.
Container is recreated with the new mount. Works cleanly.

The takeaway: **as long as `GROUNDPLEX_NAME` changes along with other
values, you get the clean path.** It's only when `GROUNDPLEX_NAME` stays
fixed and OTHER values change that Scenario C's silent-stale gotcha bites.

---

## Summary table

| Changed in `.env` | `.slpropz` file state | Container action | JCC re-registers? | Gotchas |
|-------------------|------------------------|------------------|-------------------|---------|
| Nothing (re-run) | exists, matches | no-op | No — same container keeps running | None |
| `GROUNDPLEX_NAME` (A → B) | A exists, B missing | **recreates** (mount path changed) | ✅ Yes — new JCC, new plex | Old plex shows orphaned node in SnapLogic UI until cloud auto-cleans |
| `GROUNDPLEX_ENV`, `RELEASE_BUILD_VERSION`, or `SNAP_PLEX_LOCATION`, same NAME | A exists with OLD content | no-op (mount path unchanged) | ❌ **No — stale!** | `.env` change is silently ignored. Fix: `rm .slpropz` or `make restart-groundplex` |
| Multiple values including `GROUNDPLEX_NAME` | A exists, new-name missing | **recreates** | ✅ Yes | Scenario B applies — clean swap |
| `.slpropz` deleted manually | missing | **recreates** (self-healing auto-createplex) | ✅ Yes | None — clean |

---

## What you'll see in the terminal when a swap happens

The pre-swap check runs via the `check-groundplex-swap` target, which is
called in two places:

1. **Phase 0b of `robot-run-all-tests`** — runs BEFORE any cloud resources
   are created (Phase 1). If the user declines, no Snaplex is registered,
   no `.slpropz` is downloaded, and no project space is touched. The caller
   then passes `SWAP_CHECK_DONE=1` to `launch-groundplex` in Phase 2 to
   avoid double-prompting.
2. **Inside `launch-groundplex`** — runs as step 3 of the pre-flight
   (after external-plex guard and check-network). Skipped when
   `SWAP_CHECK_DONE=1` is set by the caller.

When the check detects that the existing `snaplogic-groundplex` container
is attached to a Snaplex **different from** what your current `.env` is
asking for, it prints a loud multi-line banner:

```
🔎 Checking for existing Groundplex container before launch...

⚠️  ============================================================
⚠️   REPLACING EXISTING GROUNDPLEX CONTAINER
⚠️  ============================================================

   This host can run only ONE 'snaplogic-groundplex' container
   at a time (the container name is hardcoded in docker-compose).

     CURRENT (will be stopped + removed):  demo_project_gp_3
     NEW     (will be started):            demo_project_gp_4

   After the swap:
     • The OLD Snaplex [demo_project_gp_3] in SnapLogic Cloud
       will show an orphan/offline node record for ~5–15 min
       (cloud auto-cleans the node, but the Snaplex DEFINITION
       itself stays in the UI until you delete it manually).
     • The OLD local .slpropz stays on disk as clutter;
       safe to remove with:
         rm test/.config/demo_project_gp_3.slpropz

   Continue with the replacement? (type 'yes' to proceed, anything else aborts):
```

Everything in the banner is **derived at runtime**:
- `CURRENT` — extracted from the running container's mount path via
  `docker inspect`.
- `NEW` — extracted from the `GROUNDPLEX_NAME=` line in your current `.env`.
- The `rm` suggestion uses the actual CURRENT name.

The banner only appears when there is an actual swap. In two other cases,
you get a short informational line instead:

| State | Message |
|-------|---------|
| No container exists yet | `ℹ️ No existing Groundplex container — fresh start.` |
| Container exists, same mount as new `.env` | `✅ Existing container is already attached to [<name>] — no swap needed.` |

### Bypass the prompt

| Situation | How |
|-----------|-----|
| Interactive shell, you're sure | Type `yes` at the prompt |
| Scripted / CI | Non-interactive shells auto-proceed with a `▶ Non-interactive shell (CI) — proceeding automatically.` notice |
| Interactive but you want to suppress the prompt | `FORCE_REPLACE=yes make launch-groundplex` |

### Always-on footer

Regardless of whether a swap happened or not, every successful
`launch-groundplex` run ends with:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✅ Groundplex ACTIVE:  <current-name-from-env>
   Container:          snaplogic-groundplex
   (only one Groundplex container per host at a time)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

This tells you unambiguously which Snaplex the local Groundplex is now
attached to — handy when debugging why tests seem to be running against
the wrong environment.

---

## Cloud-side state accumulates even though containers don't

Even though only one container can run locally, **Snaplex definitions
registered in SnapLogic Cloud do not get cleaned up** when you switch.
Each new `GROUNDPLEX_NAME` leaves behind:

- A Snaplex definition in its project space (stays until you delete it
  manually in the SnapLogic UI).
- An offline node record on that Snaplex (auto-cleared by cloud in ~5–15 min).
- The old `.slpropz` file on your disk (harmless; just clutter).

For long-lived test environments, periodic manual cleanup in the SnapLogic
UI is a good practice.

---

## External Groundplex — `EXTERNAL_GROUNDPLEX=yes`

If your Groundplex is managed outside this framework (Cloud-hosted,
shared, customer-hosted, etc.), add `EXTERNAL_GROUNDPLEX=yes` to `.env`:

```bash
GROUNDPLEX_NAME=my-shared-plex
EXTERNAL_GROUNDPLEX=yes
```

**Effect:**

| Target | Behavior |
|--------|----------|
| `make robot-run-all-tests` | ❌ Hard block — steers you to `robot-run-tests-no-gp` |
| `make launch-groundplex` | ❌ Hard block — cannot start a local container for an external plex |
| `make robot-run-tests-no-gp` | ✅ Works — skips all Groundplex management (Phase 2) |
| `check-groundplex-swap` | Skipped — swap check doesn't apply to external plexes |

**If you don't add the flag:** everything still works. The framework will
detect no local Groundplex history (no container + no `.slpropz`) and
show a soft warning with a 5-second pause before continuing. Your runs
will just take slightly longer on the first invocation.

To undo, remove the `EXTERNAL_GROUNDPLEX` line from `.env`.

---

## What's supported vs not

| Scenario | Supported? |
|----------|-----------|
| Switch between Groundplex configs serially (edit `.env`, re-launch, old one swapped out) | ✅ Yes — clean swap |
| Test against two different Snaplexes **in SnapLogic Cloud** at different times | ✅ Yes — cloud side has no limit |
| Run two `snaplogic-groundplex` Docker containers side-by-side on the same host | ❌ No — container name collision |
| Run one framework-managed container AND point to an external Groundplex via `robot-run-tests-no-gp` | ✅ Yes — separate concerns, no collision |
| Use an external Groundplex exclusively (`EXTERNAL_GROUNDPLEX=yes`) | ✅ Yes — use `robot-run-tests-no-gp` |
| Run two independent test suites simultaneously on the same host | ❌ Not recommended — they share the same Docker container and `.env` |

---

## What if you genuinely need two local Groundplexes?

Not supported out of the box. You would need to:

1. Duplicate `docker/groundplex/docker-compose.groundplex.yml` with a
   different `container_name` (e.g., `snaplogic-groundplex-b`).
2. Introduce a second set of env vars (e.g., `GROUNDPLEX_NAME_B`,
   `SNAP_PLEX_LOCATION_B`) and a second `.slpropz` path.
3. Add parallel Makefile targets (`launch-groundplex-b`,
   `stop-groundplex-b`, etc.) and wire them into a new workflow target.

That is a non-trivial framework extension (~100–150 lines across the
Makefile, docker-compose, and possibly the Robot keywords). Worth doing
only if you have a real use case — e.g., testing a pipeline that chains
across two Groundplexes.

---

## Practical recipes

### Clean switch to a new Snaplex / project space

Just edit the relevant vars in `.env` (change at minimum `GROUNDPLEX_NAME`
to keep the clean path) and run:

```bash
make launch-groundplex
```

Then delete the old Snaplex in the SnapLogic UI when convenient.

### Force-refresh the current Groundplex after editing non-NAME values

```bash
# Pick one:
rm test/.config/$(grep GROUNDPLEX_NAME .env | cut -d= -f2).slpropz && make launch-groundplex
# or
make restart-groundplex
```

### Nuclear reset — drop everything local and start over

```bash
make stop-groundplex
rm -f test/.config/*.slpropz
make launch-groundplex
```

### Swap Groundplexes in CI without the interactive prompt

```bash
FORCE_REPLACE=yes make launch-groundplex
```

Or, if the CI job runs with a non-interactive shell (no TTY), the prompt
is auto-skipped anyway — the framework detects `! [ -t 0 ]` and proceeds
with a `▶ Non-interactive shell (CI) — proceeding automatically.` notice.

---

## Where the logic lives

| Concern | File |
|---------|------|
| Hardcoded container name | `{{cookiecutter.primary_pipeline_name}}/docker/groundplex/docker-compose.groundplex.yml` |
| `launch-groundplex` self-healing (external-plex guard, check-network, pre-swap, slpropz guard, auto-createplex) | `{{cookiecutter.primary_pipeline_name}}/makefiles/common_services/Makefile.groundplex` |
| `check-groundplex-swap` (pre-swap banner + prompt, `EXTERNAL_GROUNDPLEX` skip) | `Makefile.groundplex` |
| `restart-groundplex` / `stop-groundplex` | `Makefile.groundplex` |
| Phase 0 pre-swap orchestration + `EXTERNAL_GROUNDPLEX` hard block for `robot-run-all-tests` | `{{cookiecutter.primary_pipeline_name}}/makefiles/common_services/Makefile.testing` |
| `sync-env` (.env bind-mount reconcile + `snaplogic-common-robot` version-floor guard) | `{{cookiecutter.primary_pipeline_name}}/makefiles/common_services/Makefile.docker` |
| `SNAPLOGIC_COMMON_ROBOT_MIN_VERSION` floor variable | `Makefile.docker` (top of file) |
| `EXTERNAL_GROUNDPLEX` documented default | `{{cookiecutter.primary_pipeline_name}}/.env.example` |
| Snaplex registration (fails loudly on 409 name collision) | `snaplogic-common-robot` library → `Create Snaplex` keyword |
