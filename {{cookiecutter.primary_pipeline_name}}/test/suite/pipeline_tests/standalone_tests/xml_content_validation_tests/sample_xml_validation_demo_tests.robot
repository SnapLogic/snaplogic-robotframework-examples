*** Settings ***
Documentation       Sample Demo — All 16 Reusable Keywords from xml_validations.resource
...                 This file demonstrates every reusable keyword available in the shared
...                 XML resource file. Each test case is a thin one-liner calling one keyword.
...                 Use this as a reference when building new XML test files.
...
...                 Test data uses realistic SnapLogic EBAS_to_CBS pipeline structure in XML format:
...                 - Pipeline config XML with Accounts (DEV/QA/PREPROD/PROD), Schema, paths
...                 - Same domain data as the JSON demo but represented as XML elements/attributes
...
...                 Keywords demonstrated (16):
...                 1.  Validate XML File Exists And Not Empty
...                 2.  Validate XML Element Value
...                 3.  Validate XML Elements Match Expected
...                 4.  Validate All Required XML Elements Present
...                 5.  Validate XML Element Matches Pattern
...                 6.  Validate XML Element Attribute Value
...                 7.  Count Data Elements In XML
...                 8.  Get XML Element Value By XPath
...                 9.  Check XML Element Exists
...                 10. Check XML Element Does Not Exist
...                 11. Validate XML Element Greater Than
...                 12. Validate XML Elements Sum Equals Expected
...                 13. Validate XML Two Elements Are Equal
...                 14. Compare XML Files Template
...                 15. Modify XML Element And Save (with restore)
...                 16. (inline) Element Count Sanity Check using Get Element Count
...
...                 Run:
...                 robot test/suite/pipeline_tests/standalone_tests/xml_content_validation_tests/sample_xml_validation_demo_tests.robot
...                 robot --include xml-sample test/suite/pipeline_tests/standalone_tests/xml_content_validation_tests/

Library             XML
Library             OperatingSystem
Library             Collections
Library             String
Resource            ../../../../resources/common/xml_validations.resource

Suite Setup         Load Sample XML Demo Data


*** Variables ***
${SAMPLE_ACTUAL}        ${CURDIR}/test_data/actual/sample_actual.xml
${SAMPLE_EXPECTED}      ${CURDIR}/test_data/expected/sample_expected.xml

# For Validate XML Element Value
${EXPECTED_STATUS}      active

# For Validate XML Element Matches Pattern (Jira ticket format)
${JIRA_PATTERN}         ^[A-Z]+-\\d+$

# For Validate XML Element Greater Than
${MIN_RECORD_COUNT}     0

# For Validate XML Elements Sum Equals Expected
${EXPECTED_SUM_TOTAL}   450

# Required element XPaths for Validate All Required XML Elements Present
@{REQUIRED_XPATHS}
...    .//status
...    .//pipeline_name
...    .//project
...    .//jira_ticket
...    .//approved_by
...    .//reviewed_by

# XPaths for multi-element match
@{MATCH_XPATHS}
...    .//status
...    .//pipeline_name
...    .//project
...    .//approved_by
...    .//reviewed_by

# XPaths for sum check
@{SUM_XPATHS}
...    .//source_table_1_count
...    .//source_table_2_count
...    .//source_table_3_count

# Expected number of output columns
${EXPECTED_COLUMN_COUNT}    5

# Expected number of required element XPaths
${EXPECTED_REQUIRED_COUNT}    6


*** Test Cases ***
# ────────────────────────────────────────────────────────────────
# KEYWORD 1: Validate XML File Exists And Not Empty
# ────────────────────────────────────────────────────────────────
Demo 01 - Validate XML File Exists And Not Empty
    [Documentation]    Checks that an XML file exists on disk and has content (size > 0 bytes).
    [Tags]    ebaas    xml-sample    keyword-01
    Validate XML File Exists And Not Empty    ${SAMPLE_ACTUAL}

# ────────────────────────────────────────────────────────────────
# KEYWORD 2: Validate XML Element Value
# ────────────────────────────────────────────────────────────────
Demo 02 - Validate XML Element Value
    [Documentation]    Extracts a single element's text from XML and asserts it equals the expected value.
    ...    Example: Verify pipeline_name is EBAS_to_CBS.
    [Tags]    ebaas    xml-sample    keyword-02
    Validate XML Element Value    ${ACTUAL_XML}    .//pipeline_name    EBAS_to_CBS

