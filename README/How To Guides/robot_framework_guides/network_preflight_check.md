# Network Pre-Flight Check

This guide documents the `make check-network` target — a diagnostic probe
that validates DNS, HTTPS reachability, and TLS trust for the SnapLogic
Cloud endpoint configured in your `.env` file (the `URL=` value), running
from inside the tools container.

It also explains how the check is automatically wired into
`make launch-groundplex` so you fail fast instead of watching the JCC boot
timeout loop when the real problem is a corporate firewall, DNS issue,
or SSL inspection.

---

## Why this exists

Before this check existed, a corporate-network problem (WSL DNS, port-443
firewall, MITM SSL proxy) would manifest as this unhelpful sequence:

```
Launching Groundplex...
✔ Container snaplogic-groundplex  Started
🔁 Checking Snaplex JCC status ... 20 attempts, 10s interval
⏱️ Attempt 1... ❌ JCC not running (PID file not found). Retrying in 10s...
⏱️ Attempt 2... ❌ JCC not running (PID file not found). Retrying in 10s...
...
⏱️ Attempt 20... ❌ JCC failed to start after 20 attempts.
```

You'd wait 200 seconds, then have to dig through `docker logs
snaplogic-groundplex` to discover the real cause — usually a single line
buried in the JCC startup log like `PKIX path building failed` or
`UnknownHostException`.

`check-network` surfaces the root cause in 5–30 seconds instead, with a
copy-paste-ready fix hint.

---

## What it checks

| Step | Probe | Catches |
|------|-------|---------|
| **1. DNS resolution** | `getent hosts <host>` inside the tools container | Broken `/etc/resolv.conf` in WSL; corporate DNS not propagated; firewall blocking DNS |
| **2. HTTPS reachability** | `curl --max-time 10 https://<host>/` inside the tools container | Port 443 blocked by corporate firewall; connection timeout; proxy required |
| **3. TLS trust** | `curl --cacert /etc/ssl/certs/ca-certificates.crt https://<host>/` inside the tools container | Corporate SSL inspection (MITM proxy) re-signing certs — the #1 cause of JCC failure on Windows/WSL |

Probes run against **one host** — whatever is set in your `.env` `URL`
variable (the target ends the hostname by stripping `https://` and the
path). Nothing is hardcoded: if you switch pods (e.g. `elastic.snaplogic.com`
→ `cdn.elastic.snaplogic.com` → `staging.snaplogic.com`), the probes follow
automatically.

If `URL=` is missing or blank in `.env`, the check fails fast with:

```
❌ URL is not set in .env — cannot run network check.
   Add a line like 'URL=https://elastic.snaplogic.com' to .env and retry.
```

All probes run **inside the tools container**, not on your host, so the
results reflect exactly what the framework runtime will see. (WSL host
networking and container networking can differ in subtle ways.)

---

## Logic flow

```
make check-network
      │
      ▼
┌───────────────────────────────────────────────────────┐
│ Step 0: is the tools container running?               │
└───────────────────┬───────────────────────────────────┘
                    │
           ┌────────┴────────┐
           │                 │
        No │              Yes│
           ▼                 ▼
    ❌ Exit 1          ┌───────────────────────────────┐
    "Start it with:"  │ Read URL= from .env           │
    "make start-tools │                               │
     -service-only"   │   URL_RAW = (everything after │
                      │              the first =)     │
                      │   HOST    = strip https:// +  │
                      │             path              │
                      └──────────┬────────────────────┘
                                 │
                     ┌───────────┴───────────┐
                     │                       │
                URL_RAW              URL_RAW
                is empty             is set
                     │                       │
                     ▼                       ▼
             ❌ Exit 1              ┌──────────────────┐
             "URL is not set"       │ Probe the host:  │
             "Add URL=https://...   │   [1/3] DNS      │
              to .env"              │   [2/3] HTTPS    │
                                    │   [3/3] TLS      │
                                    └─────┬────────────┘
                                          │
                              ┌───────────┴───────────┐
                              │                       │
                          All pass             Anything fails
                              │                       │
                              ▼                       ▼
                       ✅ Exit 0             ❌ Exit 1
                       "All checks passed"   "N check(s) failed.
                                              Typical fixes: ..."
```

### The three probes, in plain English

