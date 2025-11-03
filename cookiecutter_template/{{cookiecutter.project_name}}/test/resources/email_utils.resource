*** Settings ***
Documentation       Email Testing Utility Keywords for MailDev Integration
...                 This resource file provides reusable keywords for email testing
...                 with MailDev mock service and SnapLogic Email Snap.

Library             RequestsLibrary
Library             Collections
Library             String
Library             JSONLibrary
Library             DateTime
Library             OperatingSystem


*** Variables ***
${DEFAULT_MAILDEV_URL}      http://maildev-test:1080
${DEFAULT_SMTP_PORT}        1025
${EMAIL_WAIT_TIMEOUT}       30s
${EMAIL_POLL_INTERVAL}      1s


*** Keywords ***
Setup MailDev Connection
    [Documentation]    Verify MailDev service is accessible using direct HTTP client
    [Arguments]    ${maildev_url}=${DEFAULT_MAILDEV_URL}

    ${response}=    GET    ${maildev_url}    expected_status=200
    Should Be Equal As Numbers    ${response.status_code}    200
    ...    msg=Cannot connect to MailDev at ${maildev_url}

    Log    Successfully connected to MailDev at ${maildev_url}    console=yes

Purge All Emails
    [Documentation]    Remove all emails from MailDev inbox using direct HTTP client
    [Arguments]    ${maildev_url}=${DEFAULT_MAILDEV_URL}

    ${response}=    DELETE    ${maildev_url}/email/all    expected_status=200
    Should Be Equal As Numbers    ${response.status_code}    200
    Log    All emails purged from MailDev    console=yes

Get Email Count
    [Documentation]    Get the current number of emails in MailDev using direct HTTP client
    [Arguments]    ${maildev_url}=${DEFAULT_MAILDEV_URL}

    ${response}=    GET    ${maildev_url}/email    expected_status=200
    ${emails}=    Set Variable    ${response.json()}
    ${count}=    Get Length    ${emails}
    Log    Current email count: ${count}    console=yes
    RETURN    ${count}

Get All Emails
    [Documentation]    Retrieve all emails from MailDev using direct HTTP client
    [Arguments]    ${maildev_url}=${DEFAULT_MAILDEV_URL}

    ${response}=    GET    ${maildev_url}/email    expected_status=200
    ${emails}=    Set Variable    ${response.json()}
    RETURN    ${emails}

Verify Email TO Recipient
    [Documentation]    Verify that email has the expected recipient in TO field
    ...    By default, fails if not found (fail_on_error=${True})
    ...    Set fail_on_error=${False} to return True/False instead
    [Arguments]    ${expected_to_email}    ${fail_on_error}=${True}    ${maildev_url}=${DEFAULT_MAILDEV_URL}

    # Get the latest email from MailDev
    ${email}=    Get And Validate Latest Email    ${maildev_url}

    # Check TO field for the recipient
    ${found}=    Set Variable    ${False}
    FOR    ${to}    IN    @{email}[to]
        IF    '${to}[address]' == '${expected_to_email}'
            Log    Recipient ${expected_to_email} found in TO field
            ${found}=    Set Variable    ${True}
            BREAK
        END
    END

    # Handle result based on fail_on_error setting
    IF    not ${found}
        Log    Recipient ${expected_to_email} NOT found in TO field
        IF    ${fail_on_error}
            Fail    TO recipient ${expected_to_email} not found in email
        END
    END

    # Return the result (True/False)
    RETURN    ${found}

