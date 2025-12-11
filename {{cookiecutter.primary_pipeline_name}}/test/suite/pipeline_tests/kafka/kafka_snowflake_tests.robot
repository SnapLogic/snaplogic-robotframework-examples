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
Resource            snaplogic_common_robot/snaplogic_apis_keywords/snaplogic_keywords.resource    # SnapLogic API keywords from installed package
Resource            ../../test_data/queries/oracle_queries.resource    # Oracle SQL queries
Resource            ../../../resources/common/files.resource    # CSV/JSON file operations

Suite Setup         Check connections    # Check if the connection to the Oracle database is successful and snaplex is up


*** Variables ***
# Project Configuration

# ${upload_source_file_path}    ${CURDIR}/../../test_data/actual_expected_data/expression_libraries
# ${container_source_file_path}    opt/snaplogic/test_data/actual_expected_data/expression_libraries

${expressions_library_path}         ${CURDIR}/../../test_data/actual_expected_data/input_data/kafka
${sf_acct1}                         snowflake_s3_databaseaccount
${sf_acct2}                         snowflake_s3_keypair_dynamic_databaseaccount

# Oracle_Pipeline and Task Configuration
# ${ACCOUNT_PAYLOAD_FILE}    acc_oracle.json

#### Pipeline Configuration #############
${pipeline_name}                    01.kafka_snowflake_parent_pl
${pipeline_file_name_slp}           parent_pipeline1.slp

#### Child Pipeline1 Configuration #############

${child_pipeline1_name}             02.kafka_snowflake_child_pipeline1
${child_pipeline1_file_name_slp}    child_pipeline1.slp

#### Child Pipeline2 Configuration #############

${child_pipeline2_name}             03.kafka_snowflake_child_pipeline2
${child_pipeline2_file_name_slp}    child_pipeline2.slp

#### Child Pipeline1 Configuration #############
${task_name}                        Kafka_Task

&{task_params_set1}
...                                 cross_account_role_arn=arn:aws:iam::801811267036:role/tapp102550Managed/global-npdataint-s3-tapp102550-role
...                                 cross_account_external_id=nptapp102550
...                                 ca_cert_path=801811267036-global-npdataint-ps-001-s3-bucket/tapp102550/cyberark_mfa_cert_and_key/APP_CC_GPS-Datalake_NP.crt
...                                 ca_cert_key_path=801811267036-global-npdataint-ps-001-s3-bucket/tapp102550/cyberark_mfa_cert_and_key/APP_CC_GPS-Datalake_NP.key
...                                 snf_rsa_private_key=${EMPTY}
...                                 snf_rsa_passphrase=${EMPTY}
...                                 msk_cross_account_iam=${EMPTY}
...                                 msk_cross_account_external_key=${EMPTY}
...                                 DDP_Email_Secret_ID=${EMPTY}
...                                 DDP_Email_Secret_Key=${EMPTY}


*** Test Cases ***
Create Account
    [Documentation]    Creates an account in the project space using the provided payload file.
    [Tags]    kafka_snowflake
    [Template]    Create Account From Template
    # ${ACCOUNT_LOCATION_PATH}    ${KAFKA_ACCOUNT_PAYLOAD_FILE_NAME}    ${KAFKA_ACCOUNT_NAME}
    ${ACCOUNT_LOCATION_PATH}    ${SNOWFLAKE_ACCOUNT_PAYLOAD_FILE_NAME}    ${sf_acct1}
    ${ACCOUNT_LOCATION_PATH}    ${SNOWFLAKE_ACCOUNT_PAYLOAD_KEY_PAIR_S3_DYNAMIC_FILE_NAME}    ${sf_acct2}

Upload Files With File Protocol
    [Documentation]    Upload files using file:/// protocol URLs - all options in template format
    [Tags]    kafka_snowflake
    [Template]    Upload File Using File Protocol Template

    # file path    destination_path
    ${expressions_library_path}/cyberarks_params.expr    ${PROJECT_PATH}
    ${expressions_library_path}/functions.expr    ${PROJECT_PATH}
    ${expressions_library_path}/account_params.expr    ${PROJECT_PATH}

