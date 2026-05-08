# Compare CSV Keywords — Explained

A visual deep-dive into the two CSV-comparison keywords from [`csv_validations.resource`](../../../../resources/common/csv_validations.resource):

- `Compare CSV Files Template` — basic byte/value comparison
- `Compare CSV Files With Exclusions Template` — same, but skips chosen columns

Every argument is explained with a tiny CSV example so you can see exactly what each knob does.

---

## TL;DR

```
┌─────────────────────────────────────────────────────────────────┐
│                                                                 │
│   Plain                          With Exclusions                │
│   ─────                          ────────────────               │
│   Compares every cell            Compares every cell EXCEPT     │
│   Header to header               the columns you exclude        │
│   Row by row                                                    │
│                                  Use when files contain         │
│   Use when CSVs are              non-deterministic columns      │
│   fully deterministic            (timestamps, run IDs, UUIDs)   │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

Both return the same dict: `{status, total_differences}`. Both fail the test if `expected_status` doesn't match the actual outcome.

---

## Visual: how each keyword sees a CSV

Imagine two CSV files where everything matches except one column:

```
file1 (actual)                       file2 (expected)
─────────────────────────────        ─────────────────────────────
id, name,  salary, ts                id, name,  salary, ts
 1, Alice, 80000,  2026-05-08         1, Alice, 80000,  2026-05-07   ← different
 2, Bob,   65000,  2026-05-08         2, Bob,   65000,  2026-05-07   ← different
 3, Carol, 95000,  2026-05-08         3, Carol, 95000,  2026-05-07   ← different
─────────────────────────────        ─────────────────────────────
```

### Plain keyword sees:
```
id  name   salary  ts            ← every column compared
 ✓    ✓      ✓     ✗
 ✓    ✓      ✓     ✗
 ✓    ✓      ✓     ✗
                                    Result: DIFFERENT (3 cells differ)
```

### Exclusions keyword (excluding `ts`) sees:
```
id  name   salary  [ts removed]  ← ts column dropped from both files
 ✓    ✓      ✓
 ✓    ✓      ✓
 ✓    ✓      ✓
                                    Result: IDENTICAL (0 cells differ)
```

Same input files. Different result. **The exclusion is the deciding factor.**

---

## Keyword 1: `Compare CSV Files Template`

### Signature

```robot
Compare CSV Files Template
...    ${file1_path}                  ← positional 1
...    ${file2_path}                  ← positional 2
...    ${ignore_order}                ← positional 3
...    ${show_details}                ← positional 4
...    ${expected_status}             ← positional 5
```

### Argument reference

| # | Argument | Type | Example | What it does |
|---|---|---|---|---|
| 1 | `file1_path` | string (path) | `${CURDIR}/data/actual.csv` | The "actual output" CSV |
| 2 | `file2_path` | string (path) | `${CURDIR}/data/expected.csv` | The "baseline" CSV to compare against |
| 3 | `ignore_order` | `${TRUE}` / `${FALSE}` | `${TRUE}` | If TRUE, row order doesn't matter |
| 4 | `show_details` | `${TRUE}` / `${FALSE}` | `${TRUE}` | If TRUE, prints every differing cell to the log |
| 5 | `expected_status` | `IDENTICAL` / `DIFFERENT` / `SUBSET` | `IDENTICAL` | What the test expects the result to be |

### Returns

```python
{
    'status': 'IDENTICAL',          # or 'DIFFERENT' / 'SUBSET'
    'total_differences': 0          # number of differing cells
}
```

The keyword **asserts** `status == expected_status` and fails the test if they don't match.

### Visual: each argument's effect

#### `ignore_order`

```
file1                file2                ignore_order=FALSE     ignore_order=TRUE
─────                ─────                ──────────────────     ────────────────
id, name             id, name
 1, Alice             3, Carol
 2, Bob               1, Alice            DIFFERENT              IDENTICAL
 3, Carol             2, Bob              (rows out of order)    (same rows)
