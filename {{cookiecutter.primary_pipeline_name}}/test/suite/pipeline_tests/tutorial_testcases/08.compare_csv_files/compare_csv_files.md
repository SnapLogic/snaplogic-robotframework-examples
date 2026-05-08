# CSV File Comparison — Tutorial

A walk-through of every commonly-used CSV-comparison and validation keyword in [`test/resources/common/csv_validations.resource`](../../../../resources/common/csv_validations.resource), demonstrated by the companion file [`compare_csv_files.robot`](./compare_csv_files.robot).

---

## TL;DR

- **10 test cases**, each demonstrates **one keyword or one edge case**.
- 12 sample CSV files in **6 paired scenarios** under `data/actual_data/` and `data/expected_data/`.
  Each test compares `actual_data/X.csv` against `expected_data/X.csv` (same filename in both folders).
- No external dependencies — pure file comparison, no DB, no S3, no SnapLogic account needed.
- Run with: `make robot-run-tests-no-gp TAGS="compare_csv_sample"`

---

## Why CSV comparison matters

Pipeline tests usually follow this shape:

```
1. Run pipeline
2. Pipeline writes output (DB row → CSV, S3 download → local CSV, etc.)
3. Test compares actual output CSV  ↔  expected baseline CSV
4. PASS if they match, FAIL if they don't
```

Step 3 is what these keywords do. The hard part is **deciding when "match" means match** — exact bytes? same data, any order? same data minus volatile columns like timestamps? These keywords give you the knobs to express each case.

---

## Available keywords

The 4 keywords from `csv_validations.resource`:

| Keyword | Purpose |
|---|---|
| `Count Data Rows In CSV` | Returns the number of data rows (header excluded) |
| `Validate CSV File Template` | Asserts row count + optional column count |
| `Compare CSV Files Template` | Compares two files end-to-end |
| `Compare CSV Files With Exclusions Template` | Same, but ignores specific columns |

Plus one related keyword in [`sql_table_operations.resource`](../../../../resources/common/sql_table_operations.resource):

| Keyword | Purpose |
|---|---|
| `Compare Table With CSV File` | Compares a database table against a CSV (not demonstrated here — needs a DB) |

---

## Keyword reference

### `Count Data Rows In CSV    ${csv_file}    ${header_rows}=1`

Counts data rows, returning an integer. Header rows excluded by default (override with `header_rows=0` if your CSV has no header).

```robot
${count}=    Count Data Rows In CSV    employees.csv
Should Be Equal As Integers    ${count}    5
```

---

### `Validate CSV File Template    ${file_path}    ${expected_rows}    ${has_headers}=${TRUE}    ${expected_columns}=${None}`

Asserts row count and (optionally) column count in one call. Convenient when you want a single sanity-check before doing anything else with the file.

```robot
Validate CSV File Template
...    employees.csv
...    expected_rows=5
...    has_headers=${TRUE}
...    expected_columns=4
```

Returns a dict: `{valid, actual_rows, actual_columns}`.

---

### `Compare CSV Files Template    ${file1}    ${file2}    ${ignore_order}    ${show_details}    ${expected_status}`

The workhorse. Compares two files and asserts the result matches `${expected_status}`.

| Argument | Type | What it means |
|---|---|---|
| `file1_path` | path | Actual output |
| `file2_path` | path | Expected baseline |
| `ignore_order` | `${TRUE}`/`${FALSE}` | If TRUE, row order doesn't matter |
| `show_details` | `${TRUE}`/`${FALSE}` | If TRUE, prints which cells differ |
| `expected_status` | `IDENTICAL` / `DIFFERENT` / `SUBSET` | What the test expects the result to be |

Returns a dict: `{status, total_differences}`.

#### About `expected_status`

This is the **assertion**. The keyword fails the test if the actual comparison result doesn't match what you said to expect.

- `IDENTICAL` — files match (per `ignore_order` rules) → status will be IDENTICAL
- `DIFFERENT` — files don't match → status will be DIFFERENT (use this for **negative tests**)
- `SUBSET` — file1's rows are a subset of file2's

#### Common patterns

```robot
# Positive test — files SHOULD match
Compare CSV Files Template    actual.csv    expected.csv    ${FALSE}    ${TRUE}    IDENTICAL

# Negative test — files SHOULD NOT match (proves you can detect divergence)
Compare CSV Files Template    actual.csv    expected.csv    ${FALSE}    ${TRUE}    DIFFERENT

# Order doesn't matter — same data shuffled is OK
Compare CSV Files Template    actual.csv    expected.csv    ${TRUE}     ${TRUE}    IDENTICAL
```

