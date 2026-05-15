# AWS SSO Setup — Prerequisites

Prerequisite / initial-setup steps for connecting the Robot Framework test suite to AWS S3 using AWS SSO.

This document is for users on **Windows + WSL**. All commands run **inside WSL** — not in Windows PowerShell or CMD.

---

## Step 1 — Install (Or Upgrade) AWS CLI To v2

AWS SSO requires **AWS CLI v2**. Version 1 does not support `aws sso login` and will give an error if you try to use it.

### 1a. Open A WSL Terminal (This step is only for windows users)

On your Windows machine, open a WSL terminal (e.g., via the Ubuntu app, Windows Terminal → WSL, or VS Code → Terminal → WSL).

Verify you're inside WSL:

```bash
uname -a
```

**Expected output:** Something like `Linux ... WSL2 ... x86_64 GNU/Linux`.

If you see PowerShell-style output, switch the terminal to WSL before continuing.

### 1b. Check What AWS CLI Version Is Currently Installed

```bash
aws --version
```

You'll see one of three things:

| Output              | What It Means                | What To Do                          |
| ------------------- | ---------------------------- | ----------------------------------- |
| `aws-cli/2.x.x ...` | ✅ v2 already installed       | Skip to Step 2 — nothing to do here |
| `aws-cli/1.x.x ...` | v1 installed — needs upgrade | Continue to 1c                      |
| `command not found` | Not installed at all         | Continue to 1c                      |

### 1c. Install AWS CLI v2

Run these commands inside WSL to install (or upgrade to) v2:

```bash
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
```

> 💡 **Why not `sudo apt install awscli`?** On most Ubuntu/Debian versions, `apt` installs AWS CLI v1, which doesn't support SSO. Always use the official AWS installer for v2.

### 1d. Verify The Installation

```bash
aws --version
```

**Expected output:** `aws-cli/2.x.x ...`

If you still see v1, you may have a v1 binary shadowing v2 in your PATH (common if you have a Python virtual environment or other tools installed). Check with:

```bash
which aws
```

If the path points somewhere other than the v2 install location (typically `/usr/local/bin/aws`), you'll need to deactivate the conflicting environment before continuing.

---

## Step 2 — Configure The AWS SSO Profile

Once `aws --version` confirms AWS CLI v2 is installed, run the interactive SSO setup.

### 2a. Find Your SSO Start URL First

Before starting the configuration, you need your **SSO start URL**. This is the AWS-specific URL (not your Okta or corporate SSO portal URL).

**How to find it:**

1. Log into your corporate SSO portal (e.g., Okta dashboard)
2. Click the **"Amazon Web Services"** tile / icon
3. Your browser will redirect to the AWS access portal
4. The URL in the browser address bar will look like:

```
https://d-XXXXXXXXXX.awsapps.com/start/#/
```

5. Copy the URL **up to and including `/start`** — that's your SSO start URL.

**Example (real URL pattern):**

```
https://d-9267467bdf.awsapps.com/start
```

> 💡 **The URL pattern is always `https://<identifier>.awsapps.com/start`.** Some organizations use a custom subdomain (e.g., `https://your-org.awsapps.com/start`); others use the auto-generated `d-XXXX` identifier. Either is valid.

### 2b. Run The Interactive SSO Configuration

In your WSL terminal, run:

```bash
aws configure sso
```

This will prompt you for several values. Here's exactly what to enter:

```
SSO session name (Recommended): swapna-sso
SSO start URL [None]: https://d-9267467bdf.awsapps.com/start
SSO region [None]: us-west-2
SSO registration scopes [sso:account:access]:
```

**Notes on each prompt:**

| Prompt                    | What To Enter                                          | Notes                                         |
| ------------------------- | ------------------------------------------------------ | --------------------------------------------- |
| `SSO session name`        | Any memorable name (e.g., `your-name-sso`)             | Internal label for this SSO session           |
| `SSO start URL`           | The URL from Step 2a                                   | Must include `/start` at the end              |
| `SSO region`              | The AWS region where SSO is hosted (e.g., `us-west-2`) | See gotcha below                              |
| `SSO registration scopes` | Press **Enter** to accept default                      | Default `sso:account:access` is what you want |

### 2c. Common Gotcha — Wrong SSO Region

If you enter the wrong SSO region, you'll get this error:

```
aws: [ERROR]: An error occurred (InvalidRequestException) when calling the RegisterClient operation:

Additional error details:
error: invalid_request
error_description: Invalid request.
```

**Fix:** Re-run `aws configure sso` and try a different region. Common SnapLogic SSO regions:

- `us-west-2` (try first)
- `us-east-1`
- `us-east-2`

If unsure, ask your AWS administrator which region the SSO is hosted in.

### 2d. Authorize In The Browser

After entering the SSO region, AWS CLI prints a URL and attempts to open your browser automatically:

