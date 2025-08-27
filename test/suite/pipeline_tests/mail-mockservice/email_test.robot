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
Resource            snaplogic_common_robot/snaplogic_apis_keywords/snaplogic_keywords.resource
Resource            ../../../resources/files.resource
Resource            ../../../resources/email_utils.resource

Suite Setup         Initialize Variables


*** Variables ***
${DEFAULT_MAILDEV_URL}      http://maildev-test:1080
${DEFAULT_SMTP_PORT}        1025
${EMAIL_WAIT_TIMEOUT}       30s
${EMAIL_POLL_INTERVAL}      1s

${MAILDEV_URL}              http://maildev-test:1080
${SMTP_HOST}                localhost
${SMTP_PORT}                1025
${TEST_FROM_EMAIL}          test-sender@example.com
${TEST_TO_EMAIL}            test-recipient@example.com
${TEST_CC_EMAIL}            test-cc@example.com
${SUBJECT}                  Test Email Subject
${TEMPLATE_BODY}            Hello, this is a test email
# Project Configuration
${project_path}             ${org_name}/${project_space}/${project_name}
${pipeline_file_path}       ${CURDIR}/../../../../src/pipelines

${ACCOUNT_PAYLOAD_FILE}     acc_email.json
${pipeline_name}            email_notification
${pipeline_name_slp}        email.slp
${task1}                    mail_task

@{notification_states}      Completed    Failed
&{task_notifications}
...                         recipients=newemail@gmail.com
...                         states=${notification_states}

&{task_params_set1}
...                         EMAIL_ACCT=../shared/mail_acct
...                         TEST_FROM_EMAIL=test-sender@example.com
...                         TEST_TO_EMAIL=test-recipient@example.com
...                         TEST_CC_EMAIL=test-cc@example.com
...                         SUBJECT=Test Email Subject
...                         TEMPLATE_BODY=Hello, this is a test email


*** Test Cases ***
Create Account
    [Documentation]    Creates an account in the project space using the provided payload file.
    ...    "account_payload_path"    value as assigned to global variable    in __init__.robot file
    [Tags]    email2
    [Template]    Create Account From Template
    ${account_payload_path}/${ACCOUNT_PAYLOAD_FILE}

Import Pipelines
    [Documentation]    Imports the Email notitificarion Pipeline
    ...    Returns:
    ...    unique_id --> which is used until executing the tasks
    ...    pipeline_snodeid --> which is used to create the tasks
    [Tags]    email2
    [Template]    Import Pipelines From Template
    ${unique_id}    ${pipeline_file_path}    ${pipeline_name}    ${pipeline_name_slp}

Create Triggered_task
    [Documentation]    Creates triggered task and returns the task name and task snode id
    ...    which is used to execute the task.
    ...    Prereq: Need unique_id,pipeline_snodeid (from Import Pipelines)
    ...    Returns:
    ...    task_payload --> which is used to update the task params
    ...    task_snodeid --> which is used to update the task params
    [Tags]    email2
    [Template]    Create Triggered Task From Template
    ${unique_id}    ${project_path}    ${pipeline_name}    ${task1}    ${task_params_set1}    ${task_notifications}

Execute Triggered Task With Parameters
    [Documentation]    Updates the task parameters and runs the task
    ...    Prereq: Need task_payload,task_snodeid (from Create Triggered_task)
    [Tags]    email2
    [Template]    Run Triggered Task With Parameters From Template
    ${unique_id}    ${project_path}    ${pipeline_name}    ${task1}    TEMPLATE_BODY=Hello, this is a test email

Verify Email Setup
    [Documentation]    Verifies that the email was sent and received correctly using MailDev.
    ...    Prereq: Ensure MailDev is running and accessible.
    [Tags]    email2

    # Get emails from MailDev and return the latest one
    Get And Validate Latest Email    ${MAILDEV_URL}
    Verify Email TO Recipient    ${TEST_TO_EMAIL}
    Verify Email CC Recipient    ${TEST_CC_EMAIL}
    Verify Email Subject    ${SUBJECT}
    Verify Email Body Equals    ${TEMPLATE_BODY}


*** Keywords ***
Initialize Variables
    ${unique_id}=    Get Unique Id
    Set Suite Variable    ${unique_id}    ${unique_id}
    Purge All Emails    ${MAILDEV_URL}

    # ${response}=    DELETE    ${MAILDEV_API_URL}/all
    # Log    \nMailDev Clear Response: ${response.status_code}    console=yes
    # Log    Response Body: ${response.content}    console=yes
    # Should Be Equal As Numbers    ${response.status_code}    200