---

### `Compare CSV Files With Exclusions Template    ${file1}    ${file2}    ${ignore_order}    ${show_details}    ${expected_status}    @{exclude_keys}    &{options}`

Same as `Compare CSV Files Template`, but **ignores one or more columns** during comparison. Use this when your CSVs differ only in non-deterministic columns (timestamps, run IDs, generated UUIDs, etc.).

```robot
# Exclude one column
Compare CSV Files With Exclusions Template
...    actual.csv    expected.csv    ${FALSE}    ${TRUE}    IDENTICAL
...    load_timestamp

# Exclude multiple columns
Compare CSV Files With Exclusions Template
...    actual.csv    expected.csv    ${FALSE}    ${TRUE}    IDENTICAL
...    load_timestamp    run_id    last_modified
```

The `@{exclude_keys}` are passed as varargs after `expected_status`. Each is a column name in the CSV header.

#### Optional `match_key`

For complex scenarios where rows can be matched by an ID column even if other columns differ:

```robot
Compare CSV Files With Exclusions Template
...    actual.csv    expected.csv    ${TRUE}    ${TRUE}    IDENTICAL
...    timestamp    match_key=employee_id
```

`match_key=employee_id` tells the comparator: *"Match each actual row to an expected row by employee_id, then compare the rest."*

---

## Test inventory

All 10 tests in execution order:

| # | Test name | What it demonstrates | Files used |
|---|---|---|---|
| 1 | VALIDATE — Count Data Rows In CSV | `Count Data Rows In CSV` returns 5 | `actual_data/basic.csv` |
| 2 | VALIDATE — Validate CSV File Template | Row + column count in one call | `actual_data/basic.csv` |
| 3 | COMPARE — Identical files | Two byte-identical files → IDENTICAL | `actual_data/basic.csv` ↔ `expected_data/basic.csv` |
| 4 | COMPARE — Different files | Bob's role/salary differs → DIFFERENT | `actual_data/modified.csv` ↔ `expected_data/modified.csv` |
| 5 | COMPARE — Shuffled rows with ignore_order=TRUE | Same data, different order → IDENTICAL | `actual_data/shuffled.csv` ↔ `expected_data/shuffled.csv` |
| 6 | COMPARE — Shuffled rows with ignore_order=FALSE | Same data, different order → DIFFERENT | `actual_data/shuffled.csv` ↔ `expected_data/shuffled.csv` |
| 7 | COMPARE — Differ only in timestamp (EXCLUDED) | Different timestamps but excluded → IDENTICAL | `actual_data/with_timestamp.csv` ↔ `expected_data/with_timestamp.csv` |
| 8 | COMPARE — Differ only in timestamp (NOT EXCLUDED) | Same files, no exclusion → DIFFERENT | `actual_data/with_timestamp.csv` ↔ `expected_data/with_timestamp.csv` |
| 9 | COMPARE — Different row counts | actual has 6 rows, expected has 5 → DIFFERENT | `actual_data/extra_row.csv` ↔ `expected_data/extra_row.csv` |
| 10 | COMPARE — Different column counts | actual missing salary column → DIFFERENT | `actual_data/missing_column.csv` ↔ `expected_data/missing_column.csv` |

---

## Edge cases covered

| Edge case | Test | Resolution |
|---|---|---|
| Files truly identical | #3 | IDENTICAL |
| Files genuinely different | #4 | DIFFERENT |
| Same data but reordered rows (e.g. unsorted DB query) | #5 / #6 | Use `ignore_order=TRUE` |
| Volatile columns (timestamps, run IDs) | #7 / #8 | Use `Compare CSV Files With Exclusions Template` |
| Off-by-one row counts | #9 | DIFFERENT — total_differences shows extras |
| Schema mismatch (missing column) | #10 | DIFFERENT — comparison reports the column delta |

Other edge cases not covered here that you'll hit in real pipelines:
- **Whitespace differences** — leading/trailing spaces in cells. Treated as different by default. Pre-trim with a Python step if needed.
- **Case differences** — `Engineer` vs `engineer`. Treated as different. Normalize first.
- **Numeric precision** — `1.0` vs `1.00`. Treated as different by string comparison. Round before writing.
- **Empty files** — both empty CSVs are IDENTICAL. One empty + one populated is DIFFERENT.

---

