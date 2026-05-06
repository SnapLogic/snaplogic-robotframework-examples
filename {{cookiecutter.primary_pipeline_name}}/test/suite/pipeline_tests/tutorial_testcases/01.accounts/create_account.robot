*** Settings ***
Documentation       Create Account
...                 This test case demonstrates how to create an account in the project space using a payload file. It retrieves necessary values from environment files and uses a template for account creation.
...                 How to run this test case? : Navigate to {{cookiecutter.primary_pipeline_name}}    folder and run
...                 make robot-run-test-no-gp TAGS="create_account_sample"

Resource            snaplogic_common_robot/snaplogic_apis_keywords/snaplogic_keywords.resource    # SnapLogic API keywords from installed package


*** Test Cases ***
Create Account
    [Documentation]    Creates an account in the project space using the provided payload file.
    ...    ACCOUNT_LOCATION_PATH = Get it from ---".env file"
    ...    SQLSERVER_ACCOUNT_PAYLOAD_FILE_NAME= Get the value from--- ".env.sqlserver" file
    ...    SQLSERVER_ACCOUNT_NAME= Get the value from--- ".env.sqlserver" file"
    [Tags]    create_account_sample
    [Template]    Create Account From Template

    test10_project_space/shared    acc_sqlserver.json    sqlserveracct3
    test10_project_space/shared    acc_sqlserver.json    sqlserveracct4    overwrite_if_exists=${TRUE}
    ${ACCOUNT_LOCATION_PATH}    ${SQLSERVER_ACCOUNT_PAYLOAD_FILE_NAME}    ${SQLSERVER_ACCOUNT_NAME}