```

| ignore_order | When to use |
|---|---|
| `${FALSE}` (default) | Strict order matters — you wrote a `SELECT ... ORDER BY id` query, expect rows in that exact order |
| `${TRUE}` | Order doesn't matter — DB query has no ORDER BY, or you're comparing unsorted data |

#### `show_details`

Same comparison, two different log outputs:

**`show_details=${FALSE}`**
```
CSV comparison completed - Status: DIFFERENT
Total differences found: 3
```

**`show_details=${TRUE}`**
```
CSV comparison completed - Status: DIFFERENT
Total differences found: 3
  Row 1, column 'ts': '2026-05-08' vs '2026-05-07'
  Row 2, column 'ts': '2026-05-08' vs '2026-05-07'
  Row 3, column 'ts': '2026-05-08' vs '2026-05-07'
```

| show_details | When to use |
|---|---|
| `${TRUE}` | Debugging — see which cells actually differ |
| `${FALSE}` | Stable green builds — keep logs short |

#### `expected_status`

This is your **assertion**. Three valid values:

| Value | Means |
|---|---|
| `IDENTICAL` | "The files SHOULD match" — fails the test if they don't |
| `DIFFERENT` | "The files SHOULD NOT match" — proves your test detects divergence |
| `SUBSET` | "file1's rows are all present in file2 (file2 may have extras)" |

```
Use IDENTICAL  →  positive test ("did the pipeline produce the expected output?")
Use DIFFERENT  →  negative test ("does the comparator catch a known bad file?")
Use SUBSET     →  partial-match test ("are all my expected rows present, even if extras exist?")
```

### Tiny working example

```robot
*** Test Cases ***
My output matches the baseline
    Compare CSV Files Template
    ...    ${CURDIR}/data/actual.csv          # file 1
    ...    ${CURDIR}/data/expected.csv        # file 2
    ...    ${FALSE}                           # ignore_order — strict
    ...    ${TRUE}                            # show_details — yes
    ...    IDENTICAL                          # expected_status — must match
```

---

## Keyword 2: `Compare CSV Files With Exclusions Template`

### Signature

```robot
Compare CSV Files With Exclusions Template
...    ${file1_path}                  ← positional 1     ┐
...    ${file2_path}                  ← positional 2     │  Same first 5 args
...    ${ignore_order}                ← positional 3     │  as the plain keyword
...    ${show_details}                ← positional 4     │
...    ${expected_status}             ← positional 5     ┘
...    @{exclude_keys}                ← varargs   (NEW)
...    &{options}                     ← kwargs    (NEW)
```

### Argument reference

| # | Argument | Type | Example | What it does |
|---|---|---|---|---|
| 1 | `file1_path` | path | `${CURDIR}/data/actual.csv` | The "actual" CSV |
| 2 | `file2_path` | path | `${CURDIR}/data/expected.csv` | The "expected" CSV |
| 3 | `ignore_order` | bool | `${TRUE}` | Same as plain keyword |
| 4 | `show_details` | bool | `${TRUE}` | Same as plain keyword |
| 5 | `expected_status` | string | `IDENTICAL` | Same as plain keyword |
| 6+ | `@{exclude_keys}` | varargs (list) | `load_timestamp    run_id` | Column names to skip during comparison |
| kw | `match_key=<col>` | named | `match_key=employee_id` | Match rows by an ID column instead of position |

### Visual: how `@{exclude_keys}` reshapes the comparison

```
ORIGINAL FILES                       AFTER EXCLUSION (load_timestamp removed)
──────────────                       ────────────────────────────────────────

file1.csv                            file1.csv (in-memory view)
id, name, salary, load_timestamp     id, name, salary
 1, Alice, 80000, 2026-05-08          1, Alice, 80000
 2, Bob,   65000, 2026-05-08          2, Bob,   65000

file2.csv                            file2.csv (in-memory view)
id, name, salary, load_timestamp     id, name, salary
 1, Alice, 80000, 2026-05-07          1, Alice, 80000
 2, Bob,   65000, 2026-05-07          2, Bob,   65000