## Sample file inventory

12 CSV files organised as 6 paired scenarios. Each scenario has the **same filename** in both folders, so tests read like:

```robot
Compare CSV Files Template    ${ACTUAL_DIR}/basic.csv    ${EXPECTED_DIR}/basic.csv    ...
```

```
data/
├── actual_data/                       expected_data/
│   ├── basic.csv             ←→       ├── basic.csv             (identical content)
│   ├── modified.csv          ←→       ├── modified.csv          (Bob differs)
│   ├── shuffled.csv          ←→       ├── shuffled.csv          (rows reordered)
│   ├── with_timestamp.csv    ←→       ├── with_timestamp.csv    (timestamp differs)
│   ├── extra_row.csv         ←→       ├── extra_row.csv         (actual has 6, expected has 5)
│   └── missing_column.csv    ←→       └── missing_column.csv    (actual missing salary col)
```

| Pair | actual_data side | expected_data side | Used by tests |
|---|---|---|---|
| `basic.csv` | 5 rows, 4 cols | byte-identical | 1, 2, 3 |
| `modified.csv` | Bob = "Senior Analyst, 75000" | Bob = "Analyst, 65000" (original) | 4 |
| `shuffled.csv` | rows in [3,1,5,2,4] order | rows in [1,2,3,4,5] order | 5, 6 |
| `with_timestamp.csv` | load_timestamp = 2026-05-08 | load_timestamp = 2026-05-07 | 7, 8 |
| `extra_row.csv` | 6 rows (adds Frank) | 5 rows | 9 |
| `missing_column.csv` | 3 cols (no salary) | 4 cols (with salary) | 10 |

---

## Patterns worth copying

### 1. Always pair positive + negative tests

For any comparison rule you rely on, write **both** an IDENTICAL and a DIFFERENT test. Test 5 + 6 do this for `ignore_order`. Test 7 + 8 do it for `exclude_keys`. This proves the keyword is detecting differences correctly — not just always returning IDENTICAL.

### 2. Exclude every column that varies between runs

If your pipeline writes `load_timestamp`, `pipeline_run_id`, or any UUID-like column, **exclude it**. Otherwise every comparison is a false negative.

```robot
Compare CSV Files With Exclusions Template
...    ${actual}    ${expected}    ${FALSE}    ${TRUE}    IDENTICAL
...    load_timestamp    pipeline_run_id    record_uuid
```

### 3. Use `ignore_order=TRUE` when DB queries don't guarantee row order

`SELECT * FROM employees` with no `ORDER BY` returns rows in undefined order. Either:
- Add `ORDER BY id` to your export, OR
- Pass `ignore_order=${TRUE}` to the compare keyword

### 4. Show details on first failure, hide on stable runs

`show_details=${TRUE}` prints every differing cell to the log. Useful while debugging, noisy on green builds. Set to `${TRUE}` initially; flip to `${FALSE}` once tests are stable.

---

## Running the suite

```bash
make robot-run-tests-no-gp TAGS="compare_csv_sample"
```

Expected: **10 tests, 10 passed, 0 failed**.

No services to start — these are pure file operations.

---

## Where to look when something fails

| Symptom | Likely cause | Where to check |
|---|---|---|
| `File 'X' does not exist` | Path typo or `${CURDIR}` resolved unexpectedly | Check the file is in `./data/` next to the `.robot` file |
| `Expected status 'IDENTICAL' but got 'DIFFERENT'` | The two files actually differ — your fixtures or pipeline output is wrong | Open both CSVs and diff them by eye |
| `Expected status 'DIFFERENT' but got 'IDENTICAL'` | Negative test failing — files unexpectedly match. Check fixture wasn't overwritten |  |
| Rows compared but values look right | Whitespace, case, or numeric formatting | Check raw bytes — `cat -A actual.csv` reveals invisibles |
| Comparison ignores too many differences | Excluded list is too broad | Audit your `@{exclude_keys}` list |

---

## Related keywords (not demonstrated here)

| Keyword | Where it lives | Why skipped |
|---|---|---|
| `Compare Table With CSV File` | `sql_table_operations.resource` | Compares a DB table to a CSV — needs a database connection. Used in real pipeline tests, not in this pure-file tutorial. |
| `Load CSV Data Template` | `csv_validations.resource` | Loads CSV rows into a DB table — needs a database. |

When you're ready to test pipeline output end-to-end (DB → CSV → compare), see the snowflake/oracle baseline tests for examples that combine these keywords.
