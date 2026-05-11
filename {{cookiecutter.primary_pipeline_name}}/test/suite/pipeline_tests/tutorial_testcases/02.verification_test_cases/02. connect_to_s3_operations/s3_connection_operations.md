# S3 / MinIO Operations Tutorial

> 📓 **Want to run this interactively?**
> 1. Start Jupyter: `make jupyter-start`
> 2. Open the notebook in one click: [s3_connection_operations.ipynb](http://localhost:8888/lab/tree/test/suite/pipeline_tests/tutorial_testcases/02.verification_test_cases/02.%20connect_to_s3_operations/s3_connection_operations.ipynb)
>
> The link only works while Jupyter is running. If it doesn't open, try `http://localhost:8888/lab` and navigate to the file manually.

> 🔍 **Notebook vs Robot tests** — what's the difference? See [robot_vs_notebook.md](./robot_vs_notebook.md).

A walk-through of every commonly-used S3 keyword in `test/resources/minio/minio.resource`, demonstrated by the companion file [`s3_connection_operations.robot`](./s3_connection_operations.robot).

---

## TL;DR

- **19 test cases**, each demonstrates **one keyword**.
- Works against both **MinIO (Docker)** and **real AWS S3** — same keywords, configured via `S3_ENDPOINT` in `env_files/mock_service_accounts/.env.s3`.
- Suite is **idempotent** — re-running it works. Suite Teardown cleans up local files and bucket contents even if a test fails mid-way.
- Run with: `make robot-run-tests-no-gp TAGS="connect_to_s3_sample"`

---

## Prerequisites

| What | How |
|---|---|
| MinIO container running | `make minio-start` (or `make start-services`) |
| S3 account exists in SnapLogic project | First test (`Create Account`) handles this |
| Bucket `test-bucket` exists | Auto-created by `snaplogic-minio-setup` container at startup |
| `boto3` Python package | Already in tools container — no setup needed |

For real AWS S3 instead of MinIO, edit `env_files/mock_service_accounts/.env.s3`:

```bash
# Clear S3_ENDPOINT to switch from MinIO to AWS
S3_ENDPOINT=
S3_ACCESS_KEY=AKIA...
S3_SECRET_KEY=...
S3_REGION=us-east-1
```

The framework auto-detects: endpoint set → MinIO/compatible; endpoint empty → AWS S3.

---

## S3 concepts — what S3 actually has

S3 is a **flat key-value store** — there are no real folders, no directories, no hierarchy. Just objects identified by string keys.

| Concept | What it really is |
|---|---|
| **Bucket** | A namespace — a top-level container for objects. |
| **Object** | A single file you uploaded — has a *key* (the full path-like name) and bytes (the file content). |
| **Key** | The string name of the object — can contain `/` characters, but those are just normal characters to S3. |
| **Prefix** | Any leading substring of a key — e.g. `tutorial/` is a prefix of `tutorial/sample.txt`. |
| ~~Folder~~ | **Not a real S3 concept.** What looks like a folder in the MinIO console is just the UI rendering `/` characters in keys as a tree. |

### Why this matters when you read the keywords

When a keyword takes `${object_key}` — that's the **full key**, including any slashes. `tutorial/data/sample.csv` is one key, not three folders + a filename.

When a keyword takes `${prefix}` (like `Clean Bucket By Prefix`) — that's a **string match against the start of the key**. `tutorial/` matches everything starting with those 9 characters: `tutorial/sample.txt`, `tutorial/data/sample.csv`, even `tutorial/extra-junk.bin`. **The trailing slash matters** — `tutorial` (no slash) would also match `tutorial-readme.txt`.

### Concrete example

After the tutorial uploads its 3 files, the bucket contains exactly **three objects**:

```
Object 1 → key: tutorial/sample.txt              bytes: "Hello from..."
Object 2 → key: tutorial/data/sample.csv         bytes: "id,name\n..."
Object 3 → key: tutorial/data/sample.json        bytes: '{"run_id": ...}'
```

There is **no** "folder object" called `tutorial/` and **no** "folder object" called `tutorial/data/`. The web console draws a tree to make the slashes feel like folders, but they're just characters in the keys.

---

## Quick mental model

```
┌─────────────────────────────────────────────────────────────────┐
│  1. ACCOUNT       → Create SnapLogic S3 account                 │
│  2. CONNECT       → Validate connection works                   │
│  3-4. BUCKET      → Create / check buckets exist                │
│  5.  UPLOAD       → Push a local file to S3                     │
│  6-7. INSPECT     → Check object exists / get metadata          │
│  8-10. SEARCH     → List, find by extension, find specific      │
│  11-15. DOWNLOAD  → Single, content, pattern, all               │
│  16-17. VALIDATE  → Non-empty check, comprehensive validate     │
│  18-19. CLEAN     → By prefix, delete bucket                    │
└─────────────────────────────────────────────────────────────────┘
```

Files are isolated under the prefix `tutorial/` inside `test-bucket` so the suite never collides with `extract/`, `output/`, `config/` used by other tests.

---

## Keyword reference

### Connection

#### `Validate MinIO Connection`
Confirms boto3 can reach the configured S3 endpoint and authenticate.

```robot
${ok}=    Validate MinIO Connection
Should Be True    ${ok}
```

**When to use:** sanity check at the start of any S3-touching test. Fails fast if credentials or endpoint are wrong.

---

### Bucket lifecycle

#### `Create Bucket    ${bucket_name}    ${region}=${EMPTY}    ${fail_if_exists}=${FALSE}`
Idempotent by default — running twice does NOT fail.

```robot
# Idempotent (recommended for tests)
Create Bucket    tutorial-bucket

# Strict — fail if it already exists
Create Bucket    exclusive-bucket    fail_if_exists=${TRUE}

# AWS S3 in eu-west-1
Create Bucket    my-eu-bucket    region=eu-west-1
```

**Catches:** `BucketAlreadyOwnedByYou`, `BucketAlreadyExists` → idempotent skip (default) or fail (opt-in).

#### `Check Bucket Exists    ${bucket_name}`
Returns `${TRUE}` / `${FALSE}` — does NOT raise on missing buckets.

```robot
${exists}=    Check Bucket Exists    test-bucket
```

#### `Delete Bucket    ${bucket_name}    ${force}=${FALSE}    ${fail_if_missing}=${FALSE}`
Idempotent on missing buckets. Fails on non-empty unless `force=${TRUE}`.

```robot
# Idempotent — fails if non-empty
Delete Bucket    tutorial-bucket

# Force — empties then deletes in one call
Delete Bucket    tutorial-bucket    force=${TRUE}

# Strict — fail if missing
Delete Bucket    must-exist-bucket    fail_if_missing=${TRUE}
```

**Catches:** `NoSuchBucket` / `NotFound` → idempotent skip (default). `BucketNotEmpty` → clear error message.

---

### Upload

#### `Upload File To MinIO    ${local_file}    ${bucket}    ${object_key}`
Reads as: *"Upload `local_file` to `s3://bucket/object_key`"*.

```robot
Upload File To MinIO    /tmp/data.csv    test-bucket    tutorial/data/sample.csv
```

The `object_key` can include folder paths — they're created automatically.

---

### Existence & metadata

#### `Check Object Exists    ${bucket}    ${object_key}`
Returns boolean. Use after upload to confirm the file landed.

```robot
${exists}=    Check Object Exists    test-bucket    tutorial/sample.txt
```

#### `Get Object Metadata    ${bucket}    ${object_key}`
Returns the boto3 `head_object` dict — `ContentLength`, `ETag`, `LastModified`, `ContentType`, etc.

```robot
${metadata}=    Get Object Metadata    test-bucket    tutorial/sample.txt
${size}=        Evaluate    $metadata.get('ContentLength', 0)
```

---

### Search & list

#### `List Objects In Bucket    ${bucket}`
Returns a list of every key in the bucket (no filtering).

```robot
@{all_keys}=    List Objects In Bucket    test-bucket
```

#### `Find Files In Bucket By Extension    ${bucket}    ${extension}    @{path_filters}`
Returns `(files_list, count)` — sorted descending so element `[0]` is the latest.

**Default path filter:** `[extract/, output/]`. Pass your own prefix(es) if you store files elsewhere.

```robot
# Default — looks under extract/ and output/
${files}    ${count}=    Find Files In Bucket By Extension    test-bucket    .csv

# Custom prefix
${files}    ${count}=    Find Files In Bucket By Extension    test-bucket    .txt    tutorial/

# All paths (no filtering)
${files}    ${count}=    Find Files In Bucket By Extension    test-bucket    .json    path_filters=[]
```

#### `Find Specific File In Bucket    ${bucket}    ${expected_key}    ${extension}    @{path_filters}`
Returns `(found_bool, candidates_list)` — useful for assertion + debug context.

```robot
${found}    ${candidates}=    Find Specific File In Bucket    test-bucket    tutorial/sample.txt    .txt    tutorial/
Should Be True    ${found}    msg=Expected file not found. Candidates: ${candidates}
```

---

### Download

#### `Download Single File From MinIO    ${download_dir}    ${bucket}    ${object_key}`
Saves to `${download_dir}/${object_key}` (preserves the key's folder structure).

```robot
Download Single File From MinIO    /tmp/downloads    test-bucket    tutorial/sample.txt
# → /tmp/downloads/tutorial/sample.txt
```

#### `Download And Get File Content    ${bucket}    ${download_dir}    ${object_key}`
Same as above but **returns the file content as a string** — convenient for assertions.

```robot
${content}=    Download And Get File Content    test-bucket    /tmp/downloads    tutorial/sample.txt
Should Contain    ${content}    expected_marker
```

#### `Download Files By Pattern    ${download_dir}    ${bucket}    ${pattern}`
Downloads every object whose key contains `pattern` (substring match — not glob).

```robot
@{downloaded}=    Download Files By Pattern    /tmp/downloads    test-bucket    tutorial/data/
```

#### `Download All Files From Bucket    ${download_dir}    ${bucket}`
Downloads **every** object in the bucket. Use `Clean Bucket` first if you need isolation.

```robot
@{downloaded}=    Download All Files From Bucket    /tmp/downloads    test-bucket
```

---

### Validation

#### `Verify All Files Are Non Empty In Bucket    ${bucket}    ${file_list}`
Iterates a list of object keys, asserts each has `ContentLength > 0`.

```robot
@{keys}=    Create List    tutorial/sample.txt    tutorial/data/sample.csv
Verify All Files Are Non Empty In Bucket    test-bucket    ${keys}
```

#### `Validate Downloaded File Template    ${local_path}    min_size_bytes=0    expected_extension=${EMPTY}`
Comprehensive local-file check: exists, meets min size, has expected extension, content is readable.

```robot
Validate Downloaded File Template    /tmp/downloads/tutorial/sample.txt
...    min_size_bytes=10
...    expected_extension=.txt
```

---

### Cleanup

#### `Clean Bucket    ${bucket}`
Deletes every object in the bucket. Bucket itself remains.

#### `Clean Bucket By Prefix    ${bucket}    ${prefix}`
Deletes only objects whose key starts with `prefix`. Use when many tests share a bucket but each owns a folder.

```robot
Clean Bucket By Prefix    test-bucket    tutorial/
```

---

## Test inventory

All 19 tests in the suite, in execution order:

| # | Section | Test name | Keyword demonstrated |
|---|---|---|---|
| 1 | ACCOUNT | Create Account | `Create Account From Template` |
| 2 | CONNECT | CONNECT — Validate MinIO Connection | `Validate MinIO Connection` |
| 3 | BUCKET | BUCKET — Create Bucket (idempotent) | `Create Bucket` (called twice to prove idempotency) |
| 4 | BUCKET | BUCKET — Check Bucket Exists | `Check Bucket Exists` (positive + negative) |
| 5 | UPLOAD | UPLOAD — Upload File To MinIO | `Upload File To MinIO` |
| 6 | EXISTENCE | EXISTENCE — Check Object Exists | `Check Object Exists` (positive + negative) |
| 7 | METADATA | METADATA — Get Object Metadata | `Get Object Metadata` |
| 8 | LIST | LIST — List Objects In Bucket | `List Objects In Bucket` |
| 9 | SEARCH | SEARCH — Find Files In Bucket By Extension | `Find Files In Bucket By Extension` |
| 10 | SEARCH | SEARCH — Find Specific File In Bucket | `Find Specific File In Bucket` |
| 11 | DOWNLOAD | DOWNLOAD — Download Single File From MinIO | `Download Single File From MinIO` |
| 12 | DOWNLOAD | DOWNLOAD — Download And Get File Content | `Download And Get File Content` |
| 13 | UPLOAD | UPLOAD — Upload Two More Files (setup) | `Upload File To MinIO` × 2 (setup for batch tests) |
| 14 | DOWNLOAD | DOWNLOAD — Download Files By Pattern | `Download Files By Pattern` |
| 15 | DOWNLOAD | DOWNLOAD — Download All Files From Bucket | `Download All Files From Bucket` |
| 16 | VALIDATE | VALIDATE — Verify All Files Are Non Empty In Bucket | `Verify All Files Are Non Empty In Bucket` |
| 17 | VALIDATE | VALIDATE — Validate Downloaded File Template | `Validate Downloaded File Template` |
| 18 | CLEAN | CLEAN — Clean Bucket By Prefix | `Clean Bucket By Prefix` |
| 19 | CLEAN | CLEAN — Delete Bucket (idempotent) | `Delete Bucket` (called twice to prove idempotency) |

---

## Patterns worth copying

### 1. Use a prefix to isolate your test from others

```robot
${TUTORIAL_BUCKET}    test-bucket
${TUTORIAL_PREFIX}    tutorial/

# All your object keys start with the prefix
${OBJECT_KEY_1}    ${TUTORIAL_PREFIX}sample.txt
${OBJECT_KEY_2}    ${TUTORIAL_PREFIX}data/sample.csv
```

Why: many tests share `test-bucket`. Prefix isolation means:
- Cleanup is one call: `Clean Bucket By Prefix    test-bucket    tutorial/`
- Other tests' files never trigger your assertions
- Re-running your suite never sees stale files from a prior run

### 2. Pre-clean in Suite Setup, post-clean in Suite Teardown

```robot
Suite Setup       Initialize Tutorial
Suite Teardown    Cleanup Tutorial

Initialize Tutorial
    ...
    Run Keyword And Ignore Error    Clean Bucket By Prefix    ${TUTORIAL_BUCKET}    ${TUTORIAL_PREFIX}

Cleanup Tutorial
    Run Keyword And Ignore Error    Clean Bucket By Prefix    ${TUTORIAL_BUCKET}    ${TUTORIAL_PREFIX}
    Run Keyword And Ignore Error    Delete Bucket    ${TUTORIAL_OWN_BUCKET}    force=${TRUE}
```

`Run Keyword And Ignore Error` ensures cleanup never fails the suite — even if the bucket is missing or already clean.

### 3. Prefer idempotent operations

| Operation | Idempotent variant |
|---|---|
| Create a bucket | `Create Bucket` (default) — skip if exists |
| Delete a bucket | `Delete Bucket` (default) — skip if missing |
| Drop tutorial files | `Clean Bucket By Prefix` — no error if zero files |

Idempotent operations make tests **re-runnable** and **insensitive to failure mid-suite**.

### 4. Pass `path_filters` when your files don't live in `extract/` or `output/`

`Find Files In Bucket By Extension` and `Find Specific File In Bucket` default to scanning `extract/` and `output/` (a historical convention from the data-pipeline tests). If your files live elsewhere, **pass your prefix explicitly**:

```robot
${files}    ${count}=    Find Files In Bucket By Extension    test-bucket    .csv    tutorial/
```

---

## Running the suite

```bash
# 1. Make sure MinIO is up
make minio-start

# 2. Run the tutorial
make robot-run-tests-no-gp TAGS="connect_to_s3_sample"
```

Expected: **19 tests, 19 passed, 0 failed**.

---

## Where to look when something fails

| Symptom | Likely cause | Where to check |
|---|---|---|
| `Connection refused` on port 9000 | MinIO container not running | `make minio-status` → `make minio-start` |
| `InvalidAccessKeyId` | Wrong creds in `.env.s3` | `env_files/mock_service_accounts/.env.s3` |
| `NoSuchBucket: test-bucket` | Setup container didn't run | `docker logs snaplogic-minio-setup` |
| `Find Specific File` returns nothing | Default path filter excludes your prefix | Pass `path_filters=['your-prefix/']` |
| Tutorial bucket leaked across runs | Suite Teardown didn't run (e.g. KeyboardInterrupt) | `Delete Bucket    s3-tutorial-bucket    force=${TRUE}` manually |

For real AWS S3:
- Confirm `S3_REGION` matches the bucket's region
- Outside `us-east-1`, pass `region=...` to `Create Bucket` so it sends `CreateBucketConfiguration`

---

## Keywords NOT covered (and why)

| Keyword | Why skipped |
|---|---|
| `Wait Until New S3 Files Appear` | Polls for files written by a running pipeline — needs pipeline execution context |
| `Get Current And Previous File Content From Bucket` | Compound — depends on having ≥2 timestamped files |
| `Download And Validate File From Bucket` | Compound — combines Download Single + Validate; covered by demonstrating each piece separately |
| `Validate Multiple Downloaded Files` | Loops `Validate Downloaded File Template`; covered by single-file version |
| `Get S3 Client` / `Get MinIO S3 Client` | Internal helpers — every other keyword calls them implicitly |
| `Get File Content Safely` | Local-filesystem helper, not S3-specific |
| `Get Directory From Path` / `Remove Directory If Exists` | Local-filesystem helpers |
| `Clean Bucket` (vs `Clean Bucket By Prefix`) | Same shape as the prefix variant, broader scope |

These aren't broken — just not the right shape for a one-keyword-per-test tutorial. Use them in real tests as needed.