Import Pipeline
    [Documentation]    Imports Snowflake pipeline files (.slp) into the SnapLogic project space.
    ...    This test case uploads pipeline definitions and deploys them to the specified location,
    ...    making them available for task creation and execution.
    ...
    ...    📋 PREREQUISITES:
    ...    • ${unique_id} - Generated from suite setup (Check connections keyword)
    ...    • Pipeline .slp files must exist in the test_data directory
    ...    • SnapLogic project and folder structure must be in place
    ...
    ...    📋 ARGUMENT DETAILS:
    ...    • Argument 1: ${unique_id} - Unique test execution identifier for naming/tracking
    ...    (Generated automatically in suite setup)
    ...    • Argument 2: ${PIPELINES_LOCATION_PATH} - SnapLogic folder path where pipelines will be imported
    ...    (e.g., /org/project/pipelines or /shared/pipelines)
    ...    • Argument 3: ${pipeline_name} - Logical name for the pipeline (without .slp extension)
    ...    (e.g., snowflake_pl1, data_processor, etl_pipeline)
    ...    • Argument 4: ${pipeline_file_name} - Physical .slp file name to import
    ...    (e.g., snowflake1.slp, pipeline.slp)
    ...
    ...    💡 TO IMPORT MULTIPLE PIPELINES:
    ...    You can import multiple pipeline files by adding more records to this template.
    ...    Each record represents one pipeline import operation.
    [Tags]    kafka_snowflake
    [Template]    Import Pipelines From Template

    ${unique_id}    ${PIPELINES_LOCATION_PATH}    ${pipeline_name}    ${pipeline_file_name_slp}
    ${unique_id}    ${PIPELINES_LOCATION_PATH}    ${child_pipeline1_name}    ${child_pipeline1_file_name_slp}
    ${unique_id}    ${PIPELINES_LOCATION_PATH}    ${child_pipeline2_name}    ${child_pipeline2_file_name_slp}

Create Triggered_task
    [Documentation]    Creates a triggered task for pipeline execution and returns task metadata.
    ...    Triggered tasks are scheduled or on-demand pipeline executions configured with
    ...    specific parameters and notification settings.
    ...
    ...    📋 PREREQUISITES:
    ...    • unique_id - Generated from Import Pipelines test case
    ...    • pipeline_snodeid - Created during pipeline import
    ...
    ...    📋 ARGUMENT DETAILS:
    ...    • Argument 1: ${unique_id} - Unique identifier for test execution (generated in suite setup)
    ...    • Argument 2: ${PIPELINES_LOCATION_PATH} - SnapLogic path where pipelines are stored
    ...    • Argument 3: ${pipeline_name} - Name of the pipeline to create task for
    ...    • Argument 4: ${task_name} - Name to assign to the triggered task
    ...    • Argument 5: ${GROUNDPLEX_NAME} - Name of the Snaplex where task will execute (optional- can be omitted)
    ...    • Argument 6: ${task_params_set} - Dictionary of parameters to pass to pipeline execution
    ...    (e.g., snowflake_acct, schema_name, table_name)-(optional- can be omitted)
    ...    • Argument 7: ${task_notifications} (Optional) - Dictionary containing notification settings
    ...    (recipients and states for task completion/failure alerts)-(optional- can be omitted)
    [Tags]    kafka_snowflake
    Set To Dictionary    ${task_params_set1}    child_pipeline1=${child_pipeline1_name}_${unique_id}
    Set To Dictionary    ${task_params_set1}    child_pipeline2=${child_pipeline2_name}_${unique_id}
    Create Triggered Task From Template
    ...    ${unique_id}
    ...    ${PIPELINES_LOCATION_PATH}
    ...    ${pipeline_name}
    ...    ${task_name}
    ...    ${GROUNDPLEX_NAME}
    ...    ${task_params_set1}


*** Keywords ***
Check connections
    [Documentation]    Verifies    Snaplex availability
    ${unique_id}=    Get Unique Id
    Set Suite Variable    ${unique_id}    ${unique_id}

    Log    🔧 Initializing test environment for file mount demonstration
    Log    📋 Test ID: ${unique_id}
