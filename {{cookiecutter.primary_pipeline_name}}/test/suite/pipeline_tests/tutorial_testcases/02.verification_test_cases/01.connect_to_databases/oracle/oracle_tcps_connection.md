# Oracle TCPS Connection Setup — Step-By-Step Walkthrough

Set up the Robot Framework to connect to a **customer-hosted Oracle database** using **TCPS (TLS-encrypted)** on port 2484, authenticating with an Oracle wallet.

This guide is structured the same way as the AWS SSO walkthrough — small, focused steps with a **cross-verification command** at the end of each so you confirm the previous step before moving on. Do **not** skip the verification commands; nine times out of ten a `DPY-4011` failure can be traced to one of them silently going wrong.

> 💡 **Skip this entirely if you're testing against the local Docker Oracle.** That uses plain TCP on port 1521 and needs no wallet. The framework defaults to plain-TCP mode when `ORACLE_WALLET_LOCATION` is empty.

---

## What You'll End Up With

By the end of this walkthrough:

- Wallet files placed in `test/suite/test_data/wallets/oracle/` on the host
- `env_files/database_accounts/.env.oracle` updated with TCPS connection settings
- The container sees the wallet at `/app/test/suite/test_data/wallets/oracle/`
- `make robot-run-tests-no-gp TAGS=connect_to_oracle_database_sample` connects to the customer Oracle and runs the connection test successfully

---

## Prerequisites

Before starting, confirm:

| # | What | Why |
|---|------|-----|
| 1 | You have the project cloned and Docker Desktop is running | The framework runs inside a Docker container |
| 2 | The customer's DBA team has provided you with the wallet files | You can't generate these yourself |
| 3 | You can connect to the customer's Oracle from your laptop manually (via Toad, DBeaver, or `sqlplus`) | Confirms your network path (VPN/Direct Connect) is already working |
| 4 | You know the customer's Oracle hostname, port (2484), service name, and your DB username + password | All required for the connection |

If any of those four are missing, stop and resolve them first — none of the steps below will fix them.

---

## Step 1 — Confirm You're At The Project Root

Open your terminal (WSL terminal on Windows, regular terminal on Mac/Linux) and run:

```bash
pwd
ls
```

**Expected output:**

```
<some path>/snaplogic-robotframework-examples/<pipeline-name>

docker-compose.yml   Makefile   test/   env_files/   src/   makefiles/   ...
```

**What you're verifying:**

