# Robot Tests vs Jupyter Notebook — How They Relate

The folder contains both [`s3_connection_operations.robot`](./s3_connection_operations.robot) (Robot Framework tests) and [`s3_connection_operations.ipynb`](./s3_connection_operations.ipynb) (Jupyter notebook). This doc explains the relationship between them.

---

## TL;DR

**Not exactly equivalent — they're parallel, not the same thing.**
The notebook uses **raw `boto3` calls** (the lower-level Python that the Robot keywords *internally use*). It mirrors what the Robot tests *do*, but it doesn't call the Robot keywords themselves.

Think of it as: Robot keyword **wraps** boto3. Notebook **uses** boto3 directly. Both achieve the same outcome (file uploaded to S3) but at different abstraction levels.

---

## The three layers of the same operation

```
┌──────────────────────────────────────────────────────────────────┐
│  LEVEL 1 — Robot test (declarative)                              │
│                                                                  │
│  UPLOAD — Upload File To MinIO                                   │
│      Upload File To MinIO  ${LOCAL_FILE}  ${BUCKET}  ${KEY}      │
│                                                                  │
└────────────────────────┬─────────────────────────────────────────┘
                         │ calls
                         ▼
┌──────────────────────────────────────────────────────────────────┐
│  LEVEL 2 — Robot keyword in minio.resource (Python via Evaluate) │
│                                                                  │
│  Upload File To MinIO                                            │
│      [Arguments]    ${local}    ${bucket}    ${key}              │
│      ${s3_client}=    Get MinIO S3 Client                        │
│      Evaluate    $s3_client.upload_file(...)                     │
│      Log    ✅ uploaded                                          │
│                                                                  │
└────────────────────────┬─────────────────────────────────────────┘
                         │ calls
                         ▼
┌──────────────────────────────────────────────────────────────────┐
│  LEVEL 3 — Raw boto3 (Python)                                    │
│                                                                  │
│  s3.upload_file(local_file, bucket, key)                         │
│                                                                  │
└──────────────────────────────────────────────────────────────────┘
```

The **notebook uses Level 3** directly. The **Robot tests stack at Level 1**. Both end up making the same HTTP call to S3 — the difference is what code path you traverse to get there.

---

## Concrete side-by-side — the same upload

### Robot test (in `s3_connection_operations.robot`)

```robot
*** Test Cases ***
UPLOAD — Upload File To MinIO
    Upload File To MinIO
    ...    ${LOCAL_SAMPLE_FILE}
    ...    ${BUCKET_NAME}
    ...    ${OBJECT_KEY_1}
```

### Robot keyword definition (in `minio.resource`)

```robot
Upload File To MinIO
    [Arguments]    ${local_file_path}    ${bucket_name}    ${object_key}
    ${s3_client}=    Get MinIO S3 Client
    TRY
        Evaluate    $s3_client.upload_file('${local_file_path}', '${bucket_name}', '${object_key}')
        Log    ✅ File uploaded successfully    console=yes
    EXCEPT    AS    ${error}
        Fail    Failed to upload: ${error}
    END
```

### Notebook cell (raw Python — `s3_connection_operations.ipynb`)

```python
s3.upload_file(LOCAL_FILE, BUCKET_NAME, OBJECT_KEY)
print(f"📤 Uploaded {LOCAL_FILE} → s3://{BUCKET_NAME}/{OBJECT_KEY}")
```

All three accomplish the same thing — a file lands in S3. The notebook strips away the Robot wrapper and shows what's happening underneath.

---

## What "equivalent" means in different senses

