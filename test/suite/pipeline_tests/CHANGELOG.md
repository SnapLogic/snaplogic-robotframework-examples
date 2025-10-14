# Test Framework Updates - Changelog

## Summary of Recent Changes

This document outlines the standardization and improvements made to the Robot Framework test suite for SnapLogic automation testing.

---

## ✅ Test Case Argument Updates

### 1. Create Account Test Case

**Purpose:** Standardize account creation across all database and service types

**Changes Made:**
- **Updated to 3-parameter format:**
  - **Parameter 1:** `${ACCOUNT_LOCATION_PATH}` - Common account location for all tests
  - **Parameter 2:** `${<DATABASE>_ACCOUNT_PAYLOAD_FILE_NAME}` - Payload file name from respective `.env` file
  - **Parameter 3:** `${<DATABASE>_ACCOUNT_NAME}` - Account name from respective `.env` file

**Files Updated:**
- `/test/suite/pipeline_tests/db2/db2.robot`
- `/test/suite/pipeline_tests/mysql/mysql.robot`
- `/test/suite/pipeline_tests/oracle/oracle.robot`
- `/test/suite/pipeline_tests/postgres_s3/postgres_to_s3.robot`
- `/test/suite/pipeline_tests/sqlserver/sqlserver.robot`
- `/test/suite/pipeline_tests/teradata/teradata.robot`
- `/test/suite/pipeline_tests/snowflake/snowflake_demo.robot`

**Example Usage:**
```robotframework
Create Account
    [Template]    Create Account From Template
    ${ACCOUNT_LOCATION_PATH}    ${MYSQL_ACCOUNT_PAYLOAD_FILE_NAME}    ${MYSQL_ACCOUNT_NAME}
```

**Benefits:**
- ✅ Consistent pattern across all test files
- ✅ Environment-driven configuration
- ✅ Easy to identify which account is being created
- ✅ Self-documenting code

---

### 2. Create Triggered Task Test Case

**Purpose:** Improve flexibility in passing optional parameters

**Keyword Updated:** `Create Triggered Task From Template`

**Argument Order Changed:**
- **New Order:**
  ```robotframework
  [Arguments]
  ...    ${unique_id}              # Position 1
  ...    ${project_path}           # Position 2
  ...    ${pipeline_name}          # Position 3
  ...    ${task_name}              # Position 4
  ...    ${plex_name}=${groundplex_name}     # Position 5 (moved up)
  ...    ${pipeline_params}=None             # Position 6
  ...    ${notification}=None                # Position 7
  ```

- **Previous Order:**
  ```robotframework
  [Arguments]
  ...    ${unique_id}
  ...    ${project_path}
  ...    ${pipeline_name}
  ...    ${task_name}
  ...    ${pipeline_params}=None
  ...    ${notification}=None
  ...    ${plex_name}=${groundplex_name}
  ```

**Why This Change?**
- `plex_name` moved to position 5 for easier access
- Can skip `pipeline_params` and `notification` while still setting `plex_name`
- Supports both positional and named argument syntax

**Example Usage:**

**Using Positional Arguments:**
```robotframework
Create Triggered Task From Template
...    ${unique_id}
...    ${PIPELINES_LOCATION_PATH}
...    ${pipeline_name}
...    ${task_name}
...    ${CUSTOM_PLEX}    # plex_name at position 5
```

**Using Named Arguments (Recommended):**
```robotframework
Create Triggered Task From Template
...    ${unique_id}
...    ${PIPELINES_LOCATION_PATH}
...    ${pipeline_name}
...    ${task_name}
...    plex_name=${GROUNDPLEX_NAME}
...    pipeline_params=${task_params_set}
...    notification=${task_notifications}
```

**Benefits:**
- ✅ More flexible parameter passing
- ✅ Can skip optional parameters easily
- ✅ Better code readability with named arguments
- ✅ No breaking changes (backward compatible)

---

### 3. Execute Triggered Task Test Case

**Purpose:** Enable dynamic parameter updates at runtime

**Keyword Used:** `Run Triggered Task With Parameters From Template`

**Features:**
- Merges new parameters with existing task parameters
- Supports passing individual parameters
- Supports passing dictionary variables
- Updates task definition via API before execution

**Example Usage:**

**Passing Individual Parameters:**
```robotframework
Execute Triggered Task
    [Template]    Run Triggered Task With Parameters From Template
    ${unique_id}    ${PIPELINES_LOCATION_PATH}    ${pipeline_name}    ${task_name}    schema_name=PROD    table_name=PROD.USERS
```

**Passing Dictionary Variables:**
```robotframework
*** Variables ***
&{runtime_params}
...    schema_name=PROD
...    table_name=PROD.ORDERS
...    batch_size=1000

*** Test Cases ***
Execute Triggered Task
    Run Triggered Task With Parameters From Template
    ...    ${unique_id}
    ...    ${PIPELINES_LOCATION_PATH}
    ...    ${pipeline_name}
    ...    ${task_name}
    ...    &{runtime_params}
```

