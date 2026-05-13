*** Settings ***
Documentation       Create Account
...                 This test case demonstrates how to create an account in the project space using a payload file. It retrieves necessary values from environment files and uses a template for account creation.
...                 How to run this test case? : Navigate to {{cookiecutter.primary_pipeline_name}}    folder and run
...                 make robot-run-test-no-gp TAGS="create_account_sample"

Resource            snaplogic_common_robot/snaplogic_apis_keywords/snaplogic_keywords.resource    # SnapLogic API keywords from installed package


*** Test Cases ***
Create Account
    [Documentation]    Creates accounts in the project space using the provided payload files.
    ...    ACCOUNT_LOCATION_PATH comes from the root ".env" file.
    ...    Each <DB>_ACCOUNT_PAYLOAD_FILE_NAME and <DB>_ACCOUNT_NAME come from the matching
    ...    env_files/database_accounts/.env.<db> file (e.g. .env.sqlserver, .env.oracle, .env.postgres,
    ...    .env.mysql, .env.db2, .env.teradata).
    [Tags]    create_account_sample
    [Template]    Create Account From Template

    # SQL Server — hardcoded paths/names (demonstrates the literal form)
    test10_project_space/shared    acc_sqlserver.json    sqlserveracct3
    test10_project_space/shared    acc_sqlserver.json    sqlserveracct4    overwrite_if_exists=${TRUE}

    # SQL Server — env-driven form (preferred pattern)
    ${ACCOUNT_LOCATION_PATH}    ${SQLSERVER_ACCOUNT_PAYLOAD_FILE_NAME}    ${SQLSERVER_ACCOUNT_NAME}

    # Other databases — env-driven, overwrite-if-exists
    ${ACCOUNT_LOCATION_PATH}    ${ORACLE_ACCOUNT_PAYLOAD_FILE_NAME}    ${ORACLE_ACCOUNT_NAME}    overwrite_if_exists=${TRUE}
    ${ACCOUNT_LOCATION_PATH}    ${POSTGRES_ACCOUNT_PAYLOAD_FILE_NAME}    ${POSTGRES_ACCOUNT_NAME}    overwrite_if_exists=${TRUE}
    ${ACCOUNT_LOCATION_PATH}    ${MYSQL_ACCOUNT_PAYLOAD_FILE_NAME}    ${MYSQL_ACCOUNT_NAME}    overwrite_if_exists=${TRUE}
    ${ACCOUNT_LOCATION_PATH}    ${DB2_ACCOUNT_PAYLOAD_FILE_NAME}    ${DB2_ACCOUNT_NAME}    overwrite_if_exists=${TRUE}
    # ${ACCOUNT_LOCATION_PATH}    ${TERADATA_ACCOUNT_PAYLOAD_FILE_NAME}    ${TERADATA_ACCOUNT_NAME}    overwrite_if_exists=${TRUE}
