# Accessing MinIO — Credentials & Access Methods

How to log into the local MinIO container, browse buckets, and run S3 commands against it from outside the Robot Framework tests.

---

## TL;DR

| What | Value |
|---|---|
| **Web console** | http://localhost:9011 |
| **Username** | `minioadmin` |
| **Password** | `minioadmin` |
| **S3 API endpoint (from host machine)** | http://localhost:9010 |
| **S3 API endpoint (from inside Docker)** | http://minio:9000 |
| **Region** | `us-east-1` |

Open http://localhost:9011 in your browser, log in with `minioadmin` / `minioadmin`, and you'll see every bucket and file.

---

## Where these values come from

File: [`env_files/mock_service_accounts/.env.s3`](../../../../../env_files/mock_service_accounts/.env.s3)

```bash
S3_ENDPOINT=http://minio:9000        # used by tools/Groundplex inside Docker
S3_ACCESS_KEY=minioadmin
S3_SECRET_KEY=minioadmin
S3_REGION=us-east-1

MINIO_API_PORT=9010                  # host port → container port 9000
MINIO_CONSOLE_PORT=9011              # host port → container port 9001
```

The same credentials are wired into [`docker/minio/docker-compose.minio.yml`](../../../../../docker/minio/docker-compose.minio.yml) as `MINIO_ROOT_USER` / `MINIO_ROOT_PASSWORD`. Both must match — don't change just one.

---

## Why two endpoints?

MinIO listens on **two ports** with **two purposes**:

```
        Host machine                    Docker network (snaplogicnet)
┌──────────────────────────┐          ┌───────────────────────────────┐
│ Browser → :9011 ─────────┼──────────┤→ minio:9001  (web console)    │
│ AWS CLI → :9010 ─────────┼──────────┤→ minio:9000  (S3 API)         │
│                          │          │                                │
│                          │          │ tools container ─→ minio:9000 │
│                          │          │ groundplex     ─→ minio:9000  │
└──────────────────────────┘          └───────────────────────────────┘
```

| Where you are | Use this endpoint | Why |
|---|---|---|
| Browser, AWS CLI on host, mc on host | `http://localhost:9010` (API) or `http://localhost:9011` (console) | Host port mappings |
| Robot Framework tests (tools container) | `http://minio:9000` | Inside Docker DNS, container internal port |
| SnapLogic Groundplex (in Docker) | `http://minio:9000` | Same as above |
| Pipelines running on Groundplex | `http://minio:9000` | Same — set in S3 account JSON |

**Mistake to avoid:** using `http://minio:9000` from your host browser/CLI. The DNS name `minio` only resolves inside the `snaplogicnet` bridge network.

---

## Three ways to access

### 1. Web console (easiest — point and click)

```
URL:      http://localhost:9011
Username: minioadmin
Password: minioadmin
```

You can:
- Browse buckets
- Upload / download files
- View object metadata (size, content-type, ETag, last-modified)
- Manage service accounts and access keys
- See server stats (storage usage, IO metrics)

### 2. AWS CLI

```bash
# One-time profile setup
aws configure --profile minio
#   AWS Access Key ID:     minioadmin
#   AWS Secret Access Key: minioadmin
#   Default region name:   us-east-1
#   Default output format: json

# Common commands — pass --endpoint-url every time
aws --profile minio --endpoint-url http://localhost:9010 s3 ls
aws --profile minio --endpoint-url http://localhost:9010 s3 ls s3://test-bucket/
aws --profile minio --endpoint-url http://localhost:9010 s3 ls s3://test-bucket/ --recursive

# Upload / download / delete
aws --profile minio --endpoint-url http://localhost:9010 s3 cp file.txt s3://test-bucket/tutorial/
aws --profile minio --endpoint-url http://localhost:9010 s3 cp s3://test-bucket/tutorial/file.txt ./
aws --profile minio --endpoint-url http://localhost:9010 s3 rm s3://test-bucket/tutorial/file.txt

# Bucket operations
aws --profile minio --endpoint-url http://localhost:9010 s3 mb s3://my-new-bucket
aws --profile minio --endpoint-url http://localhost:9010 s3 rb s3://my-new-bucket --force
```