# ────────────────────────────────────────────────────────────────
# KEYWORD 3: Validate XML Elements Match Expected
# ────────────────────────────────────────────────────────────────
Demo 03 - Validate XML Elements Match Expected
    [Documentation]    Compares multiple element values between actual and expected XML data.
    ...    Example: Verify status, pipeline_name, project, approved_by, reviewed_by all match.
    [Tags]    ebaas    xml-sample    keyword-03
    Validate XML Elements Match Expected    ${ACTUAL_XML}    ${EXPECTED_XML}
    ...    .//status    .//pipeline_name    .//project    .//approved_by    .//reviewed_by

# ────────────────────────────────────────────────────────────────
# KEYWORD 4: Validate All Required XML Elements Present
# ────────────────────────────────────────────────────────────────
Demo 04 - Validate All Required XML Elements Present
    [Documentation]    Validates that all specified elements exist in XML and have non-empty text.
    ...    Example: status, pipeline_name, project, jira_ticket, approved_by, reviewed_by.
    [Tags]    ebaas    xml-sample    keyword-04
    Validate All Required XML Elements Present    ${ACTUAL_XML}    @{REQUIRED_XPATHS}

# ────────────────────────────────────────────────────────────────
# KEYWORD 5: Validate XML Element Matches Pattern
# ────────────────────────────────────────────────────────────────
Demo 05 - Validate XML Element Matches Pattern
    [Documentation]    Extracts an element and validates it against a regex pattern.
    ...    Example: Verify jira_ticket matches EBAS-5042 format (^[A-Z]+-\d+$).
    [Tags]    ebaas    xml-sample    keyword-05
    Validate XML Element Matches Pattern    ${ACTUAL_XML}    .//jira_ticket    ${JIRA_PATTERN}

# ────────────────────────────────────────────────────────────────
# KEYWORD 6: Validate XML Element Attribute Value (XML-specific)
# ────────────────────────────────────────────────────────────────
Demo 06 - Validate XML Element Attribute Value
    [Documentation]    Validates that an XML element's attribute equals the expected value.
    ...    Example: Verify <pipeline_config version="2.0"> attribute.
    [Tags]    ebaas    xml-sample    keyword-06
    Validate XML Element Attribute Value    ${ACTUAL_XML}    .    version    2.0

# ────────────────────────────────────────────────────────────────
# KEYWORD 7: Count Data Elements In XML
# ────────────────────────────────────────────────────────────────
Demo 07 - Count Data Elements In XML
    [Documentation]    Counts the number of child elements under a parent element.
    ...    Example: Count output_columns/column elements (should be 5).
    [Tags]    ebaas    xml-sample    keyword-07
    ${count}=    Count Data Elements In XML    ${SAMPLE_ACTUAL}    .//output_columns
    Should Be Equal As Integers    ${count}    ${EXPECTED_COLUMN_COUNT}
    ...    Expected ${EXPECTED_COLUMN_COUNT} output columns but found ${count}

# ────────────────────────────────────────────────────────────────
# KEYWORD 8: Get XML Element Value By XPath
# ────────────────────────────────────────────────────────────────
Demo 08 - Get XML Element Value By XPath
    [Documentation]    Extracts a specific element's text value using XPath from a file.
    ...    Example: Get the schema value directly from file.
    [Tags]    ebaas    xml-sample    keyword-08
    ${value}=    Get XML Element Value By XPath    ${SAMPLE_ACTUAL}    .//schema
    Should Be Equal    ${value}    dbo
    ...    Expected schema 'dbo' but got '${value}'

# ────────────────────────────────────────────────────────────────
# KEYWORD 9: Check XML Element Exists
# ────────────────────────────────────────────────────────────────
Demo 09 - Check XML Element Exists
    [Documentation]    Checks if an XML element exists at the given XPath.
    ...    Example: Verify the accounts/DEV element exists with expected value.
    [Tags]    ebaas    xml-sample    keyword-09
    Check XML Element Exists    ${SAMPLE_ACTUAL}    .//accounts/DEV    ../shared/EBAS2CBS_SQL_All

# ────────────────────────────────────────────────────────────────
# KEYWORD 10: Check XML Element Does Not Exist
# ────────────────────────────────────────────────────────────────
Demo 10 - Check XML Element Does Not Exist
    [Documentation]    Checks if an XML element does NOT exist at the given XPath.
    ...    Example: Verify there is no deprecated_field element.
    [Tags]    ebaas    xml-sample    keyword-10
    Check XML Element Does Not Exist    ${SAMPLE_ACTUAL}    .//deprecated_field