| Equivalent in… | Robot vs Notebook? | Why |
|---|---|---|
| **End result** (file on S3) | ✅ Yes | Both produce the same final state |
| **Python library used** (boto3) | ✅ Yes | Both ultimately call boto3 |
| **Code shape / abstraction** | ❌ No | Robot wraps, notebook is raw |
| **Error handling** | ❌ No | Robot has TRY/EXCEPT/Fail; notebook is "exception means stop" |
| **Logging style** | ❌ No | Robot logs to HTML report; notebook prints to cell output |
| **Test assertions** | ❌ No | Robot has `Should Be True`; notebook has none unless you add them |
| **Variable scope** | ❌ No | Robot: `${VARS}` and Suite/Test/Global scope; notebook: Python `=` and module-level |
| **Discovery / orchestration** | ❌ No | Robot has `[Tags]`, Suite Setup, etc.; notebook is manual cell-by-cell |

---

## What the notebook does NOT do

The notebook does **not**:
- Run Robot keywords (it can't — Robot keywords only run inside the `robot` command)
- Use `${variables}` from Robot (those are Robot-side; the notebook has Python variables)
- Trigger Robot's HTML report (`log.html`, `report.html`)
- Apply Robot's `[Tags]`, `Suite Setup`, `Documentation`, etc.
- Get picked up by `make robot-run-tests-no-gp` (notebooks aren't tests)

It's a **completely independent execution path** that happens to talk to the same MinIO server.

---

## When to use which

| Scenario | Use this |
|---|---|
| Run automated tests in CI | **Robot** — declarative, tagged, generates HTML reports |
| Investigate "why is this S3 call failing?" interactively | **Notebook** — fast iteration, see results inline |
| Prototype a new operation before writing a Robot keyword for it | **Notebook** — try it, see it work, then port to keyword |
| Demo the framework to a stakeholder | **Robot** — shows the "test case" mental model |
| Teach someone what S3 looks like in Python | **Notebook** — strips away the Robot abstraction |
| Test failure analysis with logs and reports | **Robot** — `report-*.html` shows pass/fail tree |
| Throw-away exploration ("what does `head_object` return?") | **Notebook** — inspect the dict in 2 seconds |

---

## A subtle but important point

The notebook is **Python code that mimics what the Robot tests do** — it's an interactive, simplified version. If a customer wants to know *exactly* what happens when their Robot test runs, the notebook is a good reading aid, but the **source of truth** is [`minio.resource`](../../../../../resources/minio/minio.resource) (the keyword definitions) — that's the actual code Robot runs.

| Role | File |
|---|---|
| Source of truth for Robot tests | `minio.resource` keyword definitions |
| Test-author entry point | `s3_connection_operations.robot` |
| Test walkthrough doc | `s3_connection_operations.md` |
| Interactive learning aid | `s3_connection_operations.ipynb` |
| **Mental-model explainer (this file)** | `robot_vs_notebook.md` |

The Robot tests and the notebook are **mirror images**, not duplicates. Editing one does not affect the other.

---

## Practical implication for customers

If you tweak the notebook — say, change `head_object` to fetch a custom header — the Robot tests **don't change**. They still go through the keyword in `minio.resource`. To make a new behavior part of the official test suite, port your notebook discovery into the Robot keyword library.

```
notebook (try it)   →   minio.resource (codify it)   →   .robot test (assert it)
```

That's the typical "explore → keyword → test" flow.

---

## In one sentence

**The notebook is a Python re-implementation that produces the same end state as the Robot tests, using the same underlying library (boto3), but it does NOT execute the Robot keywords themselves — it bypasses Robot entirely.**

---

## Related docs

- [`s3_connection_operations.md`](./s3_connection_operations.md) — full tutorial walkthrough of the Robot tests
- [`s3_connection_operations.robot`](./s3_connection_operations.robot) — runnable Robot suite
- [`s3_connection_operations.ipynb`](./s3_connection_operations.ipynb) — interactive notebook (run with `make jupyter-start`)
- [`how_to_access_local_minio.md`](./how_to_access_local_minio.md) — log into MinIO directly
- [`how_to_connect_to_prod_instance.md`](./how_to_connect_to_prod_instance.md) — switch to AWS S3