**Tip:** add an alias to your shell to save typing:

```bash
alias mins3='aws --profile minio --endpoint-url http://localhost:9010 s3'
mins3 ls s3://test-bucket/
```

### 3. MinIO Client (`mc`) — most powerful

`mc` is MinIO's official CLI. Better tab-completion, richer output, and admin commands the AWS CLI doesn't have.

```bash
# Install
brew install minio/stable/mc        # macOS
# OR
brew install minio-mc               # alternative tap

# Linux:
wget https://dl.min.io/client/mc/release/linux-amd64/mc -O ~/bin/mc
chmod +x ~/bin/mc

# One-time alias for our local MinIO
mc alias set local http://localhost:9010 minioadmin minioadmin

# Common commands
mc ls local                              # list buckets
mc ls local/test-bucket --recursive      # list all objects in a bucket
mc cat local/test-bucket/some.txt        # view file content
mc cp file.txt local/test-bucket/        # upload
mc cp local/test-bucket/some.txt ./      # download
mc rm local/test-bucket/some.txt         # delete one object
mc rm local/test-bucket --recursive --force    # empty a bucket

# Bucket operations
mc mb local/my-new-bucket                # make bucket
mc rb local/my-new-bucket --force        # remove bucket (force = empty first)

# Server info
mc admin info local                      # capacity, uptime, drives
mc admin trace local                     # live request trace (great for debugging)
```

---

## Quick health check

```bash
# Container status
make minio-status

# OR directly
docker ps | grep minio

# OR ping the API
curl http://localhost:9010/minio/health/live    # → 200 OK if healthy
```

If MinIO isn't running:
```bash
make minio-start
```

If a connection times out, check the right port:
- Browser → `9011` (console)
- API client → `9010` (S3 API)

---

## Inside SnapLogic

The S3 account created by the tutorial test (`acc_s3.json`) uses **the same credentials** with endpoint `http://minio:9000` (the in-Docker name). That's why:

- Pipelines running on Groundplex read/write the same buckets you see in the web console.
- Files uploaded via `Upload File To MinIO` show up immediately when you browse http://localhost:9011.
- You can debug pipeline output by inspecting MinIO directly while/after a test runs.

---

## Common questions

### Can I change the password?

Yes — but you must update **both** places consistently:

1. `env_files/mock_service_accounts/.env.s3` — `S3_SECRET_KEY=newpassword`
2. `docker/minio/docker-compose.minio.yml` — `MINIO_ROOT_PASSWORD=newpassword`

Then restart MinIO:
```bash
make minio-stop
make minio-start
```

For local dev, sticking with `minioadmin` / `minioadmin` is fine — it's a local-only mock, not a production secret.

### Are buckets persistent across restarts?

Yes — MinIO stores data in a Docker volume. Stopping/starting the container preserves your buckets and objects. To wipe:

```bash
make minio-stop
docker volume rm <volume-name>     # check `docker volume ls | grep minio`
make minio-start
```

The `snaplogic-minio-setup` container will recreate `test-bucket` automatically on next startup.

### Why do my Robot tests use `minio:9000` but I use `localhost:9010` from the CLI?

Robot tests run inside the `tools` container, which is on the `snaplogicnet` Docker bridge network. Inside that network, `minio:9000` resolves via Docker DNS to the MinIO container's internal port. From your host machine, you use the host port mapping (`localhost:9010`).

It's the same MinIO server — just two different network paths to it.

### Can I use this with real AWS S3?

Not the local MinIO — but the same Robot keywords work against AWS S3 with different env vars. See the tutorial doc [`s3_connection_operations.md`](./s3_connection_operations.md) → "Prerequisites" for the AWS toggle.
