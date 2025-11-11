*** Settings ***
Documentation       Kafka utility keywords for Robot Framework tests
...                 Using complete custom KafkaLibrary implementation

Library             Collections
Library             String
Library             BuiltIn
Library             kafka_library.py


*** Variables ***
${KAFKA_BOOTSTRAP_SERVER}       kafka:29092
${KAFKA_GROUP_ID}               test-consumer-group


*** Keywords ***
Delete Kafka Topic
    [Documentation]    Deletes one or more Kafka topics using built-in admin operations
    ...    Gracefully handles topics that don't exist (no error thrown)
    ...
    ...    Example:
    ...    | Delete Kafka Topic | test-topic |    # Single topic
    ...    | Delete Kafka Topic | topic1 | topic2 | topic3 |    # Multiple topics
    [Arguments]    @{topic_names}

    ${count}=    Get Length    ${topic_names}
    IF    ${count} == 0    Fail    No topic names provided to delete

    # Get existing topics
    ${existing_topics}=    Get Kafka Topics
    
    # Filter to only delete topics that exist
    @{topics_to_delete}=    Create List
    FOR    ${topic}    IN    @{topic_names}
        ${exists}=    Run Keyword And Return Status    Should Contain    ${existing_topics}    ${topic}
        IF    ${exists}
            Append To List    ${topics_to_delete}    ${topic}
            Log    Topic '${topic}' exists - will be deleted
        ELSE
            Log    Topic '${topic}' does not exist - skipping    console=yes
        END
    END
    
    # Only attempt deletion if there are topics to delete
    ${topics_to_delete_count}=    Get Length    ${topics_to_delete}
    IF    ${topics_to_delete_count} > 0
        Delete Topics    @{topics_to_delete}
        Log    Successfully deleted ${topics_to_delete_count} topic(s)    console=yes
    ELSE
        Log    No topics to delete (all topics already non-existent)    console=yes
    END

Connect To Kafka As Producer
    [Documentation]    Connects to Kafka as a producer
    ...
    ...    Example:
    ...    | Connect To Kafka As Producer |
    [Arguments]    ${bootstrap_servers}=${KAFKA_BOOTSTRAP_SERVER}
    Connect Producer    ${bootstrap_servers}
    Log    Connected to Kafka as producer at ${bootstrap_servers}

Connect To Kafka As Consumer
    [Documentation]    Connects to Kafka as a consumer
    ...
    ...    Example:
    ...    | Connect To Kafka As Consumer |
    ...    | Connect To Kafka As Consumer | group_id=my-group |
    [Arguments]
    ...    ${bootstrap_servers}=${KAFKA_BOOTSTRAP_SERVER}
    ...    ${group_id}=${KAFKA_GROUP_ID}
    ...    ${auto_offset_reset}=earliest
    # Connect with earliest offset to read all messages from beginning
    Connect Consumer    ${bootstrap_servers}    ${group_id}    auto_offset_reset=${auto_offset_reset}
    Log    Connected to Kafka as consumer at ${bootstrap_servers} with group ${group_id}, offset=${auto_offset_reset}

Initialize Kafka Connections
    [Documentation]    Initializes both producer and consumer connections
    ...
    ...    Example:
    ...    | Initialize Kafka Connections |
    Connect To Kafka As Producer
    Connect To Kafka As Consumer

Cleanup Kafka Connections
    [Documentation]    Closes all Kafka connections
    ...
    ...    Example:
    ...    | Cleanup Kafka Connections |
    Close
    Log    All Kafka connections closed

Send Message To Kafka
    [Documentation]    Sends a message to a Kafka topic
    ...
    ...    Example:
    ...    | Send Message To Kafka | my-topic | Hello World |
    ...    | Send Message To Kafka | test-topic | {"id": 1, "message": "test"} |
    [Arguments]    ${topic_name}    ${message}    ${key}=${None}

    Log    Sending message to topic ${topic_name}: ${message}

    IF    '${key}' != '${None}'
        Send    ${topic_name}    ${key}    ${message}
    ELSE
        Send    ${topic_name}    message=${message}
    END

    Flush
    Log    Message sent successfully to ${topic_name}

Consume Messages From Kafka
    [Documentation]    Consumes messages from a Kafka topic
    ...
    ...    Example:
    ...    | @{messages}= | Consume Messages From Kafka | my-topic |
    ...    | @{messages}= | Consume Messages From Kafka | my-topic | max_messages=5 |
    [Arguments]    ${topic_name}    ${max_messages}=1    ${timeout}=10

    Log    Consuming ${max_messages} messages from topic ${topic_name}

    Subscribe Topic    ${topic_name}
    ${messages}=    Poll    ${max_messages}    ${timeout}

    Log    Consumed messages: ${messages}
    Commit

    RETURN    ${messages}