Verify Email CC Recipient
    [Documentation]    Verify that email has the expected recipient in CC field
    ...    By default, fails if not found (fail_on_error=${True})
    ...    Set fail_on_error=${False} to return True/False instead
    [Arguments]    ${expected_cc_email}    ${fail_on_error}=${True}    ${maildev_url}=${DEFAULT_MAILDEV_URL}

    # Get the latest email from MailDev
    ${email}=    Get And Validate Latest Email    ${maildev_url}

    # Check if CC field exists
    ${has_cc}=    Run Keyword And Return Status
    ...    Dictionary Should Contain Key    ${email}    cc

    # Initialize found flag
    ${found}=    Set Variable    ${False}

    # Check CC field for the recipient if it exists
    IF    ${has_cc}
        FOR    ${cc}    IN    @{email}[cc]
            IF    '${cc}[address]' == '${expected_cc_email}'
                Log    Recipient ${expected_cc_email} found in CC field
                ${found}=    Set Variable    ${True}
                BREAK
            END
        END
    ELSE
        Log    Email has no CC recipients
    END

    # Handle result based on fail_on_error setting
    IF    not ${found}
        Log    Recipient ${expected_cc_email} NOT found in CC field
        IF    ${fail_on_error}
            Fail    CC recipient ${expected_cc_email} not found in email
        END
    END

    # Return the result (True/False)
    RETURN    ${found}

Verify Email BCC Recipient
    [Documentation]    Verify that email has the expected recipient in BCC field
    ...    By default, fails if not found (fail_on_error=${True})
    ...    Set fail_on_error=${False} to return True/False instead
    [Arguments]    ${expected_bcc_email}    ${fail_on_error}=${True}    ${maildev_url}=${DEFAULT_MAILDEV_URL}

    # Get the latest email from MailDev
    ${email}=    Get And Validate Latest Email    ${maildev_url}

    # Check if BCC field exists
    ${has_bcc}=    Run Keyword And Return Status
    ...    Dictionary Should Contain Key    ${email}    bcc

    # Initialize found flag
    ${found}=    Set Variable    ${False}

    # Check BCC field for the recipient if it exists
    IF    ${has_bcc}
        FOR    ${bcc}    IN    @{email}[bcc]
            IF    '${bcc}[address]' == '${expected_bcc_email}'
                Log    Recipient ${expected_bcc_email} found in BCC field
                ${found}=    Set Variable    ${True}
                BREAK
            END
        END
    ELSE
        Log    Email has no BCC recipients
    END

    # Handle result based on fail_on_error setting
    IF    not ${found}
        Log    Recipient ${expected_bcc_email} NOT found in BCC field
        IF    ${fail_on_error}
            Fail    BCC recipient ${expected_bcc_email} not found in email
        END
    END

    # Return the result (True/False)
    RETURN    ${found}

Generate Test Email Data
    [Documentation]    Generate test email data with unique identifiers
    [Arguments]    ${prefix}=Test

    ${timestamp}=    Get Current Date    result_format=%Y%m%d_%H%M%S
    ${unique_id}=    Generate Random String    8    [LETTERS][NUMBERS]

    ${email_data}=    Create Dictionary
    ...    from=test-sender-${unique_id}@example.com
    ...    to=test-recipient-${unique_id}@example.com
    ...    subject=${prefix} Email ${timestamp}
    ...    body=This is a test email generated at ${timestamp} with ID ${unique_id}
    ...    unique_id=${unique_id}
    ...    timestamp=${timestamp}

    RETURN    ${email_data}

