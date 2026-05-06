*** Settings ***
Documentation       Test Suite for Oracle Database Integration with Pipeline Tasks
...                 This suite validates Oracle database integration by:
...                 1. Creating necessary database tables and procedures
...                 2. Importing and configuring pipeline tasks
...                 3. Executing tasks and verifying database interactions
...                 4. Testing control date updates and procedure execution

# Standard Libraries
Library             OperatingSystem    # File system operations
Library             DatabaseLibrary    # Generic database operations
Library             oracledb    # Oracle specific operations
Library             DependencyLibrary
Resource            snaplogic_common_robot/snaplogic_apis_keywords/snaplogic_keywords.resource
# SnapLogic API keywords from installed package


*** Variables ***
# Project Configuration
${upload_source_file_path}      ${CURDIR}/../../../test_data/actual_expected_data/expression_libraries


*** Test Cases ***
Upload Files
    [Documentation]    Data-driven test case that uploads one or more files to SnapLogic SLDB.
    ...    Each row below is an independent upload — Robot Framework calls
    ...    `Upload Files To SnapLogic From Template` once per row.
    ...
    ...    📋 KEYWORD USED:
    ...    `Upload Files To SnapLogic From Template`
    ...    └─ Imported from the `snaplogic_common_robot` pip package
    ...    (see Resource line at the top of this file).
    ...
    ...    📋 ARGUMENTS (3 positional, all required):
    ...    source_dir, file_name, destination_path
    ...
    ...    📋 PREREQUISITES:
    ...    • Source directory exists on disk.
    ...    • For wildcard rows, at least one matching file should exist
    ...    (zero matches uploads nothing and passes silently).
    ...    • SnapLogic project space exists (handled by suite setup).
    ...
    ...    📋 OUTPUT:
    ...    Uploaded files appear in SnapLogic UI under
    ...    <ORG> → <project_space> → shared.
    [Tags]    upload_file_sample
    [Template]    Upload Files To SnapLogic From Template

    # ┌─ source_dir (local) ──────────────────────────────────┬─---------------─┬─-file_name ────┬─ destination_path ─────────┐
    ${CURDIR}/../../../test_data/actual_expected_data/expression_libraries    test.expr    ${ACCOUNT_LOCATION_PATH}

    # Wildcard: upload every .expr file in the directory
    ${upload_source_file_path}    *.expr    ${ACCOUNT_LOCATION_PATH}

    # ── More examples (uncomment to use) ──────────────────────────────────────────────────────────────
    # Single-character wildcard — any 3-letter extension starting with 'e':
    # ${upload_source_file_path}    employees.?pr    ${ACCOUNT_LOCATION_PATH}
    #
    # JAR file (note: source_dir using file path ):
    #    file:///opt/snaplogic/test_data/accounts_jar_files/mysql    mysql-connector-j-9.3.0.jar    ${ACCOUNT_LOCATION_PATH}