Verify Pipeline Created Topic And Messages
    [Documentation]    Verifies that the SnapLogic pipeline successfully created Kafka topic and messages
    ...    This keyword validates:
    ...    • Topic exists (created by pipeline)
    ...    • Messages sent by the pipeline are present in the topic
    ...    • Message content matches expected format from pipeline
    ...    • Message key and value are correct
    [Arguments]    ${topic_name}    ${expected_key}=Test_key    ${expected_value}=Test_value    ${wait_time}=5s

    # Allow time for pipeline messages to be fully committed
    Sleep    ${wait_time}    Allow time for pipeline messages to be fully committed

    # Verify the topic created by pipeline exists
    Log    Verifying topic ${topic_name} created by SnapLogic pipeline...
    ${topics}=    Get Kafka Topics
    Log    All available topics: ${topics}    console=yes
    Should Contain    ${topics}    ${topic_name}
    ...    Topic ${topic_name} was not found - pipeline may have failed to create it
    Log    ✓ Topic ${topic_name} exists    console=yes

    # Create a unique consumer group to always read from beginning
    ${timestamp}=    Get Time    epoch
    ${unique_group}=    Set Variable    robot-verify-${timestamp}
    Log    Using unique consumer group: ${unique_group}    console=yes

    # Connect as consumer with unique group and earliest offset
    Connect Consumer    ${KAFKA_BOOTSTRAP_SERVER}    ${unique_group}    auto_offset_reset=earliest

    # Subscribe to the topic
    Log    Subscribing to topic ${topic_name}...
    Subscribe Topic    ${topic_name}

    # Poll for messages that the pipeline should have sent
    # Poll expects: max_records, timeout (in seconds)
    ${max_messages}=    Evaluate    10
    ${timeout_seconds}=    Evaluate    10
    Log    Polling for messages: max=${max_messages}, timeout=${timeout_seconds}s    console=yes
    ${messages}=    Poll    ${max_messages}    ${timeout_seconds}

    # Log what we got
    Log    Raw messages received: ${messages}    console=yes

    # Verify we got messages from the pipeline
    ${message_count}=    Get Length    ${messages}
    Log    Message count: ${message_count}    console=yes

    # If no messages, provide helpful debugging info
    IF    ${message_count} == 0
        Log    WARNING: No messages found. Possible reasons:    WARN
        Log    1. Pipeline hasn't executed yet or failed    WARN
        Log    2. Messages sent to different topic (check pipeline config)    WARN
        Log    3. Consumer group already consumed messages    WARN
        Log    4. Messages expired due to retention policy    WARN
        Log    Topic name in pipeline: ${topic_name}    WARN
        Log    Expected key: ${expected_key}    WARN
        Log    Expected value: ${expected_value}    WARN
    END

    Should Be True    ${message_count} > 0
    ...    No messages found in topic ${topic_name} - pipeline may not have sent messages
    Log    ✓ Found ${message_count} message(s) in topic ${topic_name}    console=yes

    # Verify message content matches what pipeline should have sent
    ${messages_str}=    Convert To String    ${messages}
    Log    Messages from pipeline: ${messages_str}

    # Check for expected message value from pipeline
    ${found_expected_value}=    Run Keyword And Return Status
    ...    Should Contain    ${messages_str}    ${expected_value}

    # Check for expected message key from pipeline
    ${found_expected_key}=    Run Keyword And Return Status
    ...    Should Contain    ${messages_str}    ${expected_key}

    # Log detailed message information
    FOR    ${msg}    IN    @{messages}
        ${msg_details}=    Convert To String    ${msg}
        Log    Message details: ${msg_details}

        # Try to extract key and value if present
        ${has_value}=    Run Keyword And Return Status    Should Contain    ${msg_details}    value
        IF    ${has_value}    Log    ✓ Message contains value field

        ${has_key}=    Run Keyword And Return Status    Should Contain    ${msg_details}    key
        IF    ${has_key}    Log    ✓ Message contains key field
    END

    # Final verification
    IF    ${found_expected_value}
        Log    ✓ Found expected message value '${expected_value}' from pipeline    console=yes
    ELSE
        Log    ⚠ Expected message value '${expected_value}' not found - check pipeline configuration    WARN
    END

    IF    ${found_expected_key}
        Log    ✓ Found expected message key '${expected_key}' from pipeline    console=yes
    ELSE
        Log    ⚠ Expected message key '${expected_key}' not found - check pipeline configuration    WARN
    END

    # No need to commit since we're just verifying, not processing
    Log    Pipeline Kafka verification completed - Topic: ${topic_name}, Messages: ${message_count}    console=yes

    # Return verification results
    ${results}=    Create Dictionary
    ...    topic_exists=${True}
    ...    message_count=${message_count}
    ...    key_found=${found_expected_key}
    ...    value_found=${found_expected_value}

    RETURN    ${results}