Create HTML Email Body
    [Documentation]    Create formatted HTML email body
    [Arguments]    ${title}    ${content}    ${footer}=${None}

    ${html}=    Catenate    SEPARATOR=\n
    ...    <!DOCTYPE html>
    ...    <html>
    ...    <head>
    ...    <style>
    ...    body { font-family: Arial, sans-serif; }
    ...    .container { max-width: 600px; margin: 0 auto; padding: 20px; }
    ...    h1 { color: #333; }
    ...    .content { margin: 20px 0; }
    ...    .footer { margin-top: 30px; padding-top: 20px; border-top: 1px solid #ddd; color: #666; font-size: 12px; }
    ...    </style>
    ...    </head>
    ...    <body>
    ...    <div class="container">
    ...    <h1>${title}</h1>
    ...    <div class="content">
    ...    ${content}
    ...    </div>

    IF    '${footer}' != '${None}'
        Set Variable    ${html}    ${html}\n    <div class="footer">${footer}</div>
    END

    ${html}=    Catenate    SEPARATOR=\n
    ...    ${html}
    ...    </div>
    ...    </body>
    ...    </html>

    RETURN    ${html}

Get And Validate Latest Email
    [Documentation]    Get emails from MailDev and return the latest one
    [Arguments]    ${maildev_url}=${DEFAULT_MAILDEV_URL}

    # Get emails from MailDev
    ${response}=    GET    ${maildev_url}/email    expected_status=200
    Should Be Equal As Numbers    ${response.status_code}    200
    ${emails}=    Set Variable    ${response.json()}

    # Verify email was received
    Should Not Be Empty    ${emails}    No emails found in MailDev
    ${latest_email}=    Set Variable    ${emails}[0]

    RETURN    ${latest_email}

Verify Email Subject
    [Documentation]    Verify email subject matches expected value
    [Arguments]    ${expected_subject}    ${maildev_url}=${DEFAULT_MAILDEV_URL}

    # Get the latest email from MailDev
    ${email}=    Get And Validate Latest Email    ${maildev_url}

    Log    Actual Email Subject is: ${email}[subject]    console=yes
    Log    expected Email Subject is: ${expected_subject}    console=yes

    Should Be Equal    ${email}[subject]    ${expected_subject}
    ...    Email subject mismatch. Expected: ${expected_subject}, Got: ${email}[subject]

    Log    Email subject verified: ${expected_subject}

Verify Email Body Contains
    [Documentation]    Verify email body contains expected text
    [Arguments]    ${expected_text}    ${maildev_url}=${DEFAULT_MAILDEV_URL}

    # Get the latest email from MailDev
    ${email}=    Get And Validate Latest Email    ${maildev_url}

    # Check if email has text body
    ${has_text}=    Run Keyword And Return Status
    ...    Dictionary Should Contain Key    ${email}    text

    IF    ${has_text}
        Should Contain    ${email}[text]    ${expected_text}
        ...    Email body doesn't contain expected text: ${expected_text}
    ELSE
        # Fall back to HTML body if no text body
        Should Contain    ${email}[html]    ${expected_text}
        ...    Email HTML body doesn't contain expected text: ${expected_text}
    END

    Log    Email body verification passed

Verify Email Body Equals
    [Documentation]    Verify email body exactly matches expected text
    [Arguments]    ${expected_body}    ${maildev_url}=${DEFAULT_MAILDEV_URL}

    # Get the latest email from MailDev
    ${email}=    Get And Validate Latest Email    ${maildev_url}

    # Extract body directly from the email object
    ${has_text}=    Run Keyword And Return Status
    ...    Dictionary Should Contain Key    ${email}    text

    IF    ${has_text}
        ${actual_body}=    Set Variable    ${email}[text]
    ELSE
        # Fall back to HTML if no text
        ${has_html}=    Run Keyword And Return Status
        ...    Dictionary Should Contain Key    ${email}    html
        IF    ${has_html}
            ${actual_body}=    Set Variable    ${email}[html]
        ELSE
            ${actual_body}=    Set Variable    ${EMPTY}
        END
    END

    Should Be Equal    ${actual_body}    ${expected_body}
    ...    Email body mismatch. Expected: ${expected_body}, Got: ${actual_body}

    Log    Email body exact match verified

Get Email Body As Text
    [Documentation]    Extract plain text body from latest email in MailDev
    [Arguments]    ${maildev_url}=${DEFAULT_MAILDEV_URL}

    # Get the latest email from MailDev
    ${email}=    Get And Validate Latest Email    ${maildev_url}

    ${has_text}=    Run Keyword And Return Status
    ...    Dictionary Should Contain Key    ${email}    text

    IF    ${has_text}    RETURN    ${email}[text]

    # If no text body, try to extract from HTML
    ${has_html}=    Run Keyword And Return Status
    ...    Dictionary Should Contain Key    ${email}    html

    IF    ${has_html}    RETURN    ${email}[html]

    RETURN    ${EMPTY}

Get Email Body As HTML
    [Documentation]    Extract HTML body from email
    [Arguments]    ${maildev_url}=${DEFAULT_MAILDEV_URL}

    # Get the latest email from MailDev
    ${email}=    Get And Validate Latest Email    ${maildev_url}

    ${has_html}=    Run Keyword And Return Status
    ...    Dictionary Should Contain Key    ${email}    html

    IF    ${has_html}    RETURN    ${email}[html]

    RETURN    ${EMPTY}
