# Configuring the S3 Account for Your Own S3 Instance

How to switch the S3 account from the default local MinIO mock to **your own AWS S3** 

---

## TL;DR

Edit one file:
[`env_files/mock_service_accounts/.env.s3`](../../../../../env_files/mock_service_accounts/.env.s3)

Change four values:

```bash
S3_ENDPOINT=                                      # leave EMPTY for AWS S3
S3_ACCESS_KEY=AKIAIOSFODNN7EXAMPLE                # your AWS access key
S3_SECRET_KEY=wJalrXUtnFEMI/K7MDENG/bPxRfiCY...   # your AWS secret key
S3_REGION=us-east-1                               # your bucket's region
```

Save the file. Every test that uses the `s3_account` will now read from / write to your real S3 on the next run.

---

## What this account is used for

The S3 account (`s3_account` in your SnapLogic project) is used by:

- **Robot Framework tests** — `Upload File To MinIO`, `Download Single File From MinIO`, etc.  ✱
- **SnapLogic pipelines** — any S3 File Reader / Writer / Pipeline parameter that references `s3_account`.
- **The S3 account JSON template** — `test/suite/test_data/accounts_payload/acc_s3.json`, rendered with these env vars.

✱ Note: the keyword names say "MinIO" for legacy reasons, but they all use boto3 under the hood — they work transparently against any S3-compatible service.

---

## Prerequisites — gather these first

Before editing anything, get the following from your S3 provider:

| Item                  | Where to find it (AWS)                                                                                                                                               |
| --------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Access key ID**     | IAM → Users → your user → Security credentials → Access keys                                                                                                         |
| **Secret access key** | Shown ONCE when you create the access key — save it somewhere safe                                                                                                   |
| **Region**            | The region where your bucket lives (e.g., `us-east-1`, `eu-west-1`, `ap-southeast-2`)                                                                                |
| **Bucket name**       | The bucket(s) your tests/pipelines will read/write                                                                                                                   |
| **IAM permissions**   | The access key must have `s3:GetObject`, `s3:PutObject`, `s3:ListBucket`, `s3:DeleteObject` (and `s3:CreateBucket` / `s3:DeleteBucket` if your tests create buckets) |



## Option 1: Real AWS S3

Edit [`env_files/mock_service_accounts/.env.s3`](../../../../../env_files/mock_service_accounts/.env.s3) and set:

```bash
S3_ENDPOINT=                                              # MUST be empty for AWS
S3_ACCESS_KEY=AKIAIOSFODNN7EXAMPLE                        # your access key ID
S3_SECRET_KEY=wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY    # your secret access key
S3_REGION=us-east-1                                       # your bucket's region
```

**Why `S3_ENDPOINT` is empty:** when the endpoint is empty, boto3 auto-routes to `https://s3.<region>.amazonaws.com`. No URL needed — region alone tells it where to go.

---



##  Option 2: Switch back to local MinIO

If you ever need to revert to the default Docker mock:

```bash
S3_ENDPOINT=http://minio:9000
S3_ACCESS_KEY=minioadmin
S3_SECRET_KEY=minioadmin
S3_REGION=us-east-1
```

If the MinIO container isn't running:
```bash
make minio-start
```

---


## How the auto-detect logic works

The framework reads `S3_ENDPOINT` and decides what to do:

```
┌─────────────────────────────────────────────────────────┐
│ S3_ENDPOINT empty  → AWS S3                             │
│                      boto3.client('s3', region=...)      │
│                      Auto-routes to s3.<region>.amazonaws.com │
│                                                          │
│ S3_ENDPOINT set    → MinIO or S3-compatible             │
│                      boto3.client('s3',                  │
│                        endpoint_url='<your URL>',        │
│                        region=...)                       │
└─────────────────────────────────────────────────────────┘
```

This logic lives in `Get S3 Client` in [`test/resources/minio/minio.resource`](../../../../resources/minio/minio.resource) — every keyword that touches S3 calls it internally, so the same Robot tests work against MinIO, AWS, Wasabi, etc. **without code changes**.

---

## Verify your configuration

Run only the connection-validation test:
```bash
make robot-run-tests-no-gp TAGS="connect_to_s3_sample"
```

Look for:
```
CONNECT — Validate MinIO Connection :: ... | PASS |
```

If this passes, your credentials, region, and endpoint URL are correct and your tests are talking to your S3.
If it fails, see Troubleshooting below.

---

## Security — what NOT to do

| Don't                                           | Why                                                                                                                                             |
| ----------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------- |
| ❌ Commit `.env.s3` with real credentials to git | Real AWS keys leak immediately to anyone with repo access. The repo's `.gitignore` should already exclude `.env` files — verify before pushing. |
| ❌ Share access keys in Slack / email            | Use a vault (1Password, AWS Secrets Manager, Vault) to share.                                                                                   |
| ❌ Use the AWS root account's keys               | Create a dedicated IAM user for testing with **only** the S3 permissions it needs.                                                              |
| ❌ Re-use production keys for tests              | If a test wipes a bucket (`Clean Bucket`, `Delete Bucket    force=${TRUE}`), you do NOT want it pointed at production.                          |
| ❌ Hardcode keys in `.robot` files               | Keep them in `.env.s3` only — every keyword reads them via env vars.                                                                            |


## Troubleshooting

| Symptom                                 | Likely cause                                   | Fix                                                                           |
| --------------------------------------- | ---------------------------------------------- | ----------------------------------------------------------------------------- |
| `InvalidAccessKeyId`                    | Access key typo or doesn't exist               | Re-paste from IAM Security credentials page                                   |
| `SignatureDoesNotMatch`                 | Secret key typo                                | Re-paste; check for trailing whitespace                                       |
| `AccessDenied` on `ListBucket`          | IAM policy missing                             | Add `s3:ListBucket` for the bucket ARN                                        |
| `NoSuchBucket`                          | Bucket doesn't exist OR region mismatch        | Confirm bucket name; confirm `S3_REGION` matches the bucket's region          |
| `Could not connect to the endpoint URL` | Wrong endpoint or network blocked              | For AWS, `S3_ENDPOINT` must be EMPTY. For S3-compatible, double-check the URL |
| `IllegalLocationConstraintException`    | Tried to create a bucket in the wrong region   | When using `Create Bucket` outside `us-east-1`, pass `region=...` explicitly  |
| `expired token` or `InvalidToken`       | Using temporary credentials (STS) that expired | Refresh via `aws sts get-session-token` and update `.env.s3`                  |

---

## Related docs

- [`accessing_minio.md`](./accessing_minio.md) — how to access the local MinIO mock (web console, AWS CLI, `mc`)
- [`s3_connection_operations.md`](./s3_connection_operations.md) — full keyword reference & test inventory
- [`s3_connection_operations.robot`](./s3_connection_operations.robot) — runnable test suite