# ────────────────────────────────────────────────────────────────
# KEYWORD 11: Validate XML Element Greater Than
# ────────────────────────────────────────────────────────────────
Demo 11 - Validate XML Element Greater Than
    [Documentation]    Extracts a numeric element and asserts it is greater than a minimum value.
    ...    Example: Verify record_count > 0 (non-zero records processed).
    [Tags]    ebaas    xml-sample    keyword-11
    Validate XML Element Greater Than    ${ACTUAL_XML}    .//record_count    ${MIN_RECORD_COUNT}

# ────────────────────────────────────────────────────────────────
# KEYWORD 12: Validate XML Elements Sum Equals Expected
# ────────────────────────────────────────────────────────────────
Demo 12 - Validate XML Elements Sum Equals Expected
    [Documentation]    Sums multiple numeric elements and asserts the total equals expected value.
    ...    Example: source_table_1 (100) + source_table_2 (200) + source_table_3 (150) = 450.
    [Tags]    ebaas    xml-sample    keyword-12
    Validate XML Elements Sum Equals Expected    ${ACTUAL_XML}    ${EXPECTED_SUM_TOTAL}
    ...    .//source_table_1_count    .//source_table_2_count    .//source_table_3_count

# ────────────────────────────────────────────────────────────────
# KEYWORD 13: Validate XML Two Elements Are Equal
# ────────────────────────────────────────────────────────────────
Demo 13 - Validate XML Two Elements Are Equal
    [Documentation]    Asserts that two elements from the same XML have equal values.
    ...    Example: source_total (450) = target_total (450) — data integrity check.
    [Tags]    ebaas    xml-sample    keyword-13
    Validate XML Two Elements Are Equal    ${ACTUAL_XML}    .//source_total    .//target_total

# ────────────────────────────────────────────────────────────────
# KEYWORD 14: Compare XML Files Template
# ────────────────────────────────────────────────────────────────
Demo 14 - Compare XML Files Template
    [Documentation]    Compares two XML files element by element.
    ...    Example: Compare actual XML against itself (guaranteed identical).
    [Tags]    ebaas    xml-sample    keyword-14
    Compare XML Files Template    ${SAMPLE_ACTUAL}    ${SAMPLE_ACTUAL}

# ────────────────────────────────────────────────────────────────
# KEYWORD 15: Modify XML Element And Save (with restore)
# ────────────────────────────────────────────────────────────────
Demo 15 - Modify XML Element And Save
    [Documentation]    Modifies an XML element's text value and saves to a temp file.
    ...    Example: Change schema from 'dbo' to 'test_schema' in a temp copy.
    [Tags]    ebaas    xml-sample    keyword-15
    ${temp_file}=    Set Variable    ${CURDIR}/test_data/actual/temp_modified.xml
    Modify XML Element And Save    ${SAMPLE_ACTUAL}    .//schema    test_schema    ${temp_file}
    # Verify the modification
    ${value}=    Get XML Element Value By XPath    ${temp_file}    .//schema
    Should Be Equal    ${value}    test_schema
    # Clean up temp file
    Remove File    ${temp_file}

# ────────────────────────────────────────────────────────────────
# BONUS: Inline Element Count Sanity Check
# ────────────────────────────────────────────────────────────────
Demo 16 - Verify Required XPaths Count
    [Documentation]    Inline sanity check — confirms the number of required XPaths matches expected count.
    ...    Uses Get Length (not a reusable keyword, but a common inline pattern).
    [Tags]    ebaas    xml-sample    keyword-16
    ${actual_count}=    Get Length    ${REQUIRED_XPATHS}
    Should Be Equal As Integers    ${actual_count}    ${EXPECTED_REQUIRED_COUNT}
    ...    XPath count mismatch: found ${actual_count} but expected ${EXPECTED_REQUIRED_COUNT}


*** Keywords ***
Load Sample XML Demo Data
    [Documentation]    Suite Setup — Loads XML files into suite variables for reuse across test cases.
    Log    Loading sample XML demo data...    console=yes
    Validate XML File Exists And Not Empty    ${SAMPLE_ACTUAL}
    Validate XML File Exists And Not Empty    ${SAMPLE_EXPECTED}
    ${actual}=    Parse Xml    ${SAMPLE_ACTUAL}
    ${expected}=    Parse Xml    ${SAMPLE_EXPECTED}
    Set Suite Variable    ${ACTUAL_XML}    ${actual}
    Set Suite Variable    ${EXPECTED_XML}    ${expected}
    Log    Sample XML demo data loaded successfully    console=yes
