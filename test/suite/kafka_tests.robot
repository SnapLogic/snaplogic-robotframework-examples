*** Settings ***
Library    ../resources/kafka/kafka_library.py
Library    Collections
Library    BuiltIn

*** Variables ***
# Local Docker Kafka
${LOCAL_BOOTSTRAP_SERVERS}      kafka:29092
${LOCAL_SECURITY_PROTOCOL}      PLAINTEXT

# Dev Cluster (no auth)
${DEV_BOOTSTRAP_SERVERS}        ckafka01.nia.snaplogic.com:9092,ckafka02.nia.snaplogic.com:9092,ckafka03.nia.snaplogic.com:9092
${DEV_SECURITY_PROTOCOL}        PLAINTEXT

# Dev Cluster (with SASL)
${DEV_SASL_BOOTSTRAP_SERVERS}   ckafka01.nia.snaplogic.com:9091,ckafka02.nia.snaplogic.com:9091,ckafka03.nia.snaplogic.com:9091
${DEV_SASL_PROTOCOL}            SASL_SSL
${DEV_SASL_MECHANISM}           PLAIN
${DEV_SASL_USERNAME}            admin
${DEV_SASL_PASSWORD}            admin-secret

# Test topic configuration
${TEST_TOPIC_PREFIX}             robot-test
${NUM_PARTITIONS}                3
${REPLICATION_FACTOR}            1

*** Test Cases ***
Test Kafka Setup With Local Docker
    [Documentation]    Test Kafka operations with local Docker instance
    [Tags]    kafka    local
    
    # Connect to local Kafka
    Connect To Kafka    bootstrap_servers=${LOCAL_BOOTSTRAP_SERVERS}
    ...                security_protocol=${LOCAL_SECURITY_PROTOCOL}
    
    # Create test topic
    ${topic_name}=    Set Variable    ${TEST_TOPIC_PREFIX}-${SUITE NAME}-${TEST NAME}
    Create Topic    ${topic_name}    num_partitions=${NUM_PARTITIONS}
    
    # Verify topic exists
    ${exists}=    Topic Exists    ${topic_name}
    Should Be True    ${exists}
    
    # Send test message
    ${message}=    Create Dictionary    
    ...    test_id=123
    ...    test_name=Robot Framework Test
    ...    timestamp=${EMPTY}
    Send Message    ${topic_name}    ${message}    key=test-key
    
    # Consume and verify message
    ${messages}=    Consume Messages    ${topic_name}    max_messages=1
    Length Should Be    ${messages}    1
    Should Be Equal    ${messages}[0][key]    test-key
    
    # Cleanup
    Delete Topic    ${topic_name}
    Cleanup

Test Kafka With Dev Cluster
    [Documentation]    Test Kafka operations with dev cluster
    [Tags]    kafka    dev
    
    # Connect to dev cluster
    Connect To Kafka    bootstrap_servers=${DEV_BOOTSTRAP_SERVERS}
    ...                security_protocol=${DEV_SECURITY_PROTOCOL}
    
    # Create unique topic for this test
    ${timestamp}=    Get Time    epoch
    ${topic_name}=    Set Variable    ${TEST_TOPIC_PREFIX}-${timestamp}
    Create Topic    ${topic_name}    num_partitions=2
    
    # List topics to verify
    ${topics}=    List Topics
    Should Contain    ${topics}    ${topic_name}
    
    # Test message flow
    FOR    ${i}    IN RANGE    5
        ${msg}=    Set Variable    Test message ${i}
        Send Message    ${topic_name}    ${msg}
    END
    
    # Verify messages received
    ${messages}=    Consume Messages    ${topic_name}    max_messages=5    timeout=10000
    Length Should Be    ${messages}    5
    
    # Cleanup
    Delete Topic    ${topic_name}
    Cleanup

Test Kafka SASL Authentication
    [Documentation]    Test Kafka with SASL authentication
    [Tags]    kafka    sasl    dev
    
    # Connect with SASL
    Connect To Kafka    bootstrap_servers=${DEV_SASL_BOOTSTRAP_SERVERS}
    ...                security_protocol=${DEV_SASL_PROTOCOL}
    ...                sasl_mechanism=${DEV_SASL_MECHANISM}
    ...                sasl_username=${DEV_SASL_USERNAME}
    ...                sasl_password=${DEV_SASL_PASSWORD}
    
    # Quick connectivity test
    ${topics}=    List Topics
    Log    Available topics: ${topics}
    
    Cleanup

Setup Kafka Topics For Pipeline Test
    [Documentation]    Create topics needed for SnapLogic pipeline testing
    [Tags]    kafka    setup
    
    Connect To Kafka    bootstrap_servers=${LOCAL_BOOTSTRAP_SERVERS}
    
    # Create topics for pipeline test
    @{topics}=    Create List
    ...    snaplogic-input
    ...    snaplogic-output
    ...    snaplogic-error
    ...    snaplogic-events
    
    FOR    ${topic}    IN    @{topics}
        Create Topic    ${topic}    num_partitions=3    replication_factor=1
        Log    Created topic: ${topic}
    END
    
    # Verify all topics created
    ${all_topics}=    List Topics
    FOR    ${topic}    IN    @{topics}
        Should Contain    ${all_topics}    ${topic}
    END
    
    Cleanup

*** Keywords ***
Setup Test Environment
    [Documentation]    Common setup for Kafka tests
    Connect To Kafka    bootstrap_servers=${LOCAL_BOOTSTRAP_SERVERS}

Teardown Test Environment  
    [Documentation]    Common teardown for Kafka tests
    Cleanup
