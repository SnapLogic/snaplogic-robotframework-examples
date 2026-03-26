# Validate Account References Are Not Hardcoded — Complete Reference

## Purpose

Ensures that account references in pipeline snaps use **expressions** (pipeline parameters) rather than **hardcoded paths**. Hardcoded accounts create tight coupling between the pipeline and a specific environment, making pipelines non-portable and fragile.

---

## The Problem

When an account reference is hardcoded, the pipeline only works in one environment:

```
❌ HARDCODED — pipeline is locked to one environment

Oracle - Insert snap:
    Account: "../shared/prod_oracle_acct"     ← hardcoded string
    expression: false

Problems:
- Moving this pipeline to DEV? It still points to PROD.
- Different org? Account path doesn't exist.
- Renaming the account? Must edit every snap that references it.
- Multiple developers? Each has different account names.
```

```
✅ EXPRESSION-BASED — pipeline works in any environment

Oracle - Insert snap:
    Account: "_oracle_acct"                   ← expression (pipeline parameter)
    expression: true

Benefits:
- DEV, QA, PROD — same pipeline, different parameter values.
- Account name comes from the calling context.
- One place to change (the parameter), not every snap.
```

---

## Peer Review Requirements

From the peer review form:

> *"Accounts should never be hard coded."*
>
> *"Account should have the '=' sign turned on."*
>
> *"Account reference (whether in metadata or not) should be in format of ../shared/<account>"*

The "=" sign being turned on corresponds to `expression: true` in the `.slp` JSON.

---

## Where Account References Live in the .slp File

Each snap that uses an account has an `account_ref` field inside `property_map.account`:

### Expression-Based Reference (GOOD)

```json
{
    "property_map": {
        "account": {
            "account_ref": {
                "value": "_oracle_acct",
                "expression": true            ← expression mode ON ("=" sign)
            }
        }
    }
}
```

The `value` `"_oracle_acct"` is a **SnapLogic expression** that resolves to a pipeline parameter. At runtime, it evaluates to the parameter's value (e.g., `../shared/oracle_acct`).

### Hardcoded Reference (BAD)

```json
{
    "property_map": {
        "account": {
            "account_ref": {
                "value": "../shared/oracle_acct",
                "expression": false           ← expression mode OFF (hardcoded)
            }
        }
    }
}
```

The `value` is a literal path string — not an expression. This is a violation.

---

## The Check — Single Rule

For each snap that has an account reference, check: **is `expression` set to `true`?**

```python
for acct in accounts:
    ref = acct['account_ref']
    is_expr = acct['is_expression']

    # If it's a string value and NOT an expression → hardcoded
    if isinstance(ref, str) and ref and not is_expr:
        violations.append(...)
```

| Snap | account_ref value | expression | Result |
|---|---|:---:|---|
| Oracle - Insert | `_oracle_acct` | `true` | ✅ PASS — expression-based |
| Snowflake - Insert | `_snowflake_acct` | `true` | ✅ PASS — expression-based |
| Oracle - Select | `../shared/oracle_acct` | `false` | ❌ FAIL — hardcoded |
| MySQL - Select | `/org/proj/mysql_acct` | `false` | ❌ FAIL — hardcoded |

---

## Complete Validation Flow

```
                Load Pipeline (.slp file)
                          │
                          ▼
            ┌──────────────────────────┐
            │  Get Account References   │
            │                          │
            │  For each snap:          │
            │    Read property_map →   │
            │    account →             │
            │    account_ref           │
            │                          │
            │  Skip snaps with:        │
            │    - No account section  │
            │    - Empty account_ref   │
            │    - account_ref = {}    │
            └────────────┬─────────────┘
                         │
                         ▼
              ┌────────────────────┐
              │  For each account   │
              │  reference found    │
              └─────────┬──────────┘
                        │
                ┌───────┴───────┐
                ▼               ▼
         expression=true  expression=false
               │               │
               ▼               ▼
         ✅ PASS          Is it a non-empty
         (skip)           string?
                            │
                      ┌─────┴─────┐
                      ▼           ▼
                    Yes          No
                     │           │
                     ▼           ▼
               ❌ FAIL        (skip)
               Add violation:
               "Account ref 'X'
                in snap 'Y' is
                hardcoded"
                               │
                    ┌──────────┘
                    ▼
          ┌──────────────────────┐
          │  All accounts checked │
          │                      │
          │  violations empty?   │
          │  YES → PASS          │
          │  NO  → FAIL          │
          └──────────────────────┘
```