```
Attempting to open your default browser. If the browser does not open, open the following URL.

https://oidc.us-west-2.amazonaws.com/authorize?response_type=code&client_id=...
```

**What happens in the browser:**

1. The browser opens to an AWS authorization page
2. You'll see a prompt: *"Allow botocore-client-<your-session-name> to access your data?"*
3. Click the orange **"Allow access"** button

> 💡 **If the browser doesn't open automatically** (common on WSL where the Windows browser is separate from WSL), copy the URL from the terminal output and paste it into your Windows browser manually. Complete the authorization there.

After you click "Allow access," return to the WSL terminal — it will have automatically continued to the next step.

### 2e. Select Your AWS Account

After successful authorization, the terminal shows the AWS accounts available to **your** organization. The list, account names, and account IDs will be **specific to your company** — what's shown below is just an illustrative example.

**Generic format:**

```
There are <N> AWS accounts available to you.
> <your-account-name-1>, <owner-email-1> (<12-digit-account-id-1>)
  <your-account-name-2>, <owner-email-2> (<12-digit-account-id-2>)
  <your-account-name-3>, <owner-email-3> (<12-digit-account-id-3>)
```

**Concrete example of what it looks like in practice:**

```
There are 3 AWS accounts available to you.
> my-sandbox-account, owner+sandbox@example.com (123456789012)
  my-prod-account, owner+prod@example.com (234567890123)
  my-dev-account, owner+dev@example.com (345678901234)
```

Use the **arrow keys** to highlight the account you want, then press **Enter**.

**Recommendation:** Pick a **dev, test, or sandbox** account — never a production account. Your administrator can tell you which account has the S3 bucket you'll be testing against.

For the rest of this guide, we'll use **`my-dev-account` (345678901234)** as the example.

### 2f. Role Auto-Selection (Or Selection)

After picking an account, AWS shows the role(s) you can assume. The role names depend on your organization's IAM setup.

**Generic format:**

```
Using the account ID <your-selected-account-id>
The only role available to you is: <your-role-name>
Using the role name "<your-role-name>"
```

**Concrete example (continuing with `my-dev-account`):**

```
Using the account ID 345678901234
The only role available to you is: ReadOnly
Using the role name "ReadOnly"
```

If only one role is available, AWS auto-selects it. If multiple are available, use arrow keys to pick a **read-only** role (e.g., `ReadOnly`, `S3ReadOnlyAccess`, or whatever your organization names it).

### 2g. Final Configuration Prompts

A few last questions. The default suggestion in brackets is generated by AWS — you can accept it or pick your own.

**Generic format:**

```
Default client Region [None]: <your-region>
CLI default output format (json if not specified) [None]:
Profile name [<default-auto-generated>]: <your-chosen-profile-name>
```

**Concrete example values:**

```
Default client Region [None]: us-east-1
CLI default output format (json if not specified) [None]:
Profile name [ReadOnly-345678901234]: my-dev-s3-reader
```

| Prompt                  | What To Enter                                     | Notes                                                         |
| ----------------------- | ------------------------------------------------- | ------------------------------------------------------------- |
| `Default client Region` | Same as the AWS region where your S3 bucket lives | Used for API calls (e.g., `us-east-1`, `us-west-2`)           |
| `Default output format` | Press **Enter** for `json`                        | Standard choice                                               |
| `Profile name`          | Pick a descriptive name                           | This is what you'll reference with `AWS_PROFILE=<name>` later |

> 💡 **Profile name rules:** Use lowercase letters, hyphens, and numbers. No spaces, no special characters. Pick something memorable that describes the account + role, e.g., `<account-shortname>-readonly`.

### 2h. Success — Verify The Configuration

After all prompts, AWS CLI prints a confirmation similar to:

```
To use this profile, specify the profile name using --profile, as shown:

aws sts get-caller-identity --profile <your-chosen-profile-name>
```

**Concrete example (continuing with `my-dev-s3-reader`):**

```
To use this profile, specify the profile name using --profile, as shown:

aws sts get-caller-identity --profile my-dev-s3-reader
```

Run that verification command. Replace `<your-chosen-profile-name>` with the name you picked:

```bash
aws sts get-caller-identity --profile <your-chosen-profile-name>
```

**Concrete example command:**

```bash
aws sts get-caller-identity --profile my-dev-s3-reader
```

**Expected output (your values will reflect your account and role):**

```json
{
    "UserId": "AROA...:<your-username>",
    "Account": "<your-12-digit-account-id>",
    "Arn": "arn:aws:sts::<your-account-id>:assumed-role/AWSReservedSSO_<your-role-name>_<hash>/<your-username>"
}
```

**Concrete example of what the output looks like:**

```json
{
    "UserId": "AROAEXAMPLEEXAMPLE:user@example.com",
    "Account": "345678901234",
    "Arn": "arn:aws:sts::345678901234:assumed-role/AWSReservedSSO_ReadOnly_a1b2c3d4e5f6/user@example.com"
}
```