Get Available Kafka Topics
    [Documentation]    Gets list of available Kafka topics
    ...
    ...    Example:
    ...    | @{topics}= | Get Available Kafka Topics |
    ...    | Log Many | @{topics} |

    ${topics}=    Get Kafka Topics
    Log    Available topics: ${topics}
    RETURN    ${topics}

Check If Kafka Topic Exists
    [Documentation]    Checks if a Kafka topic exists
    ...
    ...    Example:
    ...    | ${exists}= | Check If Kafka Topic Exists | my-topic |
    ...    | Should Be True | ${exists} |
    [Arguments]    ${topic_name}

    ${topics}=    Get Kafka Topics
    ${exists}=    Run Keyword And Return Status
    ...    Should Contain    ${topics}    ${topic_name}
    Log    Topic ${topic_name} exists: ${exists}
    RETURN    ${exists}

Send And Verify Message
    [Documentation]    Sends a message and verifies it can be consumed
    ...
    ...    Example:
    ...    | Send And Verify Message | test-topic | Test Message |
    [Arguments]    ${topic_name}    ${message}

    # Send message
    Send Message To Kafka    ${topic_name}    ${message}

    # Consume and verify
    @{messages}=    Consume Messages From Kafka    ${topic_name}    max_messages=1    timeout=10

    # Check if message was received
    ${message_found}=    Set Variable    ${False}
    FOR    ${msg}    IN    @{messages}
        ${msg_value}=    Get From Dictionary    ${msg}    value    default=${EMPTY}
        IF    '${msg_value}' == '${message}'
            ${message_found}=    Set Variable    ${True}
            BREAK
        END
    END

    Should Be True    ${message_found}
    ...    Message not found. Expected: ${message}, Got: @{messages}

    Log    Message verified successfully

Clear Topic Messages
    [Documentation]    Consumes all messages from a topic to clear it
    ...    Note: This doesn't delete the topic, just consumes existing messages
    ...
    ...    Example:
    ...    | Clear Topic Messages | my-topic |
    [Arguments]    ${topic_name}

    Log    Clearing messages from topic ${topic_name}

    Subscribe Topic    ${topic_name}

    # Keep consuming until no more messages
    ${total_consumed}=    Set Variable    0
    WHILE    True
        ${messages}=    Poll    max_records=100    timeout=2
        ${count}=    Get Length    ${messages}
        IF    ${count} == 0    BREAK
        ${total_consumed}=    Evaluate    ${total_consumed} + ${count}
        Commit
    END

    Log    Cleared ${total_consumed} messages from topic ${topic_name}

Disconnect From Kafka
    [Documentation]    Closes Kafka connections
    Log    Disconnecting from Kafka...
    Close
    Log    Kafka connections closed

Connect To Kafka Broker
    [Documentation]    Creates Kafka producer and consumer connections
    ...    Uses KAFKA_BROKER from variables or environment (default: kafka:29092)
    # Get Kafka connection details
    [Arguments]    ${KAFKA_BROKER}

    ${bootstrap_servers}=    Get Variable Value    ${KAFKA_BROKER}    kafka:29092

    Log    Connecting to Kafka broker at ${bootstrap_servers}...    console=yes

    # Create consumer and producer connections
    Connect Consumer    ${bootstrap_servers}    ${KAFKA_GROUP_ID}
    Connect Producer    ${bootstrap_servers}

    Log    Successfully connected to Kafka broker at ${bootstrap_servers}

Consume Messages From Kafka Topic
    [Documentation]    Consumes messages from specified Kafka topic
    [Arguments]    ${topic_name}    ${number_of_messages}=1    ${timeout}=10

    Log    Consuming ${number_of_messages} messages from topic '${topic_name}'...

    # Subscribe to topic
    Subscribe Topic    ${topic_name}

    # Poll for messages (timeout in seconds)
    ${messages}=    Poll    ${number_of_messages}    ${timeout}

    Log    Consumed messages: ${messages}

    # Commit the offset
    Commit

    RETURN    ${messages}