---

## How Account References Are Extracted

The `Get Account References` method scans **every snap** in the `snap_map`:

```python
for snap_id, snap_data in snap_map.items():
    prop_map = snap_data.get('property_map', {})
    account = prop_map.get('account', {})
    account_ref = account.get('account_ref', {})

    ref_value = account_ref.get('value', None)
    is_expression = account_ref.get('expression', False)

    # Skip snaps with no account
    if ref_value is None or ref_value == {} or ref_value == '':
        continue
```

Not all snaps have accounts. Only snaps that connect to external systems (databases, SaaS, cloud storage) have account references:

| Snap Type | Has Account? |
|---|:---:|
| Oracle - Select/Insert/Execute | Yes |
| Snowflake - Insert | Yes |
| Salesforce Read/Create/Update | Yes |
| S3 Upload/Download | Yes |
| Kafka Producer/Consumer | Yes |
| Mapper, Filter, Router | No |
| JSON Parser, CSV Formatter | No |
| File Reader/Writer (local) | No |

### What Gets Extracted Per Account

| Field | Source | Example |
|---|---|---|
| `snap_id` | Key in snap_map | `"a1b2c3d4-..."` |
| `snap_name` | property_map.info.label.value | `"Oracle - Insert"` |
| `account_ref` | property_map.account.account_ref.value | `"_oracle_acct"` |
| `is_expression` | property_map.account.account_ref.expression | `true` or `false` |

---

## Return Value Structure

```python
{
    "status": "FAIL",
    "violations": [
        {
            "snap_name": "Oracle - Select",
            "snap_id": "a1b2c3d4-...",
            "account_ref": "../shared/oracle_acct",
            "is_expression": False,
            "reason": "Account ref '../shared/oracle_acct' in snap 'Oracle - Select' is hardcoded (not an expression)"
        }
    ],
    "total_accounts": 3,
    "total_violations": 1
}
```

| Field | Description |
|---|---|
| `status` | `"PASS"` if all accounts use expressions, `"FAIL"` otherwise |
| `violations` | List of snaps with hardcoded account references |
| `total_accounts` | Total number of snaps that have account references |
| `total_violations` | Number of snaps with hardcoded accounts |

---

## Code Architecture — 3 Layers

### Layer 1: Test Case (peer_review_tests.robot)

```robot
Verify Account References Are Not Hardcoded
    [Documentation]    Validates that account references in snaps use expressions
    ...    (pipeline parameters) rather than hardcoded account paths.
    ...    Accounts should never be hard coded per peer review standards.
    [Tags]    peer_review    accounts    static_analysis
    Pipeline Accounts Should Not Be Hardcoded    ${pipeline}
```

**What it does:** Calls the resource keyword. One line.

### Layer 2: Resource Keyword (pipeline_inspector.resource)

```robot
Pipeline Accounts Should Not Be Hardcoded
    [Arguments]    ${pipeline}
    ${result}=    Validate Accounts Not Hardcoded    ${pipeline}
    Should Be Equal    ${result}[status]    PASS
    ...    msg=Hardcoded account references found: ${result}[violations]
```

**What it does:** Calls the Python library, asserts PASS. If FAIL, the violation details are in the error message.

### Layer 3: Python Library (PipelineInspectorLibrary.py)

Two methods work together:

**`get_account_references()`** — Scans all snaps for account_ref:
```python
def get_account_references(self, pipeline):
    # For each snap in snap_map:
    #   Read property_map.account.account_ref
    #   Skip snaps with no account
    #   Return list of {snap_id, snap_name, account_ref, is_expression}
```

**`validate_accounts_not_hardcoded()`** — Checks each reference:
```python
def validate_accounts_not_hardcoded(self, pipeline):
    accounts = self.get_account_references(pipeline)
    violations = []
    for acct in accounts:
        if isinstance(ref, str) and ref and not is_expr:
            violations.append(...)  # hardcoded!
    return {status, violations, total_accounts, total_violations}
```

---

## Real Examples From Your Pipelines

### oracle2.slp — PASS ✅

```
Snap: Oracle - Insert
  account_ref: "_oracle_acct"
  expression: true → ✅ Expression-based

Total: 1 account | 0 violations | Status: PASS
```

### snowflake.slp — PASS ✅

```
Snap: Snowflake - Insert
  account_ref: "_snowflake_acct"
  expression: true → ✅ Expression-based

Total: 1 account | 0 violations | Status: PASS
```

### sit_sqlserver.slp — PASS ✅ (advanced expression)