If you see your account ID, role name, and username in the output, **AWS SSO is fully working** on your machine.

---

## Step 3 — Inspect What AWS CLI Created

After Step 2 completes, AWS CLI automatically creates a few files on your machine under `~/.aws/`. You don't need to create or edit them manually — but it's useful to **inspect them** so you understand what's there and confirm the setup is correct.

### 3a. View The Main Config File

Run:

```bash
cat ~/.aws/config
```

**Generic format of the output:**

```ini
[profile <your-chosen-profile-name>]
sso_session = <your-sso-session-name>
sso_account_id = <your-12-digit-account-id>
sso_role_name = <your-role-name>
region = <your-region>
output = json

[sso-session <your-sso-session-name>]
sso_start_url = https://<sso-identifier>.awsapps.com/start
sso_region = <sso-hosting-region>
sso_registration_scopes = sso:account:access
```

**Concrete example of what it looks like:**

```ini
[profile my-dev-s3-reader]
sso_session = my-sso-session
sso_account_id = 345678901234
sso_role_name = ReadOnly
region = us-east-1
output = json

[sso-session my-sso-session]
sso_start_url = https://d-9267467bdf.awsapps.com/start
sso_region = us-east-1
sso_registration_scopes = sso:account:access
```

**What each section means:**

| Section                | Purpose                                                         |
| ---------------------- | --------------------------------------------------------------- |
| `[profile <name>]`     | A specific profile that you reference with `AWS_PROFILE=<name>` |
| `[sso-session <name>]` | A shared SSO session that one or more profiles can reuse        |

> 💡 **Why two sections?** AWS designed this so you can authenticate once (via the SSO session) and have multiple profiles share it — e.g., if you have access to multiple AWS accounts, each gets its own profile but they all use the same SSO session.

### 3b. View The SSO Token Cache Directory

The SSO session tokens (created by `aws sso login` during Step 2) are stored separately:

```bash
ls -la ~/.aws/sso/cache/
```

**Generic format of the output:**

```
total <N>
drwx------  <perms> <user> <group> <size> <date> .
drwx------  <perms> <user> <group> <size> <date> ..
-rw-------  <perms> <user> <group> <size> <date> <hash>.json
-rw-------  <perms> <user> <group> <size> <date> <hash>.json
```

**Concrete example:**

```
total 16
drwxr-xr-x  4 user  staff   128 May 14 20:46 .
drwxr-xr-x  3 user  staff    96 May 14 20:45 ..
-rw-------  1 user  staff  3101 May 14 20:45 3f87e8ca707adb1ad7fc656fe1e55c050e8970f4.json
-rw-------  1 user  staff  3639 May 14 20:46 919ae5d02b40067f82bea840235570ff2b2d68cd.json
```

**What these files are:**

- One or more JSON files with hashed names (`<hash>.json`)
- They hold the **temporary SSO tokens** AWS CLI uses to fetch credentials
- File permissions are `-rw-------` (read/write for owner only) — this is correct and protects the tokens
- These files **expire** along with the SSO session (typically 8–12 hours) and get refreshed the next time you run `aws sso login`

> ⚠️ **Do not edit or share these files.** They're equivalent to active session credentials.

### 3c. View The Full `~/.aws/` Directory Structure

```bash
ls -la ~/.aws/
```

**Concrete example:**

```
total 16
drwxr-xr-x    6 user  staff   192 May 14 20:50 .
drwxr-x---  120 user  staff  3840 May 14 20:50 ..
drwxr-xr-x    3 user  staff    96 May 14 20:50 cli
-rw-------    1 user  staff   331 May 14 20:49 config
-rw-r--r--    1 user  staff  1182 Apr 13 21:29 credentials
drwxr-xr-x    3 user  staff    96 May 14 20:45 sso
```

**What each file/directory is:**

