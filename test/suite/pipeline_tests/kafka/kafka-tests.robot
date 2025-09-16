*** Settings ***
Documentation       Advanced Kafka Message Testing Suite
...
...                 This suite demonstrates advanced Kafka capabilities including:
...                 • Sending and consuming JSON messages through Kafka topics
...                 • Testing message persistence and partitioning
...                 • Producer and consumer pipeline integration
...                 • Topic management and message validation
...                 • Integration with SnapLogic Kafka Consumer/Producer pipelines
...
...                 KEY FEATURES: Kafka provides distributed, fault-tolerant messaging
...                 with high throughput and horizontal scalability

Resource            snaplogic_common_robot/snaplogic_apis_keywords/snaplogic_keywords.resource
Resource            ../../../resources/files.resource
Resource            ../../../resources/kafka/kafka_keywords_library.resource
Library             KafkaLibrary
Library             OperatingSystem
Library             String
Library             Collections
Library             DateTime
Library             JSONLibrary

Suite Setup         Initialize Test Environment


*** Variables ***
${documents_json}                   ${CURDIR}/../../test_data/actual_expected_data/input_data/documents.json

# Kafka Configuration
${KAFKA_BROKER}                     kafka:29092
${KAFKA_TOPIC_PREFIX}               slim3
${KAFKA_TEST_TOPIC}                 slim3-events
${KAFKA_METRICS_TOPIC}              ${KAFKA_TOPIC_PREFIX}-metrics
${KAFKA_LOGS_TOPIC}                 ${KAFKA_TOPIC_PREFIX}-logs
${KAFKA_GROUP_ID}                   robot-test-group
${KAFKA_CLIENT_ID}                  robot-test-client

# Project Configuration
${project_path}                     ${org_name}/${project_space}/${project_name}
${pipeline_file_path}               /app/src/pipelines
${upload_destination_file_path}     ${org_name}/${project_space}/shared
${ACTUAL_DATA_DIR}                  ${CURDIR}/../../test_data/actual_expected_data/actual_output    # Base directory for downloaded files
${EXPECTED_OUTPUT_DIR}              ${CURDIR}/../../test_data/actual_expected_data/expected_output    # Expected output files for comparison

${ACCOUNT_PAYLOAD_FILE}             acc_kafka.json

# Kafka Pipeline Configuration
${pipeline_name}                    kafka_consumer
${pipeline_slp}                     kafka.slp

${task1}                            kafka_Task
@{notification_states}              Completed    Failed
&{task_notifications}
...                                 recipients=newemail@gmail.com
...                                 states=${notification_states}

&{task_params_set1}
...                                 kafka_acct=../shared/kafka_acct
...                                 topic=${KAFKA_TEST_TOPIC}
...                                 partition_number=1
...                                 botstrap_server=kafka:29092
...                                 message_key= Test_key
...                                 message_value= Test_value


*** Test Cases ***
Create Kafka Account
    [Documentation]    Creates a Kafka account in the project space using the provided payload file.
    ...    Configures connection to Kafka broker with required settings:
    ...    • Bootstrap servers configuration
    ...    • Security protocol settings
    ...    • Client ID configuration
    ...    "account_payload_path" value as assigned to global variable in __init__.robot file
    [Tags]    kafkaaccount    kafka3    regression
    [Template]    Create Account From Template
    ${account_payload_path}/${ACCOUNT_PAYLOAD_FILE}

Import Pipeline
    [Documentation]    Imports the file snowflake pipeline that demonstrates
    ...    reading from and writing to mounted file locations
    ...    📋 ASSERTIONS:
    ...    • Pipeline file (.slp) exists and is readable
    ...    • Pipeline import API call succeeds
    ...    • Unique pipeline ID is generated and returned
    ...    • Pipeline contains file reader and writer snaps configured for mounts
    ...    • Pipeline is successfully deployed to the project space
    [Tags]    kafka3
    [Template]    Import Pipelines From Template
    ${unique_id}    ${pipeline_file_path}    ${pipeline_name}    ${pipeline_slp}

Create Triggered_task
    [Documentation]    Creates triggered task and returns the task name and task snode id
    ...    which is used to execute the task.
    ...    Prereq: Need unique_id,pipeline_snodeid (from Import Pipelines)
    ...    Returns:
    ...    task_payload --> which is used to update the task params
    ...    task_snodeid --> which is used to update the task params
    [Tags]    kafka3    regression
    [Template]    Create Triggered Task From Template
    ${unique_id}    ${project_path}    ${pipeline_name}    ${task1}    ${task_params_set1}    ${task_notifications}

Execute Triggered Task With Parameters
    [Documentation]    Updates the task parameters and runs the task
    ...    Prereq: Need task_payload,task_snodeid (from Create Triggered_task)
    [Tags]    kafka3    regression
    [Template]    Run Triggered Task With Parameters From Template
    ${unique_id}    ${project_path}    ${pipeline_name}    ${task1}

Verify Pipeline Created Topic And Messages
    [Documentation]    Verifies that the SnapLogic pipeline successfully created Kafka topic and messages
    ...    This test validates:
    ...    • Topic ${KAFKA_TEST_TOPIC} exists (created by pipeline)
    ...    • Messages sent by the pipeline are present in the topic
    ...    • Message content matches expected format from pipeline
    [Tags]    kafka3    regression    verification

    # Call the keyword from kafka_keywords_library.resource
    ${results}=    Verify Pipeline Created Topic And Messages
    ...    ${KAFKA_TEST_TOPIC}
    ...    expected_key=Test_key
    ...    expected_value=Test_value
    ...    wait_time=5s

    # Log the results
    Log    Verification Results: ${results}    console=yes
    Should Be True    ${results}[topic_exists]    Topic verification failed
    Should Be True    ${results}[message_count] > 0    No messages found in topic

    # Additional logging for visibility
    Log    Topic ${KAFKA_TEST_TOPIC} verification completed successfully    console=yes


*** Keywords ***
Initialize Test Environment
    [Documentation]    Initialize Kafka test environment and connections
    ${unique_id}=    Get Unique Id
    Set Suite Variable    ${unique_id}    ${unique_id}
    Wait Until Plex Status Is Up    /${ORG_NAME}/${GROUNDPLEX_LOCATION_PATH}/${GROUNDPLEX_NAME}
    Connect To Kafka Broker    ${KAFKA_BROKER}
    Delete Kafka Topic    ${KAFKA_TEST_TOPIC}