→ With plain keyword:                → With exclusion of load_timestamp:
   DIFFERENT (timestamps differ)        IDENTICAL (everything else matches)
```

The exclusion is applied **before** the comparison runs. The original files on disk are untouched — only the in-memory view is filtered.

### Visual: `match_key` for ID-based row matching

Without `match_key`, rows are compared **by position** (row 1 of file1 with row 1 of file2, row 2 with row 2, etc.):

```
position-based matching:
file1                file2
─────                ─────
row 1: A, x          row 1: B, x         ← compared together
row 2: B, y          row 2: A, y         ← compared together

Result: DIFFERENT (A vs B in row 1, B vs A in row 2)
```

With `match_key=id`, rows are compared **by ID** regardless of position:

```
key-based matching (match_key=id):
file1                file2
─────                ─────
id=1, A, x           id=2, B, x          ← match by id
id=2, B, y           id=1, A, y          ← match by id

→ Comparator pairs id=1 with id=1, id=2 with id=2, regardless of position.
Result: IDENTICAL (each ID's data matches)
```

| When | Use match_key? |
|---|---|
| Files always have the same row order | No — position is fine |
| Files come from unordered DB queries | Yes — match by primary key |
| Rows are pulled from different sources | Yes — match by a stable ID |

### Tiny working example

```robot
*** Test Cases ***
Output matches except timestamps
    Compare CSV Files With Exclusions Template
    ...    ${CURDIR}/data/actual.csv          # file 1
    ...    ${CURDIR}/data/expected.csv        # file 2
    ...    ${FALSE}                           # ignore_order
    ...    ${TRUE}                            # show_details
    ...    IDENTICAL                          # expected_status
    ...    load_timestamp                     # exclude this column
    ...    pipeline_run_id                    # exclude this one too
```

---

## Side-by-side: same files, four different calls

Using the tutorial's [`employees_with_ts_actual.csv`](./data/employees_with_ts_actual.csv) and [`employees_with_ts_expected.csv`](./data/employees_with_ts_expected.csv) — identical data except `load_timestamp`.

```
┌───────────────────────────────────────────────────────────────────────────────┐
│                                                                               │
│  Call A — plain, expecting IDENTICAL                                          │
│  ────────────────────────────────────                                         │
│  Compare CSV Files Template                                                   │
│  ...    actual.csv    expected.csv    ${FALSE}    ${TRUE}    IDENTICAL        │
│                                                                               │
│  → FAILS the test (status=DIFFERENT, but you said IDENTICAL)                  │
│                                                                               │
└───────────────────────────────────────────────────────────────────────────────┘

┌───────────────────────────────────────────────────────────────────────────────┐
│                                                                               │
│  Call B — plain, expecting DIFFERENT                                          │
│  ────────────────────────────────────                                         │
│  Compare CSV Files Template                                                   │
│  ...    actual.csv    expected.csv    ${FALSE}    ${TRUE}    DIFFERENT        │
│                                                                               │
│  → PASSES the test (status=DIFFERENT, matching your assertion)                │
│  Used as a sanity check that the comparator can detect timestamp drift.       │
│                                                                               │
└───────────────────────────────────────────────────────────────────────────────┘

┌───────────────────────────────────────────────────────────────────────────────┐
│                                                                               │
│  Call C — with exclusion, expecting IDENTICAL                                 │
│  ────────────────────────────────────────────                                 │
│  Compare CSV Files With Exclusions Template                                   │
│  ...    actual.csv    expected.csv    ${FALSE}    ${TRUE}    IDENTICAL        │
│  ...    load_timestamp                                                        │
│                                                                               │
│  → PASSES (timestamps excluded, everything else matches)                      │
│  Most realistic real-world usage — pipelines write timestamps that            │
│  customers don't want to assert on.                                           │
│                                                                               │
└───────────────────────────────────────────────────────────────────────────────┘

┌───────────────────────────────────────────────────────────────────────────────┐
│                                                                               │
│  Call D — with exclusion, expecting DIFFERENT                                 │
│  ────────────────────────────────────────────                                 │
│  Compare CSV Files With Exclusions Template                                   │
│  ...    actual.csv    expected.csv    ${FALSE}    ${TRUE}    DIFFERENT        │
│  ...    load_timestamp                                                        │
│                                                                               │
│  → FAILS (with timestamps excluded, files are IDENTICAL — but you said        │
│  DIFFERENT). This call doesn't make sense for these particular files.         │
│                                                                               │
└───────────────────────────────────────────────────────────────────────────────┘
```

---

## Decision tree

```
START — I want to compare two CSVs

│
├─→ Do my files contain ANY non-deterministic columns
│   (timestamps, run IDs, generated UUIDs)?
│
│   ├── No  ──→ Use:  Compare CSV Files Template
│   │
│   └── Yes ──→ Continue ↓
│
├─→ Do I need to match rows by an ID column
│   (instead of by row position)?
│
│   ├── No  ──→ Use:  Compare CSV Files With Exclusions Template
│   │                  + @{exclude_keys}
│   │
│   └── Yes ──→ Use:  Compare CSV Files With Exclusions Template
│                      + @{exclude_keys}
│                      + match_key=<id_column>
│
END
```

---

## Common gotchas

### `expected_status` is an ASSERTION, not a hint

```robot
Compare CSV Files Template    a.csv    b.csv    ${FALSE}    ${TRUE}    IDENTICAL
```

This says: *"I assert these files ARE IDENTICAL."* If they're actually DIFFERENT, the test **FAILS** — even though the comparison itself worked correctly. The keyword's job is to validate your assertion.

If you genuinely want to detect divergence (negative test), pass `DIFFERENT` instead.

### Forgetting `ignore_order` when needed

```sql
SELECT * FROM employees;       -- no ORDER BY
```

This SQL has **undefined row order**. If you compare against a fixed-order baseline CSV without `ignore_order=${TRUE}`, your test will be flaky — failing some runs even when the data is correct.

**Fix:** either add `ORDER BY id` to the query, or pass `${TRUE}` for `ignore_order`.

### Excluding too many columns

```robot
# Suspicious — excludes EVERYTHING except id
Compare CSV Files With Exclusions Template
...    a.csv    b.csv    ${FALSE}    ${TRUE}    IDENTICAL
...    name    role    salary    load_timestamp    run_id
```

Now the comparator only sees `id`. Two files with completely different employee data would still be IDENTICAL because their IDs match. **Audit your exclusion list periodically** — exclude only what's truly volatile.

### `@{exclude_keys}` order doesn't matter, but spelling does

```robot
# Both fine — same effect
...    load_timestamp    run_id
...    run_id    load_timestamp

# Wrong — typo. Column won't be excluded; comparison will detect it as a difference.
...    Load_TimeStamp                      ← case-sensitive!
```

CSV header column names must match **exactly** (case-sensitive). If your header is `load_timestamp`, you must pass `load_timestamp` — not `Load_Timestamp` or `LOAD_TIMESTAMP`.

---

## Quick reference card

```
┌──────────────────────────────────────────────────────────────────┐
│  PLAIN                                                           │
│  Compare CSV Files Template                                      │
│  ...    file1    file2    ignore_order    show_details    status │
│                                                                  │
│  WITH EXCLUSIONS                                                 │
│  Compare CSV Files With Exclusions Template                      │
│  ...    file1    file2    ignore_order    show_details    status │
│  ...    col_to_skip_1    col_to_skip_2                           │
│  ...    match_key=id_column            (optional)                │
│                                                                  │
│  STATUSES:  IDENTICAL  /  DIFFERENT  /  SUBSET                   │
│  BOOLS:     ${TRUE}    /  ${FALSE}                               │
└──────────────────────────────────────────────────────────────────┘
```

---

## Related docs

- [`compare_csv_files.md`](./compare_csv_files.md) — the full tutorial walk-through with all 10 test cases
- [`compare_csv_files.robot`](./compare_csv_files.robot) — runnable suite demonstrating both keywords
- [`csv_validations.resource`](../../../../resources/common/csv_validations.resource) — keyword definitions