| Item          | What It Is                                                      | Created By          |
| ------------- | --------------------------------------------------------------- | ------------------- |
| `config`      | Profile + SSO session settings (from Step 2)                    | `aws configure sso` |
| `sso/cache/`  | Cached SSO session tokens (from Step 2's browser authorization) | `aws sso login`     |
| `credentials` | Static access key + secret credentials (NOT used in SSO mode)   | Old manual setup    |
| `cli/`        | AWS CLI internal metadata                                       | AWS CLI             |

> 💡 **A `credentials` file may exist from prior usage of AWS CLI on this machine.** It won't conflict with SSO — SSO uses its own files (`config` + `sso/cache/`). If you previously had access keys configured, they'll stay where they are but won't be used as long as you specify `--profile <sso-profile-name>` or set `AWS_PROFILE` to your SSO profile.

### 3d. What If `~/.aws/` Doesn't Exist?

If `aws configure sso` succeeded but you don't see `~/.aws/` at all, something went wrong with the configuration. Try:

1. Re-run Step 2 (`aws configure sso`)
2. Confirm the browser authorization completed
3. Run `cat ~/.aws/config` again — the file should now exist

If it still doesn't appear, check disk permissions or run `mkdir -p ~/.aws` to create an empty directory first, then re-run `aws configure sso`.

---

## Step 4 — Cross-Verify S3 Access Through The SSO Profile

At this point, your AWS SSO profile is configured and the underlying token cache is in place. Before relying on the Robot Framework to talk to S3, it is worth **cross-verifying** that the SSO profile genuinely confers the expected S3 read access — directly from the command line, independent of the framework. This eliminates ambiguity later: if Robot tests fail, you'll already know whether the issue lies in the framework layer or in the underlying AWS permissions.

Two commands corroborate the setup end-to-end: one enumerates the buckets visible to the assumed role, and one demonstrates object-level read access inside a specific bucket.

### 4a. Enumerate Accessible Buckets

Run:

```bash
aws s3 ls --profile <your-chosen-profile-name>
```

**Concrete example:**

```bash
aws s3 ls --profile my-dev-s3-reader
```

**Expected output:** A list of bucket names with their creation timestamps. The exact buckets will reflect what your assumed role can see.

**Generic output format:**

```
<creation-date>  <creation-time>  <bucket-name-1>
<creation-date>  <creation-time>  <bucket-name-2>
<creation-date>  <creation-time>  <bucket-name-3>
...
```

**Concrete example:**

```
2024-04-28 03:39:58  admin-logs-bucket
2024-04-27 16:32:33  app-debug-logs
2024-04-28 05:41:57  test-sl-bkt
2024-04-27 13:46:11  monitoring-archive
```

**What this confirms:**

- ✅ The SSO token cache is valid and not expired
- ✅ The assumed role is recognized by AWS
- ✅ The role carries at least `s3:ListAllMyBuckets` permission

If the list returns without error, general AWS S3 connectivity through the SSO profile is established.

### 4b. Confirm Object-Level Read Access

Listing bucket names proves the role can see *that buckets exist*. To confirm the role can actually read **inside** a specific bucket — which is what the Robot tests will do — list the objects within a known bucket.

Pick a non-production bucket from the output above (or one your administrator confirms is safe to read).

```bash
aws s3 ls s3://<your-test-bucket-name>/ --profile <your-chosen-profile-name>
```

**Concrete example:**

```bash
aws s3 ls s3://test-sl-bkt/ --profile my-dev-s3-reader
```

> 💡 **Mind the trailing slash.** `aws s3 ls s3://bucket-name/` lists objects *inside* the bucket. Without the trailing slash, the behaviour can differ.

**Expected output:** A list of objects (files and/or "folders" by prefix) with sizes and timestamps.

**Generic output format:**

```
<modified-date>  <modified-time>  <object-size>  <object-key>
<modified-date>  <modified-time>  <object-size>  <object-key>
```

**Concrete example:**

```
2023-04-25 14:29:29       2374 cert.crt
2023-04-25 14:29:30       2374 cert.pem
2023-04-25 14:29:30       4795 bundle-g2.crt
2023-04-25 14:29:29       1679 elastic-key.key
```

**What this confirms:**

- ✅ The role carries `s3:ListBucket` permission on this specific bucket
- ✅ Network connectivity to the regional S3 endpoint is functional
- ✅ The bucket exists and is accessible under the SSO-assumed identity

### 4c. Interpreting Failure Scenarios

If either command fails, the message tells you precisely where to look:

| Error                                                                       | Likely Cause                                       | Resolution                                                                |
| --------------------------------------------------------------------------- | -------------------------------------------------- | ------------------------------------------------------------------------- |
| `Token has expired and refresh failed`                                      | SSO session lapsed                                 | Re-run `aws sso login --profile <your-profile>`                           |
| `Could not connect to the endpoint URL`                                     | Network or region misconfiguration                 | Verify `region` in `~/.aws/config` matches the bucket's region            |
| `An error occurred (AccessDenied) when calling the ListBuckets operation`   | Role lacks `s3:ListAllMyBuckets`                   | Skip 4a; try 4b with a known bucket name                                  |
| `An error occurred (AccessDenied) when calling the ListObjectsV2 operation` | Role lacks read permission on this specific bucket | Pick a different bucket, or escalate to your AWS administrator            |
| `NoSuchBucket`                                                              | Bucket name typo or wrong account                  | Double-check the bucket name and confirm it lives in the selected account |

**Important distinction:** A failure here indicates a permissions or configuration issue at the AWS level — **not** a problem with the Robot Framework. Resolving these before moving on saves significant debugging effort later.

### 4d. Why This Step Is Worth The Time

Cross-verifying at the CLI layer offers three practical benefits:

1. **Isolates the failure surface.** If Robot tests later fail, you can rule out the SSO/permission layer immediately — you've already proven it works.
2. **Establishes a known-good bucket.** The bucket you successfully list here can serve as the reference target for your initial test runs.
3. **Surfaces permission gaps early.** If the assumed role is more restrictive than expected, you discover it now rather than mid-test.

Only after both commands succeed should you proceed to configuring the framework itself.

---

## Step 5 — Configure The Framework To Use The SSO Profile

With the SSO profile validated at the AWS layer, the next task is to instruct the framework to **defer credential resolution to that profile** rather than relying on static access keys or the local MinIO emulator. All the configuration values described below go into a **single file**: the root `.env` at the top of the project. There is no need to edit the S3-specific file under `env_files/`.

The intent is straightforward: ensure the framework has **no static credentials** to fall back on, so that `boto3` is forced to consult the SSO-cached tokens via the named profile.

> 💡 **Why the root `.env`?** The framework loads the root `.env` last in its environment hierarchy, which means any values you set here take precedence over the defaults baked into `env_files/`. You can override SSO-related settings in one place without touching the framework's standard configuration files.

### 5a. Open The Root `.env` File

Open the `.env` file located at the project root (same directory as `Makefile` and `docker-compose.yml`). If the file doesn't exist yet, copy the template:

```bash
cp .env.example .env
```

### 5b. Add The SSO Configuration Block

Append (or update) the following block in the root `.env`. All five entries belong together for SSO mode.

**Generic format:**

```bash
# AWS SSO mode — leave the three credential fields empty so boto3
# falls back to the default credential chain and resolves via AWS_PROFILE.
S3_ENDPOINT=
S3_ACCESS_KEY=
S3_SECRET_KEY=
S3_REGION=<your-bucket-region>
AWS_PROFILE=<your-chosen-profile-name>
```

**Concrete example:**

```bash
# AWS SSO mode — leave the three credential fields empty so boto3
# falls back to the default credential chain and resolves via AWS_PROFILE.
S3_ENDPOINT=
S3_ACCESS_KEY=
S3_SECRET_KEY=
S3_REGION=us-east-1
AWS_PROFILE=my-dev-s3-reader
```

**Why each field matters:**

| Field           | Why Empty (Or Specific)                                                                                      |
| --------------- | ------------------------------------------------------------------------------------------------------------ |
| `S3_ENDPOINT`   | Empty signals "use real AWS S3" (a non-empty value redirects boto3 to a MinIO-compatible endpoint instead)   |
| `S3_ACCESS_KEY` | Empty so boto3 falls back to the default credential chain (which finds the SSO profile)                      |
| `S3_SECRET_KEY` | Same reason as above                                                                                         |
| `S3_REGION`     | Set to the AWS region of the bucket you intend to read                                                       |
| `AWS_PROFILE`   | Tells boto3 — both on the host and inside the Docker container — which profile in `~/.aws/config` to consult |

> ⚠️ **A common oversight:** leftover values in `S3_ACCESS_KEY` and `S3_SECRET_KEY` from earlier static-credential testing will silently override the SSO profile. The framework will not warn you. Verify these fields are truly empty.

> 💡 **The `AWS_PROFILE` value must match exactly** what you chose in Step 2g. Case-sensitive. No leading or trailing whitespace.

### 5c. Confirm The Configuration

Before restarting the container, sanity-check the values you just set:

```bash
grep -E "^(S3_ENDPOINT|S3_ACCESS_KEY|S3_SECRET_KEY|S3_REGION|AWS_PROFILE)=" .env
```

**Expected output:**

```
S3_ENDPOINT=
S3_ACCESS_KEY=
S3_SECRET_KEY=
S3_REGION=us-east-1
AWS_PROFILE=my-dev-s3-reader
```

If any of the `S3_ENDPOINT`, `S3_ACCESS_KEY`, or `S3_SECRET_KEY` lines contain values after the `=`, return to Step 5b and clear them.

---

## Step 6 — Restart The Container And Validate End-To-End

The Docker tools container reads environment variables and binds host directories **at startup**. Configuration changes made in Step 5 will not take effect on a container that's already running — a restart is mandatory. Once restarted, two quick checks confirm the entire chain works: the bind mount surfaces the host's `~/.aws/` directory inside the container, and `boto3` inside the container successfully assumes the SSO-backed identity.

### 6a. Refresh The Tools Container

Stop the running tools container and bring it back up so it picks up the new `AWS_PROFILE` value and the AWS credentials bind mount:

```bash
docker compose stop tools
make start-tools-service-only
```

**Expected output (concrete example):**

```
🚀 Starting tools container only...
[+] Running 1/1
 ✔ Container snaplogic-test-example-tools-container  Started
⏳ Waiting for container to be ready...
✅ Tools container started successfully!
```

### 6b. Verify The AWS Credentials Bind Mount

Confirm that the host's `~/.aws/` directory is correctly mounted inside the container as `/root/.aws/` (read-only):

```bash
docker compose exec tools ls -la /root/.aws/
```

**Generic format:**

```
total <N>
drwxr-xr-x <perms> root root <size> <date> .
drwx------ <perms> root root <size> <date> ..
drwxr-xr-x <perms> root root <size> <date> cli
-rw-------  <perms> root root <size> <date> config
-rw-r--r-- <perms> root root <size> <date> credentials
drwxr-xr-x <perms> root root <size> <date> sso
```

**Concrete example:**

```
total 12
drwxr-xr-x 6 root root  192 May 15 03:50 .
drwx------ 1 root root 4096 May 15 04:00 ..
drwxr-xr-x 3 root root   96 May 15 03:50 cli
-rw------- 1 root root  331 May 15 03:49 config
-rw-r--r-- 1 root root 1182 Apr 14 04:29 credentials
drwxr-xr-x 3 root root   96 May 15 03:45 sso
```

**What this confirms:**

- ✅ The host's `~/.aws/config` is visible inside the container
- ✅ The cached SSO tokens in `sso/cache/` are accessible to the container
- ✅ The bind mount declared in `docker-compose.yml` is functioning

> ⚠️ **If `/root/.aws/` is empty or missing**, the bind mount did not take effect. Re-check `docker-compose.yml` for the `${HOME}/.aws:/root/.aws:ro` entry, then repeat Step 6a.

### 6c. Verify `boto3` Inside The Container Can Assume The Role

This is the definitive end-to-end check: it proves that the AWS Python SDK running inside the Docker container can read the SSO cache, assume the IAM role, and call AWS successfully.

```bash
docker compose exec tools python -c "import boto3, os; print(boto3.Session(profile_name=os.environ['AWS_PROFILE']).client('sts').get_caller_identity())"
```

**Generic format of the output:**

```python
{'UserId': '<role-id>:<your-username>',
 'Account': '<your-12-digit-account-id>',
 'Arn': 'arn:aws:sts::<account-id>:assumed-role/<role-name>/<your-username>',
 'ResponseMetadata': {...}}
```

**Concrete example:**

```python
{'UserId': 'AROAEXAMPLEEXAMPLE:user@example.com',
 'Account': '345678901234',
 'Arn': 'arn:aws:sts::345678901234:assumed-role/AWSReservedSSO_ReadOnly_a1b2c3d4e5f6/user@example.com',
 'ResponseMetadata': {'RequestId': '...', 'HTTPStatusCode': 200, ...}}
```

**What this proves:**

- ✅ `AWS_PROFILE` flowed correctly from the host into the container
- ✅ The bind-mounted `~/.aws/` is readable by the Python interpreter inside the container
- ✅ The SSO tokens are valid and unexpired
- ✅ AWS recognizes the assumed role and returns a successful response
- ✅ The full credential chain works end-to-end

### 6d. Interpreting Failure Scenarios

If the verification fails, the message indicates where the chain broke:

| Error                                   | Likely Cause                                | Resolution                                                                             |
| --------------------------------------- | ------------------------------------------- | -------------------------------------------------------------------------------------- |
| `KeyError: 'AWS_PROFILE'`               | `AWS_PROFILE` not set in the container      | Confirm the variable in root `.env` and restart the container                          |
| `botocore.exceptions.ProfileNotFound`   | Profile name does not match `~/.aws/config` | Verify the spelling in `AWS_PROFILE` and the profile section in `~/.aws/config`        |
| `SSOTokenLoadError`                     | SSO session expired or cache missing        | Run `aws sso login --profile <your-profile>` on the host, then re-run the verification |
| `Could not connect to the endpoint URL` | Network or region misconfiguration          | Verify `S3_REGION` in the root `.env` and the profile region in `~/.aws/config`        |
| Output is silent / no JSON returned     | Python error swallowed by shell             | Run the command without `docker compose exec tools` to see the raw error               |

Only after the JSON identity output appears successfully should you proceed to running Robot Framework tests. At that point, the framework will pick up the SSO credentials transparently — no test-side changes required.

---

## Step 7 — Run A Robot Test To Validate End-To-End Connectivity

The previous steps verified that AWS SSO works, the framework's environment is configured, and `boto3` inside the container can assume the role. The final piece is to confirm that **the Robot Framework layer itself** picks up the SSO credentials transparently and can perform a real S3 operation end-to-end.

This step runs an existing Robot test that exercises the `Get S3 Client` keyword and performs a simple, non-destructive S3 operation. No new test code is required — the existing keywords work as-is once the environment is configured.

### 7a. Locate The Sample Test

The framework ships with a sample test file in the same directory as this guide:

```
test/suite/pipeline_tests/tutorial_testcases/02.verification_test_cases/02. connect_to_s3_operations/s3_connection_operations.robot
```

Inside, the test case tagged `connect_to_s3_sample_verification` calls `Get S3 Client` . This is the safest test to run for an initial connectivity check.


### 7b. Run The Test From The Terminal

Execute the sample test from the project root, targeting the appropriate tag:

```bash
make robot-run-tests-no-gp TAGS=connect_to_s3_sample_verification
```


### 7d. Interpreting The Output

A successful run produces console output similar to the example below.

**Concrete example of a successful run:**

```
==============================================================================
Connect To S3 Operations
==============================================================================
Connect To S3 Sample                                                  | PASS |
------------------------------------------------------------------------------
Connect To S3 Operations                                              | PASS |
1 critical test, 1 passed, 0 failed
1 test total, 1 passed, 0 failed
==============================================================================
```

**What this confirms:**

- ✅ Robot Framework loaded the `Get S3 Client` keyword successfully
- ✅ `boto3` picked up the SSO profile via `AWS_PROFILE`
- ✅ The cached SSO tokens were valid at execution time
- ✅ The assumed IAM role authenticated against AWS S3
- ✅ The configured bucket was accessible under the role's permissions

At this point, the framework is fully operational in SSO mode.

### 7e. Inspecting Detailed Logs

If you want to confirm exactly which auth mode was used during the run, check the Robot Framework log file generated under `test/robot_output/`:

```bash
open test/robot_output/log-*.html
```

Search for the message logged by `Get S3 Client`. In SSO mode, you should see a log entry similar to:

```
AWS SSO mode active (profile: my-dev-s3-reader)
```

This message confirms — at the keyword level — that SSO was the credential source for the test run.

### 7f. Interpreting Failure Scenarios

If the test fails, the Robot console output and the HTML log point to the root cause:

| Symptom                                           | Likely Cause                                                      | Resolution                                                            |
| ------------------------------------------------- | ----------------------------------------------------------------- | --------------------------------------------------------------------- |
| `AWS_PROFILE '<name>' resolved to no credentials` | SSO session expired or never logged in                            | Run `aws sso login --profile <your-profile>` on the host, then retry  |
| `botocore.exceptions.ProfileNotFound`             | Profile name in `.env` doesn't match `~/.aws/config`              | Re-check spelling in root `.env`                                      |
| `AccessDenied` on bucket operations               | Role lacks permission for this specific bucket                    | Switch `${BUCKET_NAME}` to a bucket the role can access (see Step 4b) |
| `Connection refused` or `Could not connect`       | Network issue between container and AWS                           | Verify the container has internet access; check `S3_REGION`           |
| Test logs show `Using explicit S3 access keys`    | Leftover values in `S3_ACCESS_KEY` / `S3_SECRET_KEY` override SSO | Return to Step 5b and ensure those fields are empty                   |

Resolve the indicated issue, then re-run `make robot-run-tests-no-gp TAGS=connect_to_s3_sample_verification`.

### 7g. What This Step Establishes

Once this test passes, you have proven the complete chain end-to-end:

```
User → aws sso login → cached tokens → bind mount → container
     → boto3 (via Get S3 Client) → AWS STS → S3 → test passes
```

From this point forward, the customer's team can run any of the existing S3 verification tests in the framework — **no further setup changes are required**. The framework operates transparently in SSO mode, just as it does in MinIO or access-key mode.

---

## Daily Workflow Summary

After the initial setup is complete (Steps 1–7), the daily workflow reduces to two commands:

```bash
# Once per session (or whenever credentials expire — typically 8–12 hours)
aws sso login --profile <your-chosen-profile-name>

# Run tests
make robot-run-tests-no-gp TAGS=<your-test-tag>
```

No more configuration. No keys to rotate. No files to edit. The framework operates entirely on transient, auto-refreshed credentials sourced from your corporate SSO identity.

## Summary-How The Pieces Fit Together

```
┌────────────────────────────────────────────────────────────┐
│  Windows Laptop                                            │
│                                                            │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  WSL (Linux subsystem on Windows)                    │  │
│  │                                                      │  │
│  │  User runs `aws sso login` here                      │  │
│  │                                                      │  │
│  │  /home/<user>/.aws/                                  │  │
│  │  ├── config              ← aws configure sso writes  │  │
│  │  └── sso/cache/<token>   ← aws sso login writes      │  │
│  │                                                      │  │
│  │  ┌─────────────────────────────────────────────────┐ │  │
│  │  │  Docker (running on WSL)                        │ │  │
│  │  │                                                 │ │  │
│  │  │  ┌─────────────────────────────────────────┐    │ │  │
│  │  │  │  tools container                        │    │ │  │
│  │  │  │                                         │    │ │  │
│  │  │  │  /root/.aws/  ← bind mount of host's    │    │ │  │
│  │  │  │               ~/.aws/ (read-only)       │    │ │  │
│  │  │  │                                         │    │ │  │
│  │  │  │  AWS_PROFILE=<profile-name> from host   │    │ │  │
│  │  │  │                                         │    │ │  │
│  │  │  │  Robot Framework runs here              │    │ │  │
│  │  │  │  → boto3 reads /root/.aws/sso/cache/    │    │ │  │
│  │  │  │  → uses SSO credentials                 │    │ │  │
│  │  │  │  → talks to AWS S3                      │    │ │  │
│  │  │  └─────────────────────────────────────────┘    │ │  │
│  │  └─────────────────────────────────────────────────┘ │  │
│  └──────────────────────────────────────────────────────┘  │
└────────────────────────────────────────────────────────────┘
```

**Key insight:** The container's `/root/.aws/` IS the WSL host's `~/.aws/`. They're the same directory, accessed from different namespaces. Run `aws sso login` once on the WSL host → all containers using this framework can read the credentials.

---

## When To Use This (vs. Access Keys)

| Use SSO when...                                 | Use Access Keys when...                               |
| ----------------------------------------------- | ----------------------------------------------------- |
| Your AWS account uses IAM roles (no IAM users)  | You have permanent access key + secret already issued |
| You want short-lived, auto-rotating credentials | Your environment doesn't have SSO configured          |
| You're running tests as a human user            | You're running tests unattended (CI/CD without SSO)   |
| Your team mandates "no long-lived credentials"  | You're doing local testing with MinIO                 |

---

## Troubleshooting

### Error: `No such profile: <name>`

**Cause:** The profile name in `AWS_PROFILE` doesn't match what's in `~/.aws/config`.

**Fix:**

```bash
# List configured profiles
aws configure list-profiles

# Make sure AWS_PROFILE matches exactly
echo $AWS_PROFILE
```

### Error: `AWS_PROFILE '<name>' resolved to no credentials. Run: aws sso login --profile <name>`

**Cause:** No active SSO session, or the session expired.

**Fix:**

```bash
aws sso login --profile <your-profile-name>
```

### Error: `botocore.exceptions.SSOTokenLoadError`

**Cause:** SSO cache files corrupted or missing.

**Fix:**

```bash
# Clear the SSO cache
rm -rf ~/.aws/sso/cache/

# Log in fresh
aws sso login --profile <your-profile-name>
```

### Container Doesn't See `~/.aws/`

**Cause:** Bind mount not active (container started before SSO setup, or running on a different filesystem).

**Fix:**

```bash
# Stop and restart the tools container
docker compose stop tools
make start-tools-service-only

# Verify mount
docker compose exec tools ls /root/.aws/
```

If still empty, check `docker-compose.yml` includes:

```yaml
volumes:
  - ${HOME}/.aws:/root/.aws:ro
```

### Error: `AccessDenied` When Listing S3

**Cause:** The SSO role doesn't have read permission on this bucket.

**Fix:** Contact the AWS administrator — they'll need to add `s3:GetObject` and `s3:ListBucket` to the role for the target bucket.

### Tests Fail After `aws sso login` Succeeded

**Cause:** `S3_ACCESS_KEY` or `S3_SECRET_KEY` may still be set in `.env`, overriding the SSO profile.

**Fix:** Open the root `.env` file and confirm those two fields are completely empty (no spaces, no quotes — just `=` followed by nothing).

Check which mode the framework is using by inspecting the Robot log:

| Log line                              | What it means                        |
| ------------------------------------- | ------------------------------------ |
| `AWS SSO mode active (profile: ...)`  | ✅ SSO is being used                  |
| `Using explicit S3 access keys (...)` | ❌ Keys are set, SSO is being ignored |
| `Using S3 endpoint: ...`              | ❌ MinIO endpoint is set              |

### Browser Doesn't Open During `aws sso login` (WSL)

**Cause:** WSL doesn't always launch the Windows browser automatically.

**Fix:** Copy the URL printed in the terminal output and paste it into Windows browser manually. AWS CLI prints a fallback URL like:

```
Attempting to automatically open the SSO authorization page in your default browser.
If the browser does not open or you wish to use a different device to authorize this request, open the following URL:

https://device.sso.<region>.amazonaws.com/

Then enter the code:

ABCD-1234
```

Paste the URL into Windows browser, enter the code, complete the login.

### Browser Opens But WSL Doesn't Detect The Completion

**Cause:** WSL-to-browser handshake timing issue.

**Fix:** Wait for the browser-side "approved" message, then return to WSL terminal. If the terminal still spins, press Enter — it may have completed silently.

---

## Why This Approach Is Better

For environments that use IAM roles (no IAM users), SSO has these benefits over long-lived access keys:

| Property                              | Long-Lived Access Keys              | SSO + AssumeRole                             |
| ------------------------------------- | ----------------------------------- | -------------------------------------------- |
| Credential lifetime                   | Forever (until rotated manually)    | 8–12 hours, auto-refreshed                   |
| Where credentials live                | In `.env` files on disk             | In `~/.aws/sso/cache/` (managed by AWS CLI)  |
| Rotation burden                       | Manual every 90 days                | Zero — happens on each login                 |
| If laptop is stolen                   | Keys leak until rotated             | Cached creds expire on their own             |
| Audit trail                           | Shows the IAM user                  | Shows the individual SSO user + assumed role |
| Aligns with role-based security model | ❌ Introduces user-based credentials | ✅ Preserves role-based model                 |

---