- ✅ `docker-compose.yml` is in the listing (means you're at the project root, not a subdirectory)
- ✅ `test/`, `env_files/`, `Makefile` are all present

**If something's missing:** `cd` into the correct project directory before continuing. Every command below assumes you're at this directory.

---

## Step 2 — Locate Your Wallet On The Host

The customer's DBA team has given you wallet files (or you copied them off another machine where Oracle Client was already configured). The wallet is typically in one of these locations:

| Platform | Common wallet location |
|---|---|
| Windows | `C:\Oracle\wallet\` |
| Windows + WSL | `/mnt/c/Oracle/wallet/` (the WSL view of the Windows path above) |
| Mac / Linux | `~/Oracle/wallet/` or `/opt/oracle/wallet/` |

Confirm the wallet is readable and inspect what's inside:

```bash
# Windows + WSL example — adjust path for your platform:
ls -la /mnt/c/Oracle/wallet/
```

**Expected output (minimum):**

```
-rwxrwxrwx 1 user user 2125 Sep 25 2023 cwallet.sso
```

**What you might also see (and what each file means):**

| File | Role | Required at runtime? |
|---|---|---|
| `cwallet.sso` | Auto-login wallet (no password needed) | ✅ **Yes — this is the one the driver actually reads** |
| `ewallet.p12` | Password-protected version of the same wallet | ❌ No (admin/recovery use) |
| `sqlnet.ora` | Oracle Net config (cipher suites, TLS settings, etc.) | ❌ No, unless the customer's Oracle uses non-default ciphers or DN matching |
| `tnsnames.ora` | TNS alias definitions | ❌ No when using `host:port/service` Easy Connect strings (the framework default) |

**Cross-verification — the file you really need is `cwallet.sso`.** If it's missing, the auto-login won't work and you'll need either the wallet password or a freshly regenerated `cwallet.sso` from the DBA.

> 💡 **For more on which files matter when**, see the appendix "Wallet File Roles" at the bottom of this guide.

---

## Step 3 — Place Wallet Files Into The Framework

The Docker container can only see files that are mounted into it. The cleanest path is to copy the wallet into the framework's `test/suite/test_data/wallets/oracle/` directory — that path is **already bind-mounted** at `/app/test/suite/test_data/wallets/oracle/` inside the container (no `docker-compose.yml` edit needed).

### 3a. Create the destination directory

```bash
mkdir -p test/suite/test_data/wallets/oracle
```

### 3b. Copy the wallet files

```bash
# Adjust source path for your platform:
cp /mnt/c/Oracle/wallet/* test/suite/test_data/wallets/oracle/
```

### 3c. Confirm the copy succeeded

```bash
ls -la test/suite/test_data/wallets/oracle/
```

**Expected output:**

```
-rwxrwxrwx 1 user user 2125 May 19 15:27 cwallet.sso
-rw-r--r-- 1 user user 1693 May 19 12:42 README.md
```

**What you're verifying:**

- ✅ `cwallet.sso` is present (with non-zero size)
- ✅ Any other wallet files you had on the source side (e.g., `ewallet.p12`, `sqlnet.ora`) also copied over

> ⚠️ **Don't worry about committing these files to git.** The `.gitignore` already excludes `*.sso`, `*.p12`, `sqlnet.ora`, and `tnsnames.ora` under `test/suite/test_data/wallets/`. Wallet files stay local to your machine.

---

## Step 4 — Update `.env.oracle` With TCPS Connection Settings

Open the file in your editor:

```
env_files/database_accounts/.env.oracle
```

Set or add these keys (keep the existing `ORACLE_ACCOUNT_*` lines intact — those are for SnapLogic account creation, separate from the DB connection itself):

```bash
# ============================================
# Customer Oracle Database Connection (TCPS)
# ============================================
ORACLE_HOST=<your-customer-oracle-hostname>
ORACLE_PORT=2484
ORACLE_DATABASE=<your-oracle-service-name>
ORACLE_USER=<your-db-username>
ORACLE_PASSWORD=<your-db-password>

# ============================================
# Wallet Location (container-side path)
# Files were copied to test/suite/test_data/wallets/oracle/ in Step 3.
# The container sees this directory at /app/test/suite/test_data/wallets/oracle/
# because ./test is bind-mounted at /app/test/ per docker-compose.yml.
# ============================================
ORACLE_WALLET_LOCATION=/app/test/suite/test_data/wallets/oracle
ORACLE_CONFIG_DIR=/app/test/suite/test_data/wallets/oracle
```

**A few important things to get right:**

| Key | Critical detail |
|---|---|
| `ORACLE_PORT` | Must be `2484` for TCPS. **Not `1521`** — that's plain TCP and won't accept TLS. |
| `ORACLE_DATABASE` | Should match the service name you use in Toad/DBeaver. Often the same as the hostname prefix (e.g., `LAMRXQC` from `LAMRXQC.example.net:2484/LAMRXQC`). |
| `ORACLE_WALLET_LOCATION` | Must use the **container path** (`/app/test/...`), not your Windows or Mac path. Don't change `/app` to `/mnt/c`. |
| `ORACLE_CONFIG_DIR` | Usually the same as `ORACLE_WALLET_LOCATION`. Only differs if `sqlnet.ora` lives somewhere else from the wallet itself. |

### 4a. Cross-verify the file (safely — without revealing the password)

This filter prints only the non-sensitive keys, so the output is safe to share for debugging:

```bash
grep -E "^(ORACLE_HOST|ORACLE_PORT|ORACLE_DATABASE|ORACLE_USER|ORACLE_WALLET_LOCATION|ORACLE_CONFIG_DIR)=" env_files/database_accounts/.env.oracle
```

**Expected output (with your real values):**

```
ORACLE_HOST=<your-host>
ORACLE_PORT=2484
ORACLE_DATABASE=<your-service>
ORACLE_USER=<your-username>
ORACLE_WALLET_LOCATION=/app/test/suite/test_data/wallets/oracle
ORACLE_CONFIG_DIR=/app/test/suite/test_data/wallets/oracle
```

**What you're verifying:**

- ✅ All six keys appear (not just five)
- ✅ `ORACLE_PORT` is `2484` (not `1521`)
- ✅ Wallet paths start with `/app/test/...` (not `/mnt/c/...` or `C:\\...`)

---

## Step 5 — Verify The Container Can See The Wallet

Even though the bind mount is configured, occasionally Docker Desktop or WSL gets confused and the file doesn't appear inside the container. Confirm directly:

### 5a. Restart the tools container (only if it's already running)

```bash
docker compose stop tools
make start-tools-service-only
```

Wait ~15 seconds for the container to come up.

### 5b. Confirm the wallet is visible inside the container

```bash
docker compose exec tools ls -la /app/test/suite/test_data/wallets/oracle/
```

**Expected output:**

```
total 8
drwxr-xr-x 2 root root   64 May 19 ...  .
drwxr-xr-x 3 root root   96 May 19 ...  ..
-rwxrwxrwx 1 root root 2125 May 19 ...  cwallet.sso
-rw-r--r-- 1 root root 1693 May 19 ...  README.md
```

**What you're verifying:**

- ✅ `cwallet.sso` appears inside the container (with non-zero size)
- ✅ The path `/app/test/suite/test_data/wallets/oracle/` resolves correctly

**If `cwallet.sso` doesn't show up here:** the bind mount didn't pick up the new file. Re-run Step 5a and try again. If still empty, confirm Step 3c succeeded on the host.

### 5c. Sanity-check the env vars are loaded inside the container

```bash
docker compose exec tools printenv ORACLE_HOST ORACLE_PORT ORACLE_DATABASE ORACLE_WALLET_LOCATION ORACLE_CONFIG_DIR
```

**Expected output:**

```
<your-host>
2484
<your-service>
/app/test/suite/test_data/wallets/oracle
/app/test/suite/test_data/wallets/oracle
```

**What you're verifying:**

- ✅ The variables you set in `.env.oracle` actually made it into the container's environment
- ✅ Wallet paths match what we set, not stale Docker-Oracle defaults

---

## Step 6 — Run The Oracle TCPS Connection Test

You're now ready to actually exercise the connection.

### 6a. Run the test

```bash
make robot-run-tests-no-gp TAGS=connect_to_oracle_database_sample
```

(Adjust the tag if your test uses a different one — check `[Tags]` at the top of `01.oracle_database.robot`.)

### 6b. Interpret a successful run

```
==============================================================================
01.Oracle Database
==============================================================================
Initialize Variables                                                  | PASS |
Create Account                                                        | PASS |
DDL — Drop, Create, Truncate                                          | PASS |
...
01.Oracle Database                                                    | PASS |
```

**What a successful run confirms:**

- ✅ Network path to the Oracle host works from inside the container
- ✅ TLS handshake completed (your wallet's CA cert trusts the server cert)
- ✅ DB authentication succeeded (your username + password are valid)
- ✅ The framework's `Connect to Oracle Database` keyword correctly switched to TCPS mode

### 6c. Confirm TCPS mode was actually used (not accidentally plain TCP)

Open the generated log file and search for the log line:

```bash
grep -h "Oracle TCPS mode" test/robot_output/log-*.html | head -1
```

**Expected output:**

```
Oracle TCPS mode — wallet: /app/test/suite/test_data/wallets/oracle
```

If you see `Oracle plain-TCP mode (no wallet configured)` instead, your `ORACLE_WALLET_LOCATION` env var is empty inside the container — return to Step 4 and re-run the verification commands.

---

## Step 7 — Failure Scenarios Reference

If the test fails, the exact error message tells you precisely which layer broke. Match the error to the table:

| Error | Layer | Most likely cause | Fix |
|---|---|---|---|
| `DPY-4011: the database or network closed the connection` | TLS handshake | Wallet not configured / wrong path / `cwallet.sso` missing inside container | Re-verify Step 5b. Confirm `wallet_location` is being passed to `Connect To Database` (check `database.resource`) |
| `DPY-6005: cannot connect to database` (wraps the above) | Connection-level | Wraps the underlying TLS issue | Same as above — the inner `DPY-4011` is the real signal |
| `ORA-12541: TNS:no listener` | TCP / network | Wrong port (1521 instead of 2484) or service name typo | Verify `ORACLE_PORT=2484` and `ORACLE_DATABASE` matches a real service |
| `ORA-12170: TNS:Connect timeout` | Network | VPN not connecting laptop to Oracle subnet | Confirm your VPN client is connected and the customer's network is reachable |
| `ORA-29024: Certificate validation failure` | TLS | Wallet has wrong CA cert (or no CA cert) | Confirm the wallet was sourced from the customer's DBA team and is the current one |
| `ORA-01017: invalid username/password` | Auth | TLS works — credentials are just wrong | Verify `ORACLE_USER` / `ORACLE_PASSWORD` match what you use in Toad |
| `ORA-12506: TNS:listener rejected connection based on service ACL` | Server-side ACL | Customer Oracle blocks your client IP | Customer's DBA needs to add your VPN-assigned IP to the listener ACL |
| `DPY-3015: password verifier type is not supported` | Driver compatibility | Older Oracle password hash, modern python-oracledb thin mode incompatible | Switch to thick mode (`oracledb.init_oracle_client(...)`) — separate config |
| Log shows `Oracle plain-TCP mode` despite TCPS config | Env vars missing | Container env didn't pick up `ORACLE_WALLET_LOCATION` | Re-run Step 5a (restart container) and Step 5c (verify env vars) |

---

## Appendix A — Wallet File Roles

Background on each file in case you're trying to understand what you have:

### `cwallet.sso` — Auto-login wallet

- The file Python (and Toad, DBeaver, sqlplus) actually reads at runtime
- Unlocks **automatically** — no password required
- Generated from `ewallet.p12` by the DBA using `orapki wallet create -auto_login`
- **Required at runtime**

### `ewallet.p12` — Password-protected wallet

- Same contents as `cwallet.sso`, but encrypted with a password
- The "source of truth" — DBAs edit this version when rotating certificates
- **Not required at runtime** — keep for recovery or rotation purposes
- Need the wallet password to open it

### `sqlnet.ora` — Oracle Net configuration

- Optional file. Used only when default Oracle Net behavior needs to be overridden.
- When you need it:
  - Customer's Oracle requires specific TLS cipher suites not in the driver default
  - You need `SSL_SERVER_DN_MATCH` / `SSL_SERVER_CERT_DN` for strict cert validation
  - Using mutual TLS (`SSL_CLIENT_AUTHENTICATION = TRUE` + client cert)
  - Using TNS aliases (`@PRODDB`) instead of Easy Connect (`host:2484/service`)
- When you don't:
  - Standard one-way TLS with a modern Oracle server → driver defaults work

### `tnsnames.ora` — TNS alias definitions

- Maps short alias names (like `PRODDB`) to full connection strings
- Not required if you use Easy Connect format in `ORACLE_HOST`/`ORACLE_DATABASE`
- The framework uses Easy Connect by default, so this file is informational only

---

## Appendix B — Security Notes

| Topic | Detail |
|---|---|
| Wallet files | Treat like SSH private keys. Never commit. Never share over unsecured channels. The `.gitignore` already excludes the standard wallet filenames, but copy-pasting wallet contents into Slack/email is still a leak. |
| Wallet password | If you have an `ewallet.p12` and need its password, ask the DBA team — they generated the wallet. Don't put the wallet password in `.env.oracle`. |
| Vendor-scoped DB user | Best practice: the customer's DBA creates a separate Oracle user (e.g., `VENDOR_QA_RO`) with **read-only** privileges on verification schemas. Don't use a DBA or application service account. |
| Credentials in `.env.oracle` | `.env.oracle` is loaded into the container as environment variables — fine for local use. **Do not commit a populated `.env.oracle` to git.** The framework's `.gitignore` already covers most cases, but double-check `git status` before committing. |
| Wallet rotation | Wallets typically rotate when the underlying CA cert rotates (years, not months). When that happens, the customer DBA will hand you a new wallet; replace the contents of `test/suite/test_data/wallets/oracle/` and re-run tests. No code changes needed. |

---

## Appendix C — How The Framework Routes The Connection

What actually happens when you run the test:

```
Robot Framework test case
   │
   ▼
test/resources/common/database.resource
   │  Connect to Oracle Database keyword
   │
   ▼  Checks: is ORACLE_WALLET_LOCATION set?
   │
   ├── YES → TCPS branch (calls Connect To Database with config_dir + wallet_location)
   │
   └── NO  → Plain TCP branch (calls Connect To Database without wallet args)
   │
   ▼
DatabaseLibrary.Connect To Database
   │  Forwards to python-oracledb driver
   │
   ▼
oracledb.connect(user=..., password=..., dsn="host:2484/service",
                 config_dir=..., wallet_location=...)
   │
   ▼  TLS handshake (uses cwallet.sso for CA verification)
   │  Auth (username + password)
   │
   ▼
Oracle DB returns a connection handle → test queries work
```

The conditional logic in `database.resource` is what makes this **backward-compatible** with the default Docker Oracle setup — if you don't set `ORACLE_WALLET_LOCATION`, the framework behaves exactly as it did before.

---

## Daily Workflow Summary

After the initial setup (Steps 1–5), the daily workflow is just:

```bash
# Make sure your VPN to the customer is connected
# (whichever VPN/network path lets you reach the Oracle host)

# Run the tests
make robot-run-tests-no-gp TAGS=connect_to_oracle_database_sample
```

No need to re-copy wallet files (they stay where you put them in Step 3) and no need to touch `.env.oracle` again unless your credentials change or the wallet rotates.
