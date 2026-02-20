*** Settings ***
Documentation       XML-focused resource file for validation, comparison, and content verification.
...                 Contains keywords for:
...                 - XML file loading and validation
...                 - XML element value assertion and pattern matching
...                 - XML attribute validation
...                 - XML element comparison between actual and expected
...                 - Required element presence and non-empty checks
...                 - Numeric element validation (greater than, sum, equality)
...                 - XML file comparison
...                 - XML schema (XSD) validation

Library             XML
Library             OperatingSystem
Library             Collections
Library             String


*** Keywords ***
################## FILE ANALYSIS AND COUNTING ##################

Count Data Elements In XML
    [Documentation]    Counts the number of child elements under a parent element in an XML file.
    ...
    ...    *Arguments:*
    ...    - ``xml_file``: Path to the XML file to analyze
    ...    - ``xpath``: XPath to the parent element whose children to count (default: root ``.'')
    ...
    ...    *Returns:*
    ...    - Number of direct child elements
    ...
    ...    *Examples:*
    ...    | ${count}= | Count Data Elements In XML | data.xml |
    ...    | ${count}= | Count Data Elements In XML | data.xml | .//output_columns |
    [Arguments]    ${xml_file}    ${xpath}=.

    ${xml}=    Parse Xml    ${xml_file}
    ${elements}=    Get Elements    ${xml}    ${xpath}/*
    ${count}=    Get Length    ${elements}
    Log    XML element count at '${xpath}': ${count} elements
    RETURN    ${count}

################## FILE COMPARISON ##################

Compare XML Files With Exclusions Template
    [Documentation]    Template keyword for XML comparison with exclusions and validation.
    ...    Compares two XML files while ignoring specified element tags (useful for dynamic fields
    ...    like timestamps, execution IDs, connector push times, etc.).
    ...    Removes matching elements from both XML trees before comparison.
    ...
    ...    *Arguments:*
    ...    - ``file1_path``: Path to actual output XML file
    ...    - ``file2_path``: Path to expected output XML file
    ...    - ``expected_status``: Expected comparison result (PASS or FAIL)
    ...    - ``normalize_whitespace``: Whether to normalize whitespace in text (default: TRUE)
    ...    - ``@exclude_tags``: One or more element tag names to exclude from comparison
    ...
    ...    *Examples:*
    ...    | Compare XML Files With Exclusions Template |
    ...    | ...    ${actual_file}    ${expected_file}    PASS |
    ...    | ...    ${TRUE}    created_at    updated_at    execution_id |
    ...
    ...    *See also:* `Compare XML Files Template`
    [Arguments]
    ...    ${file1_path}
    ...    ${file2_path}
    ...    ${expected_status}
    ...    ${normalize_whitespace}=${TRUE}
    ...    @{exclude_tags}

    Log    \nComparing XML files with exclusions:    console=yes
    Log    File 1 (Actual): ${file1_path}    console=yes
    Log    File 2 (Expected): ${file2_path}    console=yes
    Log    Excluded Tags: ${exclude_tags}    console=yes
    Log    Expected Status: ${expected_status}    console=yes

    ${xml1}=    Parse Xml    ${file1_path}
    ${xml2}=    Parse Xml    ${file2_path}

    # Remove excluded elements from both trees
    FOR    ${tag}    IN    @{exclude_tags}
        ${xpath}=    Set Variable    .//${tag}
        Remove Elements    ${xml1}    ${xpath}
        Remove Elements    ${xml2}    ${xpath}
    END

    # Compare the filtered XML trees
    ${status}=    Run Keyword And Return Status
    ...    Elements Should Be Equal    ${xml1}    ${xml2}
    ...    normalize_whitespace=${normalize_whitespace}

    IF    '${expected_status}' == 'PASS'
        Should Be True    ${status}
        ...    XML files differ after excluding tags: ${exclude_tags}
        Log    XML comparison with exclusions completed - Status: PASS (IDENTICAL)    console=yes
    ELSE
        Should Not Be True    ${status}
        ...    Expected XML files to differ, but they are identical after exclusions
        Log    XML comparison with exclusions completed - Status: FAIL (DIFFERENT as expected)    console=yes
    END

Compare XML Files Template
    [Documentation]    Template keyword for XML comparison with validation.
    ...    Compares two XML files element by element using ``Elements Should Be Equal``.
    ...
    ...    *Arguments:*
    ...    - ``file1_path``: Path to the first XML file (actual output)
    ...    - ``file2_path``: Path to the second XML file (expected output)
    ...    - ``normalize_whitespace``: Whether to normalize whitespace in text (default: TRUE)
    ...    - ``exclude_comments``: Whether to exclude comments from comparison (default: TRUE)
    ...
    ...    *Example:*
    ...    | Compare XML Files Template | ${actual_file} | ${expected_file} | ${TRUE} | ${TRUE} |
    [Arguments]    ${file1_path}    ${file2_path}    ${normalize_whitespace}=${TRUE}    ${exclude_comments}=${TRUE}

    Log    Comparing XML files:    console=yes
    Log    File 1 (Actual): ${file1_path}    console=yes
    Log    File 2 (Expected): ${file2_path}    console=yes

    ${xml1}=    Parse Xml    ${file1_path}
    ${xml2}=    Parse Xml    ${file2_path}

    Elements Should Be Equal
    ...    ${xml1}
    ...    ${xml2}
    ...    normalize_whitespace=${normalize_whitespace}
    ...    exclude_comments=${exclude_comments}

    Log    XML comparison completed successfully — files are identical    console=yes

################## XML UTILS ##################

Get XML Element Value By XPath
    [Documentation]    Extracts a specific element's text value from XML using XPath expression.
    ...
    ...    *Arguments:*
    ...    - ``xml_file``: Path to the XML file
    ...    - ``xpath``: XPath expression (e.g., ``.//config/timeout``)
    ...
    ...    *Returns:*
    ...    - Text content of the matched element
    ...
    ...    *Example:*
    ...    | ${value}= | Get XML Element Value By XPath | config.xml | .//pipeline_name |
    [Arguments]    ${xml_file}    ${xpath}

    ${xml}=    Parse Xml    ${xml_file}
    ${value}=    Get Element Text    ${xml}    ${xpath}
    Log    Extracted value from '${xpath}': ${value}
    RETURN    ${value}

Validate XML Against Schema File
    [Documentation]    Validates an XML file against an XSD schema file using ``lxml``.
    ...
    ...    *Arguments:*
    ...    - ``xml_file``: Path to the XML file to validate
    ...    - ``schema_file``: Path to the XSD schema file
    ...
    ...    *Example:*
    ...    | Validate XML Against Schema File | ${CURDIR}/data/output.xml | ${CURDIR}/schemas/output.xsd |
    ...
    ...    *Note:* Requires ``lxml`` Python package to be installed.
    [Arguments]    ${xml_file}    ${schema_file}

    Log    Validating XML file against XSD schema...    console=yes
    Log    XML file: ${xml_file}    console=yes
    Log    Schema file: ${schema_file}    console=yes

    ${result}=    Evaluate
    ...    __import__('lxml.etree', fromlist=['etree']).XMLSchema(__import__('lxml.etree', fromlist=['etree']).parse('${schema_file}')).validate(__import__('lxml.etree', fromlist=['etree']).parse('${xml_file}'))
    Should Be True    ${result}    XML file does not conform to XSD schema: ${schema_file}
    Log    XML schema validation passed successfully    console=yes

Check XML Element Exists
    [Documentation]    Checks if an XML element exists at the given XPath.
    ...    Optionally verifies the element's text matches an expected value.
    ...
    ...    *Arguments:*
    ...    - ``xml_file``: Path to the XML file
    ...    - ``xpath``: XPath expression to check
    ...    - ``expected_value``: Optional expected text value (default: None)
    ...
    ...    *Examples:*
    ...    | Check XML Element Exists | config.xml | .//pipeline_name |
    ...    | Check XML Element Exists | config.xml | .//pipeline_name | EBAS_to_CBS |
    [Arguments]    ${xml_file}    ${xpath}    ${expected_value}=${None}

    ${xml}=    Parse Xml    ${xml_file}
    Element Should Exist    ${xml}    ${xpath}

    IF    '${expected_value}' != '${None}'
        ${actual_value}=    Get Element Text    ${xml}    ${xpath}
        Should Be Equal    ${actual_value}    ${expected_value}
        Log    XML element '${xpath}' contains expected value '${expected_value}'    console=yes
    ELSE
        Log    XML element exists at path '${xpath}'    console=yes
    END

Check XML Element Does Not Exist
    [Documentation]    Checks if an XML element does NOT exist at the given XPath.
    ...
    ...    *Arguments:*
    ...    - ``xml_file``: Path to the XML file
    ...    - ``xpath``: XPath expression that should not exist
    ...
    ...    *Example:*
    ...    | Check XML Element Does Not Exist | config.xml | .//deprecated_field |
    [Arguments]    ${xml_file}    ${xpath}

    ${xml}=    Parse Xml    ${xml_file}
    Element Should Not Exist    ${xml}    ${xpath}
    Log    XML element does not exist at path '${xpath}'    console=yes

Modify XML Element And Save
    [Documentation]    Modifies an XML element's text value and saves the file.
    ...
    ...    *Arguments:*
    ...    - ``xml_file``: Path to the source XML file
    ...    - ``xpath``: XPath expression for the element to modify
    ...    - ``new_value``: New text value to set
    ...    - ``output_file``: Path to save modified XML (default: overwrites source file)
    ...
    ...    *Example:*
    ...    | Modify XML Element And Save | config.xml | .//timeout | 60 |
    ...    | Modify XML Element And Save | config.xml | .//timeout | 60 | modified_config.xml |
    [Arguments]    ${xml_file}    ${xpath}    ${new_value}    ${output_file}=${xml_file}

    ${xml}=    Parse Xml    ${xml_file}
    Set Element Text    ${xml}    ${new_value}    ${xpath}
    Save Xml    ${xml}    ${output_file}
    Log    Modified XML element '${xpath}' with value '${new_value}' and saved to: ${output_file}    console=yes

################## XML VALIDATION ##################

Validate XML File Exists And Not Empty
    [Documentation]    Validates that an XML file exists and has content (size > 0 bytes).
    ...
    ...    *Arguments:*
    ...    - ``file_path``: Path to the XML file to validate
    ...
    ...    *Example:*
    ...    | Validate XML File Exists And Not Empty | ${CURDIR}/data/pipeline_config.xml |
    [Arguments]    ${file_path}
    File Should Exist    ${file_path}
    ...    File not found: ${file_path}
    ${size}=    Get File Size    ${file_path}
    Should Be True    ${size} > 0
    ...    File is empty (0 bytes): ${file_path}
    Log    File verified: ${file_path} (${size} bytes)    console=yes

Validate XML Element Value
    [Documentation]    Extracts an element's text from parsed XML and asserts it equals the expected value.
    ...
    ...    *Arguments:*
    ...    - ``xml_data``: Parsed XML object (from ``Parse Xml``)
    ...    - ``xpath``: XPath expression to the element
    ...    - ``expected_value``: The value the element text should have
    ...
    ...    *Example:*
    ...    | Validate XML Element Value | ${xml} | .//status | active |
    [Arguments]    ${xml_data}    ${xpath}    ${expected_value}
    ${actual_value}=    Get Element Text    ${xml_data}    ${xpath}
    Should Be Equal As Strings    ${actual_value}    ${expected_value}
    ...    Element '${xpath}': expected '${expected_value}' but got '${actual_value}'
    Log    Element '${xpath}' = '${actual_value}' (matches expected)    console=yes

Validate XML Elements Match Expected
    [Documentation]    Compares specified element values between actual and expected XML data.
    ...    Pass the XPath expressions you want to match — this keyword loops through all of them.
    ...
    ...    *Arguments:*
    ...    - ``actual_xml``: Parsed actual XML object
    ...    - ``expected_xml``: Parsed expected XML object
    ...    - ``@xpaths``: One or more XPath expressions to compare
    ...
    ...    *Example:*
    ...    | Validate XML Elements Match Expected | ${actual} | ${expected} |
    ...    | ...    .//status    .//pipeline_name    .//project    .//approved_by |
    [Arguments]    ${actual_xml}    ${expected_xml}    @{xpaths}
    ${total}=    Get Length    ${xpaths}
    FOR    ${xpath}    IN    @{xpaths}
        ${actual_value}=    Get Element Text    ${actual_xml}    ${xpath}
        ${expected_value}=    Get Element Text    ${expected_xml}    ${xpath}
        Should Be Equal As Strings    ${actual_value}    ${expected_value}
        ...    Element '${xpath}' mismatch: actual='${actual_value}' vs expected='${expected_value}'
        Log    MATCH: '${xpath}' = '${actual_value}'    console=yes
    END
    Log    All ${total} elements matched between actual and expected    console=yes

Validate All Required XML Elements Present
    [Documentation]    Validates that all specified elements exist in the XML and have non-empty text.
    ...
    ...    *Arguments:*
    ...    - ``xml_data``: Parsed XML object
    ...    - ``@xpaths``: One or more XPath expressions that must exist and be non-empty
    ...
    ...    *Example:*
    ...    | Validate All Required XML Elements Present | ${xml} |
    ...    | ...    .//status    .//pipeline_name    .//project    .//jira_ticket |
    [Arguments]    ${xml_data}    @{xpaths}
    FOR    ${xpath}    IN    @{xpaths}
        Element Should Exist    ${xml_data}    ${xpath}
        ...    Required element '${xpath}' is missing from XML data
        ${value}=    Get Element Text    ${xml_data}    ${xpath}
        Should Not Be Empty    ${value}
        ...    Element '${xpath}' exists but is empty
        Log    Required element present: '${xpath}' = '${value}'    console=yes
    END
    ${total}=    Get Length    ${xpaths}
    Log    All ${total} required elements present and non-empty    console=yes

Validate XML Element Matches Pattern
    [Documentation]    Extracts an element's text from XML and validates it against a regex pattern.
    ...
    ...    *Arguments:*
    ...    - ``xml_data``: Parsed XML object
    ...    - ``xpath``: XPath expression to the element
    ...    - ``pattern``: Regex pattern the element value must match
    ...
    ...    *Example:*
    ...    | Validate XML Element Matches Pattern | ${xml} | .//jira_ticket | ^[A-Z]+-\\d+$ |
    [Arguments]    ${xml_data}    ${xpath}    ${pattern}
    ${value}=    Get Element Text    ${xml_data}    ${xpath}
    Should Not Be Empty    ${value}
    ...    Element '${xpath}' is empty — cannot validate pattern
    Should Match Regexp    ${value}    ${pattern}
    ...    Element '${xpath}' value '${value}' does not match pattern '${pattern}'
    Log    Element '${xpath}' = '${value}' matches pattern '${pattern}'    console=yes

Validate XML Element Attribute Value
    [Documentation]    Validates that an XML element's attribute equals the expected value.
    ...    This is XML-specific — JSON does not have attributes.
    ...
    ...    *Arguments:*
    ...    - ``xml_data``: Parsed XML object
    ...    - ``xpath``: XPath expression to the element
    ...    - ``attribute``: Name of the attribute to check
    ...    - ``expected_value``: The value the attribute should have
    ...
    ...    *Example:*
    ...    | Validate XML Element Attribute Value | ${xml} | .//pipeline | version | 2.0 |
    [Arguments]    ${xml_data}    ${xpath}    ${attribute}    ${expected_value}
    ${actual_value}=    Get Element Attribute    ${xml_data}    ${attribute}    ${xpath}
    Should Not Be Equal    ${actual_value}    ${None}
    ...    Attribute '${attribute}' not found on element '${xpath}'
    Should Be Equal As Strings    ${actual_value}    ${expected_value}
    ...    Attribute '${attribute}' on '${xpath}': expected '${expected_value}' but got '${actual_value}'
    Log    Attribute '${attribute}' on '${xpath}' = '${actual_value}' (matches expected)    console=yes

Validate XML Element Greater Than
    [Documentation]    Extracts a numeric element from XML and asserts it is greater than a minimum value.
    ...    Useful for count validations where value must exceed a threshold.
    ...
    ...    *Arguments:*
    ...    - ``xml_data``: Parsed XML object
    ...    - ``xpath``: XPath expression to the numeric element
    ...    - ``min_value``: The minimum value (exclusive — actual must be > ``min_value``)
    ...
    ...    *Example:*
    ...    | Validate XML Element Greater Than | ${xml} | .//record_count | 0 |
    [Arguments]    ${xml_data}    ${xpath}    ${min_value}
    ${value_str}=    Get Element Text    ${xml_data}    ${xpath}
    ${actual_value}=    Convert To Number    ${value_str}
    Should Be True    ${actual_value} > ${min_value}
    ...    Element '${xpath}' value ${actual_value} is not greater than ${min_value}
    Log    Element '${xpath}' = ${actual_value} (> ${min_value})    console=yes

Validate XML Elements Sum Equals Expected
    [Documentation]    Sums multiple numeric elements from XML and asserts the total
    ...    equals the expected value. Useful for verifying source table counts add up.
    ...
    ...    *Arguments:*
    ...    - ``xml_data``: Parsed XML object
    ...    - ``expected_total``: The expected sum value
    ...    - ``@xpaths``: One or more XPath expressions to numeric elements to sum
    ...
    ...    *Example:*
    ...    | Validate XML Elements Sum Equals Expected | ${xml} | 450 |
    ...    | ...    .//source_table_1_count    .//source_table_2_count    .//source_table_3_count |
    [Arguments]    ${xml_data}    ${expected_total}    @{xpaths}
    ${sum}=    Set Variable    ${0}
    FOR    ${xpath}    IN    @{xpaths}
        ${value_str}=    Get Element Text    ${xml_data}    ${xpath}
        ${value}=    Convert To Number    ${value_str}
        ${sum}=    Evaluate    ${sum} + ${value}
        Log    Element '${xpath}' = ${value}    console=yes
    END
    Should Be Equal As Integers    ${sum}    ${expected_total}
    ...    Sum of elements (${sum}) does not match expected total (${expected_total})
    ${count}=    Get Length    ${xpaths}
    Log    Sum of ${count} elements = ${sum} (matches expected ${expected_total})    console=yes

Validate XML Two Elements Are Equal
    [Documentation]    Asserts that two elements from the same XML have equal text values.
    ...    Useful for data integrity checks where two counts must match (e.g., source sum = target count).
    ...
    ...    *Arguments:*
    ...    - ``xml_data``: Parsed XML object
    ...    - ``xpath_1``: XPath to the first element
    ...    - ``xpath_2``: XPath to the second element
    ...
    ...    *Example:*
    ...    | Validate XML Two Elements Are Equal | ${xml} | .//source_total | .//target_total |
    [Arguments]    ${xml_data}    ${xpath_1}    ${xpath_2}
    ${value_1}=    Get Element Text    ${xml_data}    ${xpath_1}
    ${value_2}=    Get Element Text    ${xml_data}    ${xpath_2}
    Should Be Equal As Strings    ${value_1}    ${value_2}
    ...    Element '${xpath_1}' (${value_1}) does not equal element '${xpath_2}' (${value_2})
    Log    Elements match: '${xpath_1}' = '${xpath_2}' = ${value_1}    console=yes