```
Snap: tlrequest source
  account_ref: "lib.EBAS_to_CBS.Accounts.get(lib.EBAS_to_CBS.getEnv())"
  expression: true → ✅ Expression-based (using expression library)

Snap: tblHeader_select
  account_ref: "lib.EBAS_to_CBS.Accounts.get(lib.EBAS_to_CBS.getEnv())"
  expression: true → ✅ Expression-based

Total: 4 accounts | 0 violations | Status: PASS
```

### salesforce.slp — PASS ✅

```
Snap: Salesforce Read
  account_ref: "_sfdc_acct"
  expression: true → ✅ Expression-based

Snap: Salesforce Create
  account_ref: "_sfdc_acct"
  expression: true → ✅ Expression-based

Total: 2 accounts | 0 violations | Status: PASS
```

### Hypothetical Hardcoded Pipeline — FAIL ❌

```
Snap: Oracle - Select
  account_ref: "../shared/prod_oracle_acct"
  expression: false → ❌ Hardcoded!

Snap: Oracle - Insert
  account_ref: "_oracle_acct"
  expression: true → ✅ Expression-based

Total: 2 accounts | 1 violation | Status: FAIL
Violation: "Account ref '../shared/prod_oracle_acct' in snap 'Oracle - Select' is hardcoded (not an expression)"
```

---

## Three Types of Account References

| Type | expression | value | Example | Valid? |
|---|:---:|---|---|:---:|
| **Simple expression** | `true` | `_oracle_acct` | References a pipeline parameter | ✅ |
| **Library expression** | `true` | `lib.EBAS_to_CBS.Accounts.get(...)` | Uses expression library | ✅ |
| **Hardcoded path** | `false` | `../shared/oracle_acct` | Literal path string | ❌ |

---

## Edge Cases

### Snap With No Account Section

Many snaps (Mapper, Filter, Router, etc.) don't have accounts. These are silently skipped — no violation, no log.

### Pipeline With No Account References

If no snap in the pipeline has an account reference, the check **passes** — there's nothing to validate.

```python
accounts = []         # empty list
violations = []       # no violations
status = 'PASS'
total_accounts = 0
```

### Account ref Is an Empty Object

Some snaps have an `account_ref` key but with an empty value (`{}` or `""`). These are skipped:

```python
if ref_value is None or ref_value == {} or ref_value == '':
    continue
```

### Expression Defaults to False

If the `.slp` JSON has no `expression` field in `account_ref`, it defaults to `false`:

```python
is_expression = account_ref.get('expression', False)
```

This means missing `expression` fields are treated as hardcoded — the safe default.

---

## How to Fix Violations

In SnapLogic Designer:

1. Open the pipeline
2. Click on the snap with the hardcoded account (e.g., Oracle - Select)
3. Go to the **Account** tab
4. Click the **"="** button next to the account reference field (this enables expression mode)
5. Replace the hardcoded path with a parameter reference:
   - Before: `../shared/oracle_acct` (expression off)
   - After: `_oracle_acct` (expression on)
6. Add a corresponding pipeline parameter named `oracle_acct` with default value `../shared/oracle_acct`
7. Save the pipeline

### What Changes in the .slp JSON

```json
// Before (hardcoded — violation)
"account_ref": {
    "value": "../shared/oracle_acct",
    "expression": false
}

// After (expression — fixed)
"account_ref": {
    "value": "_oracle_acct",
    "expression": true
}
```

---

## Relationship to Account Reference Format Check

This test case checks **how** the account is referenced (expression vs hardcoded). There is a separate test case that checks **where** the account points to:

| Test Case | What It Checks |
|---|---|
| **Verify Account References Are Not Hardcoded** (this doc) | Is `expression` set to `true`? |
| **Verify Account References Use Shared Folder Format** | Does the resolved value match `../shared/<account>`? |

Both must pass for full account compliance. A pipeline could:
- Use expressions (pass this check) but point to the wrong folder (fail format check)
- Be hardcoded (fail this check) but point to the shared folder (pass format check)

---

## Related Documentation

| Document | Description |
|---|---|
| [Validate Account References Format](validate_account_references_format.md) | Account path format check (../shared/) |
| [Validate Parameters Have Capture Enabled](validate_parameters_have_capture_enabled.md) | Parameter capture checkbox |
| [Validate Parameters Have Prefix](validate_parameters_have_prefix.md) | Parameter xx prefix convention |
| [Peer Review Automation](peer_review_automation.md) | Full peer review automation overview |
