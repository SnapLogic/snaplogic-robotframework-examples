# How AWS SSO Is Identified

> **Frequently asked:** *"Where is the IAM role payload file that this test uses?"*
>
> **Short answer:** there is **no** IAM role payload file.

Unlike Oracle / Postgres / Snowflake tests — which load an account payload (`acc_oracle.json`, `acc_postgres.json`, etc.) — SSO authentication relies entirely on AWS CLI's own config files under `~/.aws/`. The framework only reads **one** environment variable: `AWS_PROFILE`.

---

## The test file itself does almost nothing

Look at [`s3_connection_operations.robot`](s3_connection_operations.robot) in this same folder. The test case is two lines of real logic:

```robot
${ok}=    Validate MinIO Connection
Should Be True    ${ok}
```

All authentication logic lives inside the keyword, **not** the test.

---

## Where the IAM role is actually chosen — trace it backward

### Step 1 — Keyword reads env vars (no payload file)

File: [`resources/minio/minio.resource`](../../../../../resources/minio/minio.resource) (keyword: `Get S3 Client`)

```robot
${endpoint}=      Get Environment Variable    S3_ENDPOINT      ${EMPTY}
${access_key}=    Get Environment Variable    S3_ACCESS_KEY    ${EMPTY}
${secret_key}=    Get Environment Variable    S3_SECRET_KEY    ${EMPTY}
${region}=        Get Environment Variable    S3_REGION        us-east-1
${profile}=       Get Environment Variable    AWS_PROFILE      ${EMPTY}
```

The keyword reads five env vars. **No JSON file is loaded.**

### Step 2 — Auth mode is picked by which env vars are set

```robot
IF    ${has_keys}            # → MinIO or AWS access-key mode
ELSE IF    ${has_profile}    # → AWS SSO mode  ← we land here when S3_ACCESS_KEY/SECRET are empty
ELSE                          # → boto3 default credential chain
```

In SSO mode, the `.env` should look like:

```bash
S3_ENDPOINT=
S3_ACCESS_KEY=
S3_SECRET_KEY=
S3_REGION=us-east-1
AWS_PROFILE=Demo_AWSCLI
```

### Step 3 — The SSO branch passes the profile name to boto3

```robot
${session}=    Evaluate    __import__('boto3').Session(profile_name=$profile)
${creds}=      Evaluate    $session.get_credentials()
${s3_client}=  Evaluate    $session.client('s3', **$kwargs)
```

Only the profile name (e.g., `Demo_AWSCLI`) is passed. The keyword **never says "use role X" anywhere**.

### Step 4 — boto3 reads `~/.aws/config` to find the role

When boto3 sees `profile_name="Demo_AWSCLI"`, it opens `~/.aws/config` (mounted into the container at `/root/.aws/config`) and finds:

```ini
[profile Demo_AWSCLI]
sso_session    = RFAT_DEMO
sso_account_id = <12-digit account id>
sso_role_name  = awsDeveloper        # ← THE ROLE IS HERE
region         = us-east-1
output         = json
```

That `sso_role_name = awsDeveloper` line — written by `aws configure sso` when the user picked a role at the prompt — is what tells boto3 which IAM role to assume.

### Step 5 — boto3 uses cached SSO tokens to assume the role

boto3 then:

1. Reads the SSO session tokens from `~/.aws/sso/cache/<hash>.json` (created or refreshed by `aws sso login --profile <name>`)
2. Calls AWS STS to assume the role named in `sso_role_name`
3. Receives temporary credentials (valid ~1 hour, auto-refreshed as long as the SSO session itself is valid — typically 8–12 hours)
4. Uses those credentials for all S3 API calls

---

## The full chain visualized

```
.env file
  AWS_PROFILE=Demo_AWSCLI
        │
        ▼
container environment variable
        │
        ▼
Get S3 Client keyword (minio.resource)
  reads AWS_PROFILE → "Demo_AWSCLI"
        │
        ▼
boto3.Session(profile_name="Demo_AWSCLI")
        │
        ▼
~/.aws/config   (mounted into container at /root/.aws/config)
  [profile Demo_AWSCLI]
  sso_role_name = awsDeveloper     ← role chosen HERE
        │
        ▼
~/.aws/sso/cache/<hash>.json
  (cached login tokens)
        │
        ▼
AWS STS → assume role awsDeveloper
        │
        ▼
temporary credentials → boto3 S3 client
```

---

## Priority order when multiple auth methods are set

| Priority | Method | When used |
|----------|--------|-----------|
| 1 | `S3_ACCESS_KEY` + `S3_SECRET_KEY` | Explicit keys win — even over SSO |
| 2 | `AWS_PROFILE` | SSO via cached `sso login` tokens |
| 3 | boto3 default chain | Env vars, `~/.aws/credentials`, EC2 metadata |

> ⚠️ **Critical:** in SSO mode, `S3_ACCESS_KEY` and `S3_SECRET_KEY` **must be empty**. Leftover values from earlier static-key testing will silently override the SSO profile — the keyword will use the keys and SSO will never be consulted, with no warning visible at test time.

---

## How to switch to a different IAM role

No code, `.env`, or test-file change is needed. On the host (WSL), run:

```bash
aws configure sso
```

Step through the prompts again and pick a different role when AWS lists the roles available to your account. That overwrites `sso_role_name` in `~/.aws/config`. The next test run automatically uses the new role.

---

## How to refresh expired SSO tokens

Tokens last 8–12 hours. When they expire, the keyword will fail with:

```
AWS_PROFILE '<name>' resolved to no credentials.
Run: aws sso login --profile <name>
```

On the host (WSL or PowerShell, wherever AWS CLI is installed), run:

```bash
aws sso login --profile Demo_AWSCLI
```

This opens a browser, completes the SSO handshake, and writes fresh tokens to `~/.aws/sso/cache/`. **No container restart required** — the container reads the same files via the bind mount.

---

## Why this design (vs. a payload JSON)

AWS SSO credentials are short-lived and managed by the AWS CLI's own token-cache lifecycle. Bundling them into a static JSON payload would:

- Duplicate state that AWS CLI already manages
- Force the framework to handle token refresh logic
- Encourage checking expiring credentials into version control

Reading `AWS_PROFILE` and delegating to boto3 keeps the framework thin and lets AWS CLI own the credential lifecycle.