**Benefits:**
- ✅ Dynamic parameter override at runtime
- ✅ No need to recreate tasks for different parameters
- ✅ Supports data-driven testing
- ✅ Maintains existing parameters while updating specific ones

---

### 4. Upload File Test Case

**Purpose:** Standardize file upload operations and destination paths

**Changes Made:**

#### Destination Path Standardization
- **Previous:** Various project-specific paths scattered across tests
- **Updated:** Standardized destination paths using global variables
  - `${ACCOUNT_LOCATION_PATH}` for account-related files
  - `${PIPELINES_LOCATION_PATH}` for pipeline-related files
  - Project-specific variables for custom destinations

#### Upload File Arguments Updated

**Keyword:** `Upload Files To SnapLogic From Template`

**Arguments:**
- `source_dir` - Local directory containing files
- `file_name` - File name or pattern (supports wildcards)
- `dest_path` - Destination path in SnapLogic

**Wildcard Support:**
- `*` - Matches any number of characters
- `?` - Matches single character

**Example Usage:**

**Single File Upload:**
```robotframework
Upload Files To SnapLogic From Template
    ${CURDIR}/test_data    employees.csv    ${ACCOUNT_LOCATION_PATH}
```

**Batch Upload with Wildcards:**
```robotframework
[Template]    Upload Files To SnapLogic From Template
# source_dir                  file_name    destination
${CURDIR}/test_data           *.json       ${PIPELINES_LOCATION_PATH}
${CURDIR}/expression_libs     *.expr       ${ACCOUNT_LOCATION_PATH}
```

**Benefits:**
- ✅ Supports both single and batch uploads
- ✅ Wildcard pattern matching for flexible file selection
- ✅ Consistent destination path management
- ✅ Template-friendly for data-driven testing

---



## 🎯 Overall Impact

### Consistency
- All test cases follow the same parameter pattern
- Standardized approach across database, messaging, and mock services
- Uniform naming conventions for variables

### Maintainability
- Environment-driven configuration reduces hardcoded values
- Clear variable names improve code readability
- Changes to account payloads require updates in one place only

### Flexibility
- Support for both positional and named arguments
- Easy to skip optional parameters
- Dynamic parameter updates at runtime
- Wildcard support for file operations

### Reusability
- Template-based test cases support data-driven testing
- Shared keywords work across all service types
- Configuration can be reused across different environments

### Clarity
- Self-documenting code with descriptive variable names
- Comments guide users to payload file locations
- Consistent patterns reduce learning curve

---

## 📝 Migration Guide

### For Existing Tests

If you have existing test files that need to be updated:

1. **Update Create Account Test Case:**
   ```robotframework
   # Old format
   Create Account From Template    ${account_payload_path}/${ACCOUNT_PAYLOAD_FILE}
   
   # New format
   Create Account From Template    ${ACCOUNT_LOCATION_PATH}    ${MYSQL_ACCOUNT_PAYLOAD_FILE_NAME}    ${MYSQL_ACCOUNT_NAME}
   ```

2. **Update Create Triggered Task (if using positional args):**
   ```robotframework
   # Old format
   Create Triggered Task From Template
   ...    ${unique_id}    ${project_path}    ${pipeline_name}    ${task_name}
   ...    ${params}    ${notification}    ${plex}
   
   # New format (recommended - use named args)
   Create Triggered Task From Template
   ...    ${unique_id}    ${project_path}    ${pipeline_name}    ${task_name}
   ...    plex_name=${plex}
   ...    pipeline_params=${params}
   ...    notification=${notification}
   ```

3. **Add Environment Variables:**
   - Add `<DATABASE>_ACCOUNT_PAYLOAD_FILE_NAME` to your `.env` files
   - Ensure the variable points to the correct payload file in `/test/suite/test_data/accounts_payload/`

---

## 🔄 Backward Compatibility

### Breaking Changes
- ⚠️ `Create Account From Template` now requires 3 parameters (was 1)
- ⚠️ Argument order changed in `Create Triggered Task From Template`

### Non-Breaking Changes
- ✅ Named arguments still work as before
- ✅ Existing payload files remain unchanged
- ✅ All other keywords maintain backward compatibility

---

## 📚 Additional Resources

- **Payload Files Location:** `/test/suite/test_data/accounts_payload/`
- **Environment Files Location:** `/env_files/`
- **Test Files Location:** `/test/suite/pipeline_tests/`
- **Common Keywords:** `snaplogic_common_robot/snaplogic_apis_keywords/snaplogic_keywords.resource`

---

## 📅 Change History

| Date       | Version | Description                               |
| ---------- | ------- | ----------------------------------------- |
| 2025-01-07 | 1.0     | Initial standardization of test framework |

---

## ✉️ Questions or Issues?

For questions about these changes or issues encountered during migration, please contact the test automation team or create an issue in the project repository.

---

**Document Version:** 1.0  
**Last Updated:** January 7, 2025  
**Authors:** Test Automation Team