| Step | What it really runs | What it's asking | Fails when... |
|------|---------------------|------------------|---------------|
| **1. DNS** | `getent hosts $HOST` | "Can we turn the hostname into an IP?" | WSL's `/etc/resolv.conf` is broken, or corporate DNS is unreachable |
| **2. HTTPS** | `curl --max-time 10 $URL` | "Can we open a TLS connection and get any HTTP response?" | Port 443 is firewalled, or the handshake times out |
| **3. TLS trust** | `curl --cacert /etc/ssl/certs/ca-certificates.crt $URL` | "Is the server's cert signed by a CA we trust by default?" | A corporate MITM proxy re-signed the cert with an internal CA (the #1 cause of `PKIX path building failed` in Groundplex) |

---

## Five worked examples

### Example 1 — happy path

**`.env`:**
```
URL=https://elastic.snaplogic.com
```

**Output:**
```
Target derived from .env URL:
  URL:  https://elastic.snaplogic.com
  Host: elastic.snaplogic.com

[1/3] DNS resolution (inside tools container)
  ✅ elastic.snaplogic.com → 52.1.2.3

[2/3] HTTPS reachability (port 443)
  ✅ https://elastic.snaplogic.com → HTTP 200

[3/3] TLS certificate trust check for elastic.snaplogic.com
  Issuer: C = US, O = "DigiCert Inc", CN = DigiCert TLS RSA SHA256 2020 CA1
  ✅ Cert chain verified against system CA bundle — Groundplex TLS handshake should succeed

✅ All network checks passed — Groundplex should be able to reach SnapLogic Cloud.
```

**Exit code:** `0` → `launch-groundplex` continues to slpropz guard + `docker compose up`.

---

### Example 2 — different pod, still works

**`.env`:**
```
URL=https://staging.snaplogic.com
```

**Output:** (same three probes, but targeting staging)
```
Target derived from .env URL:
  URL:  https://staging.snaplogic.com
  Host: staging.snaplogic.com

[1/3] ✅ staging.snaplogic.com → 10.20.30.40
[2/3] ✅ https://staging.snaplogic.com → HTTP 302
[3/3] ✅ Cert chain verified
✅ All network checks passed
```

**Key insight:** no code change needed to support a new pod. Change `.env` → probes follow automatically.

---

### Example 3 — corporate SSL inspection (the #1 customer issue)

**`.env`:**
```
URL=https://cdn.elastic.snaplogic.com
```

**Output:**
```
Target derived from .env URL:
  URL:  https://cdn.elastic.snaplogic.com
  Host: cdn.elastic.snaplogic.com

[1/3] ✅ cdn.elastic.snaplogic.com → 104.18.10.200
[2/3] ✅ https://cdn.elastic.snaplogic.com → HTTP 302
[3/3] TLS certificate trust check for cdn.elastic.snaplogic.com
  Issuer: C = US, ST = MN, O = <CorporateName>, CN = <CorporateName> Internal Root CA
  ❌ Cert chain verification FAILED — Groundplex will reject this TLS handshake
     Symptom in groundplex logs: 'PKIX path building failed'
     Fix: import your corporate CA into the Groundplex container's Java truststore.

❌ 1 check(s) failed.
```

**Exit code:** `1` → `launch-groundplex` aborts in ~10 seconds (not 200 seconds).

**Diagnostic fingerprint:** Step 2 passes but Step 3 fails. Step 2 uses curl's default cert validation which accepts the proxy's re-signed cert; Step 3 uses strict verification against the system CA bundle, which catches the MITM.

---

### Example 4 — missing URL in `.env`

**`.env`:**
```
# Oops, URL commented out
# URL=https://elastic.snaplogic.com
ORG_NAME=my_org
```

**Output:**
```
🌐 SnapLogic network pre-flight check
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
❌ URL is not set in .env — cannot run network check.
   Add a line like 'URL=https://elastic.snaplogic.com' to .env and retry.
```

**Exit code:** `1` → fails fast with a concrete fix instruction, no garbage probes against empty hosts.

---

### Example 5 — DNS broken in WSL (cascading failure)

**`.env`:**
```
URL=https://elastic.snaplogic.com
```

**Output:**
```
Target derived from .env URL:
  URL:  https://elastic.snaplogic.com
  Host: elastic.snaplogic.com

[1/3] DNS resolution (inside tools container)
  ❌ elastic.snaplogic.com — DNS resolution FAILED

[2/3] HTTPS reachability (port 443)
  ❌ https://elastic.snaplogic.com — NOT reachable (timeout, connection refused, or TLS error)

[3/3] TLS certificate trust check for elastic.snaplogic.com
  ❌ Cert chain verification FAILED — Groundplex will reject this TLS handshake

❌ 3 check(s) failed.
```

**Diagnostic fingerprint:** all three steps fail. DNS dies → HTTPS can't resolve → TLS handshake never starts. The fix is in `/etc/resolv.conf` inside WSL (add corporate DNS servers), not in any SnapLogic config.

**Exit code:** `1` → `launch-groundplex` aborts immediately.

---

## Design rationale

| Design choice | Why |
|---------------|-----|
| **Single host from `.env`** | No hardcoded assumption about which SnapLogic pod you're on. Customer environments vary (elastic / cdn / staging / private pods). |
| **Probes run INSIDE the tools container** | WSL host networking ≠ container networking. We must test what the framework runtime actually sees. |
| **`curl --cacert` instead of issuer pattern-matching** | Robust against any legit public CA (DigiCert, GoDaddy, Let's Encrypt, Amazon, Sectigo, etc.). Avoids brittle hardcoded allowlists that break whenever SnapLogic rotates to a new CA vendor. |
| **Fail-fast on missing URL** | A silent fallback to a default pod would mislead users on non-default pods. Better to force them to check `.env`. |
| **Exit code non-zero on failure** | CI-friendly; chains cleanly with `launch-groundplex` and `robot-run-all-tests`, so a failed check stops the pipeline at the right step. |
| **`SKIP_NETWORK_CHECK=1` escape hatch** | Respects fast dev loops when connectivity is known-good — ~5s added per run is negligible but measurable over many iterations. |

---

## Usage

### Standalone diagnostic

```bash
make check-network
```

Example output on a working setup:

```
🌐 SnapLogic network pre-flight check
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Target derived from .env URL:
  URL:  https://cdn.elastic.snaplogic.com
  Host: cdn.elastic.snaplogic.com

[1/3] DNS resolution (inside tools container)
  ✅ cdn.elastic.snaplogic.com → 2606:4700::6812:9b9

[2/3] HTTPS reachability (port 443)
  ✅ https://cdn.elastic.snaplogic.com → HTTP 302

[3/3] TLS certificate trust check for cdn.elastic.snaplogic.com
  Issuer: C = US, ST = Arizona, L = Scottsdale, O = "GoDaddy.com, Inc.", ...
  ✅ Cert chain verified against system CA bundle — Groundplex TLS handshake should succeed

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✅ All network checks passed — Groundplex should be able to reach SnapLogic Cloud.
```

### Automatic integration with `launch-groundplex`

The check runs automatically at the start of `launch-groundplex`, which is
itself now **self-healing** — if the `.slpropz` Groundplex config file is
missing, the target will auto-run the createplex phase to register the
Snaplex in SnapLogic Cloud and download the config, before the Docker
container is started.

```
make launch-groundplex
        │
        ▼
  🛑 External-plex guard
     If EXTERNAL_GROUNDPLEX=yes in .env → ❌ Exit 1
       (tells user to run 'make robot-run-tests-no-gp' instead)
     If flag is not set but no local container AND no .slpropz exist
       → ⚠️ soft warning (5s pause, Ctrl+C to abort, then continues)
        │
        ▼
  🌐 check-network (DNS / HTTPS / TLS probes)
     Skip with SKIP_NETWORK_CHECK=1
        │
  ┌─────┴──────────┐
  │                │
 Pass             Fail
  │                │
  ▼                ▼
Pre-swap check    ❌ Exit 1 with fix hints — NEVER boots
  │               the Groundplex container
  │               (saves 200s of JCC timeout waiting)
  │
  ▼
🔎 Pre-swap check (delegates to 'check-groundplex-swap' target)
     Skipped when caller already ran it and set SWAP_CHECK_DONE=1
     (e.g., robot-run-all-tests runs this as Phase 0 and passes
      SWAP_CHECK_DONE=1 through to Phase 2 to avoid double-prompts)
  │
  ├─► No existing container            → ℹ️ "fresh start" message
  ├─► Existing, same mount as new .env → ✅ "already attached" message
  └─► Existing, DIFFERENT mount        → ⚠️ Multi-line REPLACING banner
                                           Prompts for 'yes' (interactive)
                                           Auto-proceeds (non-TTY / CI)
                                           Bypass with FORCE_REPLACE=yes
                                           On decline: exit 1, NO cloud changes
  │
  ▼
slpropz directory cleanup
  │
  ├─► Is test/.config/${GROUNDPLEX_NAME}.slpropz a stale DIRECTORY?
  │     └─► YES → rm -rf it (auto-cleanup from prior failed run)
  │
  ├─► Does test/.config/${GROUNDPLEX_NAME}.slpropz exist as a FILE?
  │     │
  │     ├─► NO  → auto-run createplex:
  │     │         make robot-run-tests TAGS="createplex"
  │     │         (registers Snaplex in SnapLogic + downloads .slpropz)
  │     │         Skip with SKIP_CREATEPLEX=1
  │     │
  │     └─► YES → fast path, no createplex needed
  │
  ▼
docker compose --profile gp up -d snaplogic-groundplex
  │
  ▼
groundplex-status  (JCC readiness loop)
  │
  ▼
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✅ Groundplex ACTIVE: <name-from-env>
   Container: snaplogic-groundplex
   (only one Groundplex container per host at a time)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

> **Ordering note:** the pre-swap check runs **BEFORE** the slpropz
> guard / auto-createplex, so if the user declines the swap prompt, NO
> cloud resources are created. This is a deliberate correction from an
> earlier version of the flow that ran the pre-swap check last.

Two things this buys you:

- **Standalone usability.** `make launch-groundplex` can now be run as a
  one-shot command from a cold state — no need to run
  `make robot-run-all-tests` first just to seed the `.slpropz`.
- **No behavior change inside `robot-run-all-tests`.** Phase 2 of the full
  workflow still does the same thing; the auto-createplex branch simply
  short-circuits because Phase 1 has already downloaded the file.

Since `launch-groundplex` is invoked by `make robot-run-all-tests` as Phase
2, the pre-flight happens on every framework-managed run without any extra
action from you.

---

## Escape hatches — skip checks on fast re-runs

`launch-groundplex` exposes two opt-out flags for quick dev loops when
you're re-running the same thing many times and know the environment is
already in good shape.

### `SKIP_NETWORK_CHECK=1` — skip DNS/HTTPS/TLS probes

```bash
SKIP_NETWORK_CHECK=1 make launch-groundplex
# or
SKIP_NETWORK_CHECK=1 make robot-run-all-tests TAGS=oracle
```

Output confirms: `⏩ SKIP_NETWORK_CHECK=1 — skipping pre-flight network check`.

### `SKIP_CREATEPLEX=1` — skip auto-createplex

When the `.slpropz` file is already on disk and you don't want
`launch-groundplex` to re-verify / re-register the Snaplex, set this flag:

```bash
SKIP_CREATEPLEX=1 make launch-groundplex
```

If the slpropz file is still missing when this flag is set,
`launch-groundplex` fails with a clear message rather than silently
auto-creating it:

```
❌ Groundplex config file not found: test/.config/<name>.slpropz
   SKIP_CREATEPLEX=1 was set, so createplex was not auto-run.
   To seed the file manually, run: make robot-run-all-tests TAGS="createplex"
```

### `SWAP_CHECK_DONE=1` — tell `launch-groundplex` the pre-swap check is already done

When a caller (e.g., `robot-run-all-tests` in its Phase 0, or
`robot-run-tests-no-gp` in specific recovery paths) has already run
`check-groundplex-swap` directly, it passes `SWAP_CHECK_DONE=1` through
to `launch-groundplex` so the swap check is not re-prompted. You
generally don't set this manually — it's an internal coordination flag
between orchestration targets.

### `EXTERNAL_GROUNDPLEX=yes` — declare your plex is externally managed

Add `EXTERNAL_GROUNDPLEX=yes` to `.env` when your Groundplex is managed
outside this framework (Cloud-hosted, shared, customer-hosted, etc.).
When set, `launch-groundplex` and `robot-run-all-tests` hard-block and
steer you to `robot-run-tests-no-gp`:

```bash
# In .env:
EXTERNAL_GROUNDPLEX=yes

# Then use:
make robot-run-tests-no-gp TAGS="oracle"
```

If the flag is **not** set but no local container or `.slpropz` exists, the
framework prints a soft warning (5s pause to Ctrl+C) but continues — this
covers first-run scenarios where the plex hasn't been created yet.

### `FORCE_REPLACE=yes` — bypass the Groundplex swap prompt

When the current container is attached to a different Snaplex than your
new `.env` requires, `launch-groundplex` prompts you to confirm the swap.
Set `FORCE_REPLACE=yes` to skip the prompt and proceed silently:

```bash
FORCE_REPLACE=yes make launch-groundplex
```

In non-interactive shells (no TTY — e.g., most CI), the prompt is skipped
automatically whether or not the flag is set. Setting the flag in CI just
suppresses the informational `▶ Non-interactive shell` notice.

### Combined

Flags can be combined for the fastest possible swap or re-launch of a
known-good container:

```bash
SKIP_NETWORK_CHECK=1 SKIP_CREATEPLEX=1 FORCE_REPLACE=yes make launch-groundplex
```

> **Note:** these flags only affect `launch-groundplex`. Running
> `make check-network` directly always runs the probe.

---

## Behavior matrix

| Scenario | Before this change | After this change |
|----------|---------------------|-------------------|
| Network OK, `.slpropz` OK | Works (200 s nominal) | Works (adds ~5 s for the check) |
| Corporate SSL inspection (MITM) | 200 s wait → `PKIX path building failed` in logs → confused user | **5–10 s** → `❌ Cert chain verification FAILED` with fix pointer |
| WSL DNS broken | 200 s wait → `UnknownHostException` in logs | **2–5 s** → `❌ DNS resolution FAILED` with fix pointer |
| Port 443 blocked by firewall | 200 s wait → `Connection timed out` in logs | **10–15 s** → `❌ HTTPS not reachable` with fix pointer |
| `.slpropz` stale directory | Fails with `IsADirectoryError` in a test step | Cleaned up automatically by `launch-groundplex` guard |
| **`.slpropz` missing (first run, standalone `make launch-groundplex`)** | ❌ Fails with "Run `make robot-run-all-tests` first" → user has to run a different command | **Self-heals** — auto-runs createplex to fetch the file, then proceeds |
| Fast re-run of known-good setup | 200 s nominal | Use `SKIP_NETWORK_CHECK=1` and/or `SKIP_CREATEPLEX=1` to strip ~5–30 s of pre-flight |

---

## Typical fix hints (printed on failure)

When the check fails, the final message points at the most common causes:

```
❌ N check(s) failed. Typical fixes:
   • DNS:   fix /etc/resolv.conf in WSL; add corporate DNS servers
   • HTTPS: unblock port 443 in corporate firewall; set HTTP_PROXY / HTTPS_PROXY env vars
   • TLS:   import corporate CA into the Groundplex container Java truststore
   • Windows/WSL setup guide: README/How To Guides/infra_setup_guides/windows/
```

---

## Where the logic lives

| Concern | File |
|---------|------|
| `check-network` target | `{{cookiecutter.primary_pipeline_name}}/makefiles/common_services/Makefile.docker` |
| `sync-env` target (bind-mount reconcile + library auto-upgrade guardrail) | `Makefile.docker` |
| Wiring into `launch-groundplex` | `{{cookiecutter.primary_pipeline_name}}/makefiles/common_services/Makefile.groundplex` |
| `EXTERNAL_GROUNDPLEX=yes` external-plex guard (hard block) + soft heuristic warning | `Makefile.groundplex` (`launch-groundplex`, `check-groundplex-swap`), `Makefile.testing` (`robot-run-all-tests`) |
| `check-groundplex-swap` target (pre-swap banner + prompt) | `Makefile.groundplex` |
| `SKIP_NETWORK_CHECK=1` / `SKIP_CREATEPLEX=1` / `FORCE_REPLACE=yes` / `SWAP_CHECK_DONE=1` flags | `Makefile.groundplex` (consumed in `launch-groundplex`) |
| Phase 0 pre-swap orchestration for `robot-run-all-tests` | `Makefile.testing` (calls `check-groundplex-swap`, then passes `SWAP_CHECK_DONE=1` to `launch-groundplex`) |

---

## Requirements

- Tools container must be running. Start it first with:
  ```bash
  make start-tools-service-only
  # or
  make start-services
  ```
  If it's not running, `check-network` exits with a clear message pointing
  at the fix.
- The tools container image must include `curl`, `openssl`, and `getent`
  (provided by the base image; no extra setup needed).

---

## Related guides

- [`project_space_setup_safe_mode.md`](./project_space_setup_safe_mode.md) —
  idempotent project-space setup semantics.
- [`robot_run_all_tests_flow.md`](./robot_run_all_tests_flow.md) —
  full end-to-end flow of `robot-run-all-tests`.
- [`groundplex_lifecycle.md`](./groundplex_lifecycle.md) — Groundplex
  container swap behavior, `FORCE_REPLACE`, and the `EXTERNAL_GROUNDPLEX`
  guard.
- [`robot_framework_test_execution_flow.md`](./robot_framework_test_execution_flow.md) —
  phase-by-phase Robot Framework execution flow.
- [`infra_setup_guides/windows/`](../infra_setup_guides/windows/) —
  WSL / corporate-network setup for Windows users.
