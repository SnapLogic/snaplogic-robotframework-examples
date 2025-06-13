*** Settings ***
Documentation       Additional JMS/ActiveMQ queue management keywords

Library             jms/robot_stomp_wrapper.py    host=${JMS_HOST}    port=${JMS_PORT}    username=${JMS_USERNAME}    password=${JMS_PASSWORD}    enable_enhanced_features=${JMS_ENHANCED_FEATURES}
Library             String
Library             Collections
Library             DateTime


*** Variables ***
${JMS_HOST}                 activemq
${JMS_PORT}                 61613
${JMS_USERNAME}             admin
${JMS_PASSWORD}             admin
${JMS_ENHANCED_FEATURES}    True


*** Keywords ***
Set Timeout
    [Documentation]    Set global timeout for receive message
    ...
    ...    Arguments
    ...    timeout
    ...
    ...    Arguments Description
    ...    timeout    Timeout value in milliseconds
    [Arguments]    ${timeout}

    Log    Setting global timeout for receive message: ${timeout} milliseconds

    TRY
        # Store the timeout as a suite variable for use by receive operations
        Set Suite Variable    ${GLOBAL_RECEIVE_TIMEOUT}    ${timeout}

        Log    Successfully set global receive timeout to ${timeout} milliseconds
    EXCEPT    AS    ${error}
        Log    Failed to set timeout: ${error}    ERROR
        Fail    Could not set global timeout: ${timeout}
    END

Start Connection
    [Documentation]    Start connection to JMS server. If connection is already started, nothing happens

    Log    Starting connection to JMS server

    TRY
        # Check if connection already exists
        ${connection_exists}=    Run Keyword And Return Status    Variable Should Exist    ${JMS_CONNECTION_ACTIVE}

        IF    ${connection_exists}
            Log    Connection already active, nothing to do
        ELSE
            # Create new connection
            Connect To Artemis
            Set Suite Variable    ${JMS_CONNECTION_ACTIVE}    True
            Log    Successfully started connection to JMS server at ${JMS_HOST}:${JMS_PORT}
        END
    EXCEPT    AS    ${error}
        Log    Failed to start connection: ${error}    ERROR
        Fail    Could not start connection to JMS server
    END

Stop Connection
    [Documentation]    Stop connection to JMS server.

    Log    Stopping connection to JMS server

    TRY
        # Disconnect from Artemis
        Disconnect From Artemis

        # Clear connection status
        Set Suite Variable    ${JMS_CONNECTION_ACTIVE}    False

        Log    Successfully stopped connection to JMS server
    EXCEPT    AS    ${error}
        Log    Warning during connection stop: ${error}    WARN
        # Continue with cleanup even if disconnect fails
        Set Suite Variable    ${JMS_CONNECTION_ACTIVE}    False
    END

    Log    Connection stopped

Send Message To Queue
    [Documentation]    Send message to queue.
    ...
    ...    Arguments
    ...    queue
    ...    message
    ...
    ...    Arguments Description
    ...    queue    Queue to send message to
    ...    message    Text of the message or message object
    ...
    ...    Example:
    ...    Send Message To Queue    MyQueue    Hello World
    ...    ${message}=    Create Message    Hello There
    ...    Send Message To Queue    MyQueue    ${message}
    [Arguments]    ${queue}    ${message}

    Log    Sending message to queue: ${queue}

    TRY
        # Create queue destination
        ${dest}=    Create Queue Destination    ${queue}    ${queue}

        # Generate unique message ID
        ${timestamp}=    Get Current Date    result_format=epoch
        ${msg_id}=    Set Variable    msg-queue-${timestamp}

        # Send the message to the queue
        Send Text Message    ${dest}    ${message}    ${msg_id}

        Log    Successfully sent message to queue ${queue}: ${message}    level=Console
    EXCEPT    AS    ${error}
        Log    Failed to send message to queue ${queue}: ${error}    ERROR
        Fail    Could not send message to queue: ${queue}
    END

Send Message To Producer
    [Documentation]    Send message to producer.
    ...
    ...    Arguments
    ...    producer
    ...    message
    ...
    ...    Arguments Description
    ...    producer    Producer to send message to
    ...    message    Text of the message or message object
    ...
    ...    Example:
    ...    ${producer}=    Create Producer    MyQueue
    ...    Send Message To Producer    ${producer}    Hello World
    [Arguments]    ${producer}    ${message}

    Log    Sending message to specific producer: ${producer}

    TRY
        # Generate unique message ID
        ${timestamp}=    Get Current Date    result_format=epoch
        ${msg_id}=    Set Variable    msg-producer-${timestamp}

        # Send the message using the specific producer (destination)
        Send Text Message    ${producer}    ${message}    ${msg_id}

        Log    Successfully sent message to producer ${producer}: ${message}
    EXCEPT    AS    ${error}
        Log    Failed to send message to producer ${producer}: ${error}    ERROR
        Fail    Could not send message to producer: ${producer}
    END

Send Message
    [Documentation]    Send message to default producer. If message is passed, it will be sent. Otherwise, message from Create Message will be sent.
    ...
    ...    Arguments
    ...    message
    ...
    ...    Arguments Description
    ...    message    Text of the message or message object
    ...
    ...    Example:
    ...    Create Message    Hello World
    ...    Create Producer    MyQueue
    ...    Send Message
    ...    Receive Message From Queue    MyQueue    Hello World
    ...    ${message}=    Create Message    Hello There
    ...    Send Message    ${message}
    ...    Receive Message From Queue    MyQueue    Hello There
    ...    Send Message    Hello Again
    ...    Receive Message From Queue    MyQueue    Hello Again
    [Arguments]    ${message}=None

    Log    Sending message using default producer

    TRY
        # Determine which message to send
        IF    '${message}' != 'None'
            ${message_to_send}=    Set Variable    ${message}
            Log    Using provided message: ${message_to_send}
        ELSE
            Variable Should Exist
            ...    ${ACTIVE_MESSAGE}
            ...    msg=No message provided and no default message found. Use 'Create Message' first or provide message parameter.
            ${message_to_send}=    Set Variable    ${ACTIVE_MESSAGE}
            Log    Using default message: ${message_to_send}
        END

        # Check for active producer
        Variable Should Exist    ${ACTIVE_PRODUCER_DEST}    msg=No active producer found. Use 'Create Producer' first.
        Variable Should Exist
        ...    ${ACTIVE_PRODUCER_QUEUE}
        ...    msg=No active producer queue found. Use 'Create Producer' first.

        # Generate message ID if using active message
        IF    '${message}' == 'None' and '${ACTIVE_MESSAGE_ID}' != '${EMPTY}'
            ${msg_id}=    Set Variable    ${ACTIVE_MESSAGE_ID}
        ELSE
            ${timestamp}=    Get Current Date    result_format=epoch
            ${msg_id}=    Set Variable    msg-send-${timestamp}
        END

        # Send the message
        Send Text Message    ${ACTIVE_PRODUCER_DEST}    ${message_to_send}    ${msg_id}

        Log    Successfully sent message to queue ${ACTIVE_PRODUCER_QUEUE}: ${message_to_send}
    EXCEPT    AS    ${error}
        Log    Failed to send message: ${error}    ERROR
        Fail    Could not send message using default producer
    END

Send
    [Documentation]    Send message to default producer. If message is passed, it will be sent. Otherwise, message from Create Message will be sent.
    ...
    ...    Arguments
    ...    message
    ...
    ...    Arguments Description
    ...    message    Text of the message or message object
    ...
    ...    Example:
    ...    Create Message    Hello World
    ...    Create Producer    MyQueue
    ...    Send
    ...    Receive Message From Queue    MyQueue    Hello World
    ...    ${message}=    Create Message    Hello There
    ...    Send    ${message}
    ...    Receive Message From Queue    MyQueue    Hello There
    [Arguments]    ${message}=None

    Log    Sending message using default producer

    TRY
        # Determine which message to send
        IF    '${message}' != 'None'
            ${message_to_send}=    Set Variable    ${message}
            Log    Using provided message: ${message_to_send}
        ELSE
            Variable Should Exist
            ...    ${ACTIVE_MESSAGE}
            ...    msg=No message provided and no default message found. Use 'Create Message' first or provide message parameter.
            ${message_to_send}=    Set Variable    ${ACTIVE_MESSAGE}
            Log    Using default message: ${message_to_send}
        END

        # Check for active producer
        Variable Should Exist    ${ACTIVE_PRODUCER_DEST}    msg=No active producer found. Use 'Create Producer' first.
        Variable Should Exist
        ...    ${ACTIVE_PRODUCER_QUEUE}
        ...    msg=No active producer queue found. Use 'Create Producer' first.

        # Generate message ID if using active message
        IF    '${message}' == 'None' and '${ACTIVE_MESSAGE_ID}' != '${EMPTY}'
            ${msg_id}=    Set Variable    ${ACTIVE_MESSAGE_ID}
        ELSE
            ${timestamp}=    Get Current Date    result_format=epoch
            ${msg_id}=    Set Variable    msg-send-${timestamp}
        END

        # Send the message
        Send Text Message    ${ACTIVE_PRODUCER_DEST}    ${message_to_send}    ${msg_id}

        Log    Successfully sent message to queue ${ACTIVE_PRODUCER_QUEUE}: ${message_to_send}
    EXCEPT    AS    ${error}
        Log    Failed to send message: ${error}    ERROR
        Fail    Could not send message using default producer
    END

Receive Message From Queue
    [Documentation]    Receive message from queue and verify assertion.
    ...
    ...    Arguments
    ...    queue
    ...    assertion_operator
    ...    assertion_expected
    ...    message
    ...    timeout
    ...
    ...    Arguments Description
    ...    queue    Queue to receive message from
    ...    assertion_operator    See Assertions for further details. Defaults to None.
    ...    assertion_expected    Expected value for the state
    ...    message    overrides the default error message for assertion.
    ...    timeout    Timeout in milliseconds. Defaults to 2000.
    ...
    ...    Example:
    ...    Send Message To Queue    MyQueue    Hello World
    ...    Receive Message From Queue    MyQueue    Hello World
    [Arguments]
    ...    ${queue}
    ...    ${assertion_operator}=None
    ...    ${assertion_expected}=None
    ...    ${message}=None
    ...    ${timeout}=2000

    Log    Receiving message from queue: ${queue}

    TRY
        # Create consumer for the queue
        ${dest}=    Create Queue Destination    ${queue}    ${queue}
        ${consumer_id}=    Subscribe To Queue    ${dest}

        # Convert timeout to seconds
        ${timeout_seconds}=    Evaluate    ${timeout} / 1000.0

        # Receive message using the consumer
        ${received_count}=    Wait For Messages    1    ${timeout_seconds}

        IF    ${received_count} == 0
            # Clean up consumer before failing
            Unsubscribe From Queue    ${consumer_id}
            Fail    No message received from queue ${queue} within timeout of ${timeout} milliseconds
        END

        # Get the message text
        ${message_text}=    Get Text From Last Received Message

        # Clean up consumer
        Unsubscribe From Queue    ${consumer_id}

        # Perform assertion if specified
        IF    '${assertion_operator}' != 'None' and '${assertion_expected}' != 'None'
            IF    '${assertion_operator}' == '=='
                Should Be Equal    ${message_text}    ${assertion_expected}    ${message}
            END
            IF    '${assertion_operator}' == '!='
                Should Not Be Equal    ${message_text}    ${assertion_expected}    ${message}
            END
            IF    '${assertion_operator}' == 'contains'
                Should Contain    ${message_text}    ${assertion_expected}    ${message}
            END
            IF    '${assertion_operator}' == 'not contains'
                Should Not Contain    ${message_text}    ${assertion_expected}    ${message}
            END
        END

        Log    Successfully received message from queue ${queue}: ${message_text}
        RETURN    ${message_text}
    EXCEPT    AS    ${error}
        # Ensure cleanup on error
        Run Keyword And Ignore Error    Unsubscribe From Queue    ${consumer_id}
        Log    Failed to receive message from queue ${queue}: ${error}    ERROR
        Fail    Could not receive message from queue: ${queue}
    END

Receive Message From Consumer
    [Documentation]    Receive message from specific consumer and verify assertion.
    ...
    ...    Arguments
    ...    consumer
    ...    assertion_operator
    ...    assertion_expected
    ...    message
    ...    timeout
    ...
    ...    Arguments Description
    ...    consumer    Consumer to receive message from
    ...    assertion_operator    See Assertions for further details. Defaults to None.
    ...    assertion_expected    Expected value for the state
    ...    message    overrides the default error message for assertion.
    ...    timeout    Timeout in milliseconds. Defaults to 2000.
    [Arguments]
    ...    ${consumer}
    ...    ${assertion_operator}=None
    ...    ${assertion_expected}=None
    ...    ${message}=None
    ...    ${timeout}=2000

    Log    Receiving message from specific consumer: ${consumer}

    TRY
        # Convert timeout to seconds (Robot Framework uses seconds, JMS uses milliseconds)
        ${timeout_seconds}=    Evaluate    ${timeout} / 1000.0

        # Set the consumer as active for this operation
        Set Suite Variable    ${ACTIVE_CONSUMER_ID}    ${consumer}

        # Receive message using the specified consumer
        ${received_count}=    Wait For Messages    1    ${timeout_seconds}

        IF    ${received_count} == 0
            Fail    No message received from consumer ${consumer} within timeout of ${timeout} milliseconds
        END

        # Get the message text
        ${message_text}=    Get Text From Last Received Message

        # Perform assertion if specified
        IF    '${assertion_operator}' != 'None' and '${assertion_expected}' != 'None'
            IF    '${assertion_operator}' == '=='
                Should Be Equal    ${message_text}    ${assertion_expected}    ${message}
            END
            IF    '${assertion_operator}' == '!='
                Should Not Be Equal    ${message_text}    ${assertion_expected}    ${message}
            END
            IF    '${assertion_operator}' == 'contains'
                Should Contain    ${message_text}    ${assertion_expected}    ${message}
            END
            IF    '${assertion_operator}' == 'not contains'
                Should Not Contain    ${message_text}    ${assertion_expected}    ${message}
            END
        END

        Log    Successfully received message from consumer ${consumer}: ${message_text}
        RETURN    ${message_text}
    EXCEPT    AS    ${error}
        Log    Failed to receive message from consumer ${consumer}: ${error}    ERROR
        Fail    Could not receive message from consumer: ${consumer}
    END

Receive Message
    [Documentation]    Returns text of JMS message from consumer and verifies assertion.
    ...
    ...    Arguments
    ...    assertion_operator
    ...    assertion_expected
    ...    message
    ...    timeout
    ...    consumer
    ...
    ...    Arguments Description
    ...    assertion_operator    See Assertions for further details. Defaults to None.
    ...    assertion_expected    Expected value for the state
    ...    message    overrides the default error message for assertion.
    ...    timeout    Timeout in milliseconds. Defaults to 2000.
    ...    consumer    Consumer to receive message from. If not passed, a consumer needs to be created before using Create Consumer
    ...
    ...    Example:
    ...    Create Consumer    MyQueue
    ...    Send Message To Queue    MyQueue    Hello World
    ...    ${message}=    Receive Message    Hello World
    ...    Should Be Equal    ${message}    Hello World
    [Arguments]
    ...    ${assertion_operator}=None
    ...    ${assertion_expected}=None
    ...    ${message}=None
    ...    ${timeout}=2000
    ...    ${consumer}=None

    Log    Receiving message from consumer

    TRY
        # Use provided consumer or check for active consumer
        IF    '${consumer}' != 'None'
            ${consumer_id}=    Set Variable    ${consumer}
            Log    Using provided consumer: ${consumer_id}
        ELSE
            Variable Should Exist
            ...    ${ACTIVE_CONSUMER_ID}
            ...    msg=No active consumer found. Use 'Create Consumer' first or provide consumer parameter.
            ${consumer_id}=    Set Variable    ${ACTIVE_CONSUMER_ID}
            Log    Using active consumer: ${consumer_id}
        END

        # Convert timeout to seconds (Robot Framework uses seconds, JMS uses milliseconds)
        ${timeout_seconds}=    Evaluate    ${timeout} / 1000.0

        # Receive message using the consumer
        ${received_count}=    Wait For Messages    1    ${timeout_seconds}

        IF    ${received_count} == 0
            Fail    No message received within timeout of ${timeout} milliseconds
        END

        # Get the message text
        ${message_text}=    Get Text From Last Received Message

        # Perform assertion if specified
        IF    '${assertion_operator}' != 'None' and '${assertion_expected}' != 'None'
            IF    '${assertion_operator}' == '=='
                Should Be Equal    ${message_text}    ${assertion_expected}    ${message}
            END
            IF    '${assertion_operator}' == '!='
                Should Not Be Equal    ${message_text}    ${assertion_expected}    ${message}
            END
            IF    '${assertion_operator}' == 'contains'
                Should Contain    ${message_text}    ${assertion_expected}    ${message}
            END
            IF    '${assertion_operator}' == 'not contains'
                Should Not Contain    ${message_text}    ${assertion_expected}    ${message}
            END
        END

        Log    Successfully received message: ${message_text}
        RETURN    ${message_text}
    EXCEPT    AS    ${error}
        Log    Failed to receive message: ${error}    ERROR
        Fail    Could not receive message from consumer
    END

Receive All Messages From Queue
    [Documentation]    Receive all messages from queue and return them as list.
    ...
    ...    Arguments
    ...    queue
    ...    timeout
    ...
    ...    Arguments Description
    ...    queue    Queue to receive messages from
    ...    timeout    Timeout in milliseconds. Defaults to 2000.
    ...
    ...    Example:
    ...    Send Message To Queue    MyQueue    Hello World
    ...    Send Message To Queue    MyQueue    Hello Again
    ...    ${messages}=    Receive All Messages From Queue    MyQueue
    ...    Should Be Equal As Strings    ${messages}[0]    Hello World
    ...    Should Be Equal As Strings    ${messages}[1]    Hello Again
    [Arguments]    ${queue}    ${timeout}=2000

    Log    Receiving all messages from queue: ${queue}

    TRY
        # Create consumer for the queue
        ${dest}=    Create Queue Destination    ${queue}    ${queue}
        ${consumer_id}=    Subscribe To Queue    ${dest}

        # Convert timeout to seconds
        ${timeout_seconds}=    Evaluate    ${timeout} / 1000.0

        # Collect all messages
        ${all_messages}=    Create List
        ${total_received}=    Set Variable    0

        # Keep receiving messages until timeout or no more messages
        FOR    ${attempt}    IN RANGE    1    1001    # Max 1000 messages to prevent infinite loop
            TRY
                # Try to receive messages with progressively shorter timeout
                ${batch_timeout}=    Set Variable If    ${attempt} == 1    ${timeout_seconds}    0.5
                ${received_count}=    Consume Messages    ${batch_timeout}

                IF    ${received_count} == 0    BREAK

                # Get all consumed messages
                ${consumed_messages}=    Get All Consumed Messages

                # Extract text from each message and add to list
                FOR    ${msg}    IN    @{consumed_messages}
                    ${msg_text}=    Set Variable    ${msg}[body]
                    Append To List    ${all_messages}    ${msg_text}
                    ${total_received}=    Evaluate    ${total_received} + 1
                END

                # Clear consumed messages for next batch
                Clear Consumed Messages
            EXCEPT    AS    ${error}
                Log    Error receiving message batch: ${error}    WARN
                BREAK
            END
        END

        # Unsubscribe from the queue
        Unsubscribe From Queue    ${consumer_id}

        Log    Successfully received ${total_received} messages from queue: ${queue}
        RETURN    ${all_messages}
    EXCEPT    AS    ${error}
        Log    Failed to receive all messages from queue ${queue}: ${error}    ERROR
        Fail    Could not receive all messages from queue: ${queue}
    END

Receive
    [Documentation]    Returns text of JMS message from consumer and verifies assertion.
    ...
    ...    Arguments
    ...    assertion_operator
    ...    assertion_expected
    ...    message
    ...    timeout
    ...    consumer
    ...
    ...    Arguments Description
    ...    assertion_operator    See Assertions for further details. Defaults to None.
    ...    assertion_expected    Expected value for the state
    ...    message    overrides the default error message for assertion.
    ...    timeout    Timeout in milliseconds. Defaults to 2000.
    ...    consumer    Consumer to receive message from. If not passed, a consumer needs to be created before using Create Consumer
    ...
    ...    Example:
    ...    Create Consumer    MyQueue
    ...    Send Message To Queue    MyQueue    Hello World
    ...    ${message}=    Receive Message    Hello World
    ...    Should Be Equal    ${message}    Hello World
    [Arguments]
    ...    ${assertion_operator}=None
    ...    ${assertion_expected}=None
    ...    ${message}=None
    ...    ${timeout}=2000
    ...    ${consumer}=None

    Log    Receiving message from consumer

    TRY
        # Use provided consumer or check for active consumer
        IF    '${consumer}' != 'None'
            ${consumer_id}=    Set Variable    ${consumer}
            Log    Using provided consumer: ${consumer_id}
        ELSE
            Variable Should Exist
            ...    ${ACTIVE_CONSUMER_ID}
            ...    msg=No active consumer found. Use 'Create Consumer' first or provide consumer parameter.
            ${consumer_id}=    Set Variable    ${ACTIVE_CONSUMER_ID}
            Log    Using active consumer: ${consumer_id}
        END

        # Convert timeout to seconds (Robot Framework uses seconds, JMS uses milliseconds)
        ${timeout_seconds}=    Evaluate    ${timeout} / 1000.0

        # Receive message using the consumer
        ${received_count}=    Wait For Messages    1    ${timeout_seconds}

        IF    ${received_count} == 0
            Fail    No message received within timeout of ${timeout} milliseconds
        END

        # Get the message text
        ${message_text}=    Get Text From Last Received Message

        # Perform assertion if specified
        IF    '${assertion_operator}' != 'None' and '${assertion_expected}' != 'None'
            IF    '${assertion_operator}' == '=='
                Should Be Equal    ${message_text}    ${assertion_expected}    ${message}
            END
            IF    '${assertion_operator}' == '!='
                Should Not Be Equal    ${message_text}    ${assertion_expected}    ${message}
            END
            IF    '${assertion_operator}' == 'contains'
                Should Contain    ${message_text}    ${assertion_expected}    ${message}
            END
            IF    '${assertion_operator}' == 'not contains'
                Should Not Contain    ${message_text}    ${assertion_expected}    ${message}
            END
        END

        Log    Successfully received message: ${message_text}
        RETURN    ${message_text}
    EXCEPT    AS    ${error}
        Log    Failed to receive message: ${error}    ERROR
        Fail    Could not receive message from consumer
    END

Get Text From Message
    [Documentation]    Get text from jms_message and verify assertion.
    ...
    ...    Arguments
    ...    jms_message
    ...    assertion_operator
    ...    assertion_expected
    ...    message
    ...    timeout
    ...
    ...    Arguments Description
    ...    jms_message    JMS message to get text from
    ...    assertion_operator    See Assertions for further details. Defaults to None.
    ...    assertion_expected    Expected value for the state
    ...    message    overrides the default error message for assertion.
    ...    timeout    Timeout for the operation. Defaults to None.
    ...
    ...    Example:
    ...    Send Message To Queue    MyQueue    Hello World
    ...    ${message}=    Receive Message From Queue    MyQueue
    ...    Get Text From Message    ${message}    Hello World
    ...    ${text}=    Get Text From Message    ${message}
    ...    Should Be Equal    ${text}    Hello World
    [Arguments]
    ...    ${jms_message}
    ...    ${assertion_operator}=None
    ...    ${assertion_expected}=None
    ...    ${message}=None
    ...    ${timeout}=None

    Log    Getting text from JMS message

    TRY
        # Extract text from the JMS message object
        # In Robot Framework, we'll use the message body directly
        ${message_text}=    Set Variable    ${jms_message}

        # If jms_message is a dictionary/object, try to get the body/text field
        ${message_type}=    Evaluate    type($jms_message).__name__
        IF    '${message_type}' == 'dict'
            ${message_text}=    Get From Dictionary    ${jms_message}    body    ${jms_message}
        ELSE IF    '${message_type}' == 'str'
            ${message_text}=    Set Variable    ${jms_message}
        ELSE
            # Try to get text attribute from message object
            ${message_text}=    Get Variable Value    ${jms_message.body}    ${jms_message}
        END

        # Perform assertion if specified
        IF    '${assertion_operator}' != 'None' and '${assertion_expected}' != 'None'
            IF    '${assertion_operator}' == '=='
                Should Be Equal    ${message_text}    ${assertion_expected}    ${message}
            END
            IF    '${assertion_operator}' == '!='
                Should Not Be Equal    ${message_text}    ${assertion_expected}    ${message}
            END
            IF    '${assertion_operator}' == 'contains'
                Should Contain    ${message_text}    ${assertion_expected}    ${message}
            END
            IF    '${assertion_operator}' == 'not contains'
                Should Not Contain    ${message_text}    ${assertion_expected}    ${message}
            END
        END

        Log    Retrieved text from message: ${message_text}
        RETURN    ${message_text}
    EXCEPT    AS    ${error}
        Log    Failed to get text from JMS message: ${error}    ERROR
        Fail    Could not get text from JMS message
    END

Get Text From Last Received Message
    [Documentation]    Get text from last received message and verify assertion.
    ...
    ...    Arguments
    ...    assertion_operator
    ...    assertion_expected
    ...    message
    ...
    ...    Arguments Description
    ...    assertion_operator    See Assertions for further details. Defaults to None.
    ...    assertion_expected    Expected value for the state
    ...    message    overrides the default error message for assertion.
    ...
    ...    Example:
    ...    Send Message To Queue    MyQueue    Hello World
    ...    Receive Message From Queue    MyQueue    Hello World
    ...    Get Text From Last Received Message    ==    Hello World
    ...    ${text}=    Get Text From Last Received Message
    ...    Should Be Equal    ${text}    Hello World
    [Arguments]    ${assertion_operator}=None    ${assertion_expected}=None    ${message}=None

    Log    Getting text from last received message

    TRY
        # Check if there's an active consumer with received messages
        Variable Should Exist    ${ACTIVE_CONSUMER_ID}    msg=No active consumer found. Use 'Create Consumer' first.

        # Get the last consumed message text from the library - use the actual library method
        ${message_text}=    robot_stomp_wrapper.Get Text

        # Perform assertion if specified
        IF    '${assertion_operator}' != 'None' and '${assertion_expected}' != 'None'
            IF    '${assertion_operator}' == '=='
                Should Be Equal    ${message_text}    ${assertion_expected}    ${message}
            END
            IF    '${assertion_operator}' == '!='
                Should Not Be Equal    ${message_text}    ${assertion_expected}    ${message}
            END
            IF    '${assertion_operator}' == 'contains'
                Should Contain    ${message_text}    ${assertion_expected}    ${message}
            END
            IF    '${assertion_operator}' == 'not contains'
                Should Not Contain    ${message_text}    ${assertion_expected}    ${message}
            END
        END

        Log    Retrieved message text: ${message_text}
        RETURN    ${message_text}
    EXCEPT    AS    ${error}
        Log    Failed to get text from message: ${error}    ERROR
        Fail    Could not get text from last received message
    END

Get Queue
    [Documentation]    Get queue.
    ...
    ...    Arguments
    ...    queue
    ...
    ...    Arguments Description
    ...    queue    Name of the queue to get
    [Arguments]    ${queue}

    Log    Getting queue: ${queue}

    TRY
        # Create queue destination to get the queue
        ${dest}=    Create Queue Destination    ${queue}    ${queue}

        Log    Successfully retrieved queue: ${queue}
        Log    Queue destination: ${dest}

        RETURN    ${dest}
    EXCEPT    AS    ${error}
        Log    Failed to get queue ${queue}: ${error}    ERROR
        Fail    Could not get queue: ${queue}
    END

Get Topic
    [Documentation]    Get topic.
    ...
    ...    Arguments
    ...    topic
    ...
    ...    Arguments Description
    ...    topic    Name of the topic to get
    ...
    ...    Example:
    ...    ${topic_dest}=    Get Topic    MyTopic
    ...    Send Text Message    ${topic_dest}    Broadcast message    msg-topic-1
    [Arguments]    ${topic}

    Log    Getting topic: ${topic}

    TRY
        # Create topic destination to get the topic
        ${dest}=    Create Topic Destination    ${topic}    ${topic}

        Log    Successfully retrieved topic: ${topic}
        Log    Topic destination: ${dest}

        RETURN    ${dest}
    EXCEPT    AS    ${error}
        Log    Failed to get topic ${topic}: ${error}    ERROR
        Fail    Could not get topic: ${topic}
    END

Create Producer
    [Documentation]    Create producer for queue. Producer will be returned and also set as default producer for this instance.
    ...
    ...    Arguments
    ...    queue
    ...
    ...    Arguments Description
    ...    queue    Name of the queue for which the producer is created
    [Arguments]    ${queue}

    Log    Creating producer for queue: ${queue}

    TRY
        # Create queue destination
        ${dest}=    Create Queue Destination    ${queue}    ${queue}

        # Store the producer information for later use
        Set Suite Variable    ${ACTIVE_PRODUCER_QUEUE}    ${queue}
        Set Suite Variable    ${ACTIVE_PRODUCER_DEST}    ${dest}

        Log    Successfully created producer for queue: ${queue}
        Log    Producer destination: ${dest}

        RETURN    ${dest}
    EXCEPT    AS    ${error}
        Log    Failed to create producer for queue ${queue}: ${error}    ERROR
        Fail    Could not create producer for queue: ${queue}
    END

Create Message
    [Documentation]    Creates a message from message and sets it as default message for this instance. After calling this keyword, Send keyword can be used without passing message.
    ...
    ...    The message is object returned and also set as default message for this instance.
    ...
    ...    Arguments
    ...    message
    ...
    ...    Arguments Description
    ...    message    Text of the message
    ...
    ...    Example:
    ...    Create Message    Hello World
    ...    Create Producer    MyQueue
    ...    Send
    ...    Receive Message From Queue    MyQueue    Hello World
    [Arguments]    ${message}

    Log    Creating message: ${message}

    TRY
        # Store the message as suite variable for later use
        Set Suite Variable    ${ACTIVE_MESSAGE}    ${message}

        # Generate a unique message ID
        ${timestamp}=    Get Current Date    result_format=epoch
        ${message_id}=    Set Variable    msg-${timestamp}
        Set Suite Variable    ${ACTIVE_MESSAGE_ID}    ${message_id}

        Log    Successfully created message with ID: ${message_id}
        Log    Message content: ${message}

        RETURN    ${message}
    EXCEPT    AS    ${error}
        Log    Failed to create message: ${error}    ERROR
        Fail    Could not create message: ${message}
    END

Create Consumer
    [Documentation]    Create consumer for queue. Consumer will be returned and also set as default consumer for this instance.
    ...
    ...    Arguments
    ...    queue
    ...
    ...    Arguments Description
    ...    queue    Name of the queue for which the consumer is created
    ...
    ...    Example:
    ...    Create Consumer    MyQueue
    ...    Send Message To Queue    MyQueue    Hello World
    ...    Receive Message    Hello World
    [Arguments]    ${queue}

    Log    Creating consumer for queue: ${queue}

    TRY
        # Create queue destination
        ${dest}=    Create Queue Destination    ${queue}    ${queue}

        # Subscribe to the queue (this creates the consumer)
        ${consumer_id}=    Subscribe To Queue    ${dest}

        # Store the consumer ID for later use
        Set Suite Variable    ${ACTIVE_CONSUMER_ID}    ${consumer_id}
        Set Suite Variable    ${ACTIVE_CONSUMER_QUEUE}    ${queue}

        Log    Successfully created consumer for queue ${queue} with ID: ${consumer_id}
        RETURN    ${consumer_id}
    EXCEPT    AS    ${error}
        Log    Failed to create consumer for queue ${queue}: ${error}    ERROR
        Fail    Could not create consumer for queue: ${queue}
    END

Create Connection
    [Documentation]    Create connection to JMS server

    Log    Creating connection to JMS server at ${JMS_HOST}:${JMS_PORT}...

    TRY
        # Connect to Artemis with retry logic
        Connect To Artemis
        Log    Successfully connected to JMS server at ${JMS_HOST}:${JMS_PORT}
    EXCEPT    AS    ${error}
        Log    Failed to connect to JMS server: ${error}    ERROR
        Fail    Could not establish connection to JMS server at ${JMS_HOST}:${JMS_PORT}
    END

    Log    JMS connection established and ready for use

Close Connection
    [Documentation]    Close connection to JMS server. Shutdown JVM.

    Log    Closing connection to JMS server and shutting down JVM...

    TRY
        # Disconnect from Artemis
        Disconnect From Artemis
        Log    Successfully disconnected from JMS server

        # Note: JVM shutdown is typically handled by the underlying library
        # The UnifiedArtemisSTOMPLibrary should handle proper cleanup
        Log    JVM shutdown initiated
    EXCEPT    AS    ${error}
        Log    Warning during connection close: ${error}    WARN
        # Continue with cleanup even if disconnect fails
    END

    Log    Connection closed and JVM shutdown completed

Create Queue
    [Documentation]    Create a queue with ANYCAST routing in ActiveMQ Artemis.
    ...
    ...    Arguments
    ...    address_name
    ...    queue_name
    ...    routing_type
    ...
    ...    Arguments Description
    ...    address_name    Name of the address
    ...    queue_name    Name of the queue (defaults to address_name if not provided)
    ...    routing_type    Routing type (ANYCAST or MULTICAST, default: ANYCAST)
    ...
    ...    Example:
    ...    ${queue_dest}=    Create Queue    TestQueue
    ...    ${queue_dest}=    Create Queue    OrderSystem    HighPriorityOrders
    ...    ${queue_dest}=    Create Queue    MixedAddress    QueueView    ANYCAST
    [Arguments]    ${address_name}    ${queue_name}=${None}    ${routing_type}=ANYCAST

    Log    Creating queue: address=${address_name}, queue=${queue_name}, routing=${routing_type}

    TRY
        # Call the library method to create the queue
        ${destination}=    robot_stomp_wrapper.Create Queue
        ...    ${address_name}
        ...    ${queue_name}
        ...    ${routing_type}

        Log    Successfully created queue with destination: ${destination}
        RETURN    ${destination}
    EXCEPT    AS    ${error}
        Log    Failed to create queue: ${error}    ERROR
        Fail    Could not create queue: ${address_name}
    END

Create Topic
    [Documentation]    Create a topic with MULTICAST routing in ActiveMQ Artemis.
    ...
    ...    Arguments
    ...    address_name
    ...    topic_name
    ...
    ...    Arguments Description
    ...    address_name    Name of the address
    ...    topic_name    Name of the topic (defaults to address_name if not provided)
    ...
    ...    Example:
    ...    ${topic_dest}=    Create Topic    PriceUpdates
    ...    ${topic_dest}=    Create Topic    MarketData    StockPrices
    ...    ${topic_dest}=    Create Topic    SystemNotifications    EmailAlerts
    [Arguments]    ${address_name}    ${topic_name}=${None}

    Log    Creating topic: address=${address_name}, topic=${topic_name}

    TRY
        # Call the library method to create the topic
        ${destination}=    robot_stomp_wrapper.Create Topic    ${address_name}    ${topic_name}

        Log    Successfully created topic with destination: ${destination}
        RETURN    ${destination}
    EXCEPT    AS    ${error}
        Log    Failed to create topic: ${error}    ERROR
        Fail    Could not create topic: ${address_name}
    END

Clear Queue
    [Documentation]    Clear all messages from queue.
    ...
    ...    Arguments
    ...    queue
    ...
    ...    Arguments Description
    ...    queue    Queue to clear
    ...
    ...    Example:
    ...    Send Message To Queue    MyQueue    Hello World
    ...    Clear Queue    MyQueue
    [Arguments]    ${queue}

    Log    Clearing all messages from queue: ${queue}

    TRY
        # Create destination for the queue
        ${dest}=    Create Queue Destination    ${queue}    ${queue}

        # Subscribe to the queue
        ${subscription_id}=    Subscribe To Queue    ${dest}

        ${cleared_count}=    Set Variable    0
        ${timeout}=    Set Variable    1.0

        # Keep consuming messages until queue is empty
        FOR    ${attempt}    IN RANGE    1    1001    # Max 1000 messages to prevent infinite loop
            TRY
                ${consumed}=    Consume Messages    ${timeout}
                IF    ${consumed} == 0    BREAK
                ${cleared_count}=    Evaluate    ${cleared_count} + ${consumed}

                # Reduce timeout for subsequent attempts
                ${timeout}=    Set Variable    0.5
            EXCEPT    AS    ${error}
                Log    Error consuming messages: ${error}    WARN
                BREAK
            END
        END

        # Unsubscribe from the queue
        Unsubscribe From Queue    ${subscription_id}

        Log    Successfully cleared ${cleared_count} messages from queue: ${queue}
        RETURN    ${cleared_count}
    EXCEPT    AS    ${error}
        Log    Warning: Could not clear queue ${queue}: ${error}    WARN
        # Fallback: try simple clear approach
        TRY
            Clear Queue Once    ${queue}    timeout=2.0
            Log    Queue ${queue} cleared using fallback method
            RETURN    0
        EXCEPT    AS    ${fallback_error}
            Log    Failed to clear queue ${queue}: ${fallback_error}    ERROR
            Fail    Could not clear queue ${queue}
        END
    END

    ########### VERIFY MESSAGES ###########

Get Full Message Content From Queue
    [Documentation]    Retrieve the full message content from queue and return both content and length.
    ...    This consumes the message and re-sends it back to the queue.
    ...
    ...    Example:
    ...    ${content}    ${length}=    Get Full Message Content From Queue    ${destination}
    ...    Log    Message content: ${content}
    ...    Log    Message length: ${length} characters
    [Arguments]    ${destination}

    Log    Getting full message content from destination: ${destination}

    TRY
        # Subscribe using the full destination
        ${consumer_id}=    Subscribe To Queue    ${destination}
        
        # Set as active consumer for Get Text From Last Received Message
        Set Suite Variable    ${ACTIVE_CONSUMER_ID}    ${consumer_id}
        
        ${received}=    Wait For Messages    1    5.0

        IF    ${received} == 0
            Unsubscribe From Queue    ${consumer_id}
            Fail    No messages found at destination ${destination}
        END

        # Get the message content and length
        ${message_text}=    Get Text From Last Received Message
        ${message_length}=    Get Length    ${message_text}

        # Clean up consumer
        Unsubscribe From Queue    ${consumer_id}

        Log    Message length: ${message_length} characters

        # Re-send the message back using the SAME destination
        ${timestamp}=    Get Current Date    result_format=epoch
        Send Text Message    ${destination}    ${message_text}    resent-${timestamp}
        Log    Message re-sent to destination after extraction

        RETURN    ${message_text}    ${message_length}
    EXCEPT    AS    ${error}
        Run Keyword And Ignore Error    Unsubscribe From Queue    ${consumer_id}
        Log    Failed to get message content: ${error}    ERROR
        Fail    Could not get message content from destination: ${destination}
    END

Save Queue Content To File
    [Documentation]    Save the queue content to a JSON file with the same name as the original.
    ...
    ...    Arguments:
    ...    queue_content    - The content retrieved from the queue
    ...    original_filename    - The original filename to use as base
    ...    output_dir    - Directory where to save the file
    ...
    ...    Example:
    ...    Save Queue Content To File    ${content}    SAP_IDoc Read output0.json    ${OUTPUT_DIR}
    [Arguments]    ${queue_content}    ${original_filename}    ${output_dir}

    # Create output directory if it doesn't exist
    Create Directory    ${output_dir}

    # Get the base filename without extension
    ${base_name}=    Evaluate    os.path.splitext("${original_filename}")[0]    os

    # Create output filename with timestamp
    ${timestamp}=    Get Current Date    result_format=%Y%m%d_%H%M%S
    ${output_filename}=    Set Variable    ${base_name}_from_queue_${timestamp}.json
    ${output_path}=    Set Variable    ${output_dir}/${output_filename}

    # Parse and format the JSON for pretty printing
    TRY
        ${json_obj}=    Evaluate    json.loads('''${queue_content}''')    json
        ${formatted_json}=    Evaluate    json.dumps(${json_obj}, indent=2)    json
        Create File    ${output_path}    ${formatted_json}
        Log    Formatted JSON saved to: ${output_path}    console=yes
    EXCEPT
        # If JSON parsing fails, save as-is
        Create File    ${output_path}    ${queue_content}
        Log    Content saved as-is to: ${output_path}    console=yes
    END

    # Also save a copy without timestamp for easy comparison
    ${simple_output_path}=    Set Variable    ${output_dir}/${base_name}_from_queue.json
    Create File    ${simple_output_path}    ${queue_content}
    Log    Also saved to: ${simple_output_path}    console=yes

    RETURN    ${output_path}

Check Message Length In Queue
    [Documentation]    Simple check to verify message length in queue by consuming and re-sending.
    ...    This is useful when browse mode is not available.
    ...
    ...    Example:
    ...    ${length}=    Check Message Length In Queue    test.queue
    ...    Log    Message length: ${length} characters
    [Arguments]    ${queue_name}

    Log    Checking message length in queue: ${queue_name}

    TRY
        # Consume the message
        ${consumer_id}=    Create Consumer    ${queue_name}
        ${received}=    Wait For Messages    1    5.0

        IF    ${received} == 0
            Unsubscribe From Queue    ${consumer_id}
            Fail    No messages found in queue ${queue_name}
        END

        # Get the message content and length
        ${message_text}=    Get Text From Last Received Message
        ${message_length}=    Get Length    ${message_text}

        # Clean up consumer
        Unsubscribe From Queue    ${consumer_id}

        Log    Message length: ${message_length} characters

        # Re-send the message back to the queue
        ${dest}=    Create Queue Destination    ${queue_name}    ${queue_name}
        ${timestamp}=    Get Current Date    result_format=epoch
        Send Text Message    ${dest}    ${message_text}    resent-${timestamp}
        Log    Message re-sent to queue after checking

        RETURN    ${message_length}
    EXCEPT    AS    ${error}
        Run Keyword And Ignore Error    Unsubscribe From Queue    ${consumer_id}
        Log    Failed to check message length: ${error}    ERROR
        Fail    Could not check message length in queue: ${queue_name}
    END

Browse Queue Messages
    [Documentation]    Browse messages in queue without consuming them.
    ...    Returns a list of dictionaries containing message id, text, and length.
    ...
    ...    Example:
    ...    ${messages}=    Browse Queue Messages    test.queue    5
    ...    FOR    ${msg}    IN    @{messages}
    ...    Log    Message ${msg['id']} has ${msg['length']} characters
    ...    END
    [Arguments]    ${queue_name}    ${max_messages}=10

    Log    Browsing messages in queue: ${queue_name} (max: ${max_messages})

    TRY
        # Create a temporary consumer to browse messages
        ${consumer_id}=    Create Consumer    ${queue_name}

        ${messages}=    Create List
        ${timeout_seconds}=    Set Variable    2.0

        # Collect messages without actually consuming them
        FOR    ${i}    IN RANGE    ${max_messages}
            TRY
                # Try to receive a message
                ${received_count}=    Wait For Messages    1    ${timeout_seconds}

                IF    ${received_count} == 0
                    Log    No more messages to browse
                    BREAK
                END

                # Get the message text
                ${msg_text}=    Get Text From Last Received Message
                ${msg_length}=    Get Length    ${msg_text}

                # Create message info dictionary
                ${msg_info}=    Create Dictionary
                ...    id=msg-${i}
                ...    text=${msg_text}
                ...    length=${msg_length}

                Append To List    ${messages}    ${msg_info}

                # Reduce timeout for subsequent messages
                ${timeout_seconds}=    Set Variable    0.5
            EXCEPT    AS    ${error}
                Log    Error browsing message: ${error}    WARN
                BREAK
            END
        END

        # Clean up consumer
        Unsubscribe From Queue    ${consumer_id}

        Log    Found ${messages.__len__()} messages in queue ${queue_name}
        RETURN    ${messages}
    EXCEPT    AS    ${error}
        Run Keyword And Ignore Error    Unsubscribe From Queue    ${consumer_id}
        Log    Failed to browse queue ${queue_name}: ${error}    ERROR
        Fail    Could not browse messages in queue: ${queue_name}
    END

Consume And Verify Full Message
    [Documentation]    Consume a message from queue and verify its full content.
    ...    Returns the actual content of the message.
    ...
    ...    Arguments:
    ...    queue_name    - Name of the queue to consume from
    ...    expected_content    - Expected message content (optional)
    ...    timeout    - Timeout in milliseconds (default: 5000)
    ...
    ...    Example:
    ...    ${content}=    Consume And Verify Full Message    test.queue
    ...    ${content}=    Consume And Verify Full Message    test.queue    ${expected_json}    10000
    [Arguments]    ${queue_name}    ${expected_content}=${None}    ${timeout}=5000

    Log    Consuming message from queue: ${queue_name}

    TRY
        # Create consumer
        ${consumer_id}=    Create Consumer    ${queue_name}

        # Convert timeout to seconds
        ${timeout_seconds}=    Evaluate    ${timeout} / 1000.0

        # Receive message
        ${received_count}=    Wait For Messages    1    ${timeout_seconds}

        IF    ${received_count} == 0
            Unsubscribe From Queue    ${consumer_id}
            Fail    No message received from queue ${queue_name} within ${timeout}ms
        END

        # Get full message content
        ${actual_content}=    Get Text From Last Received Message
        ${content_length}=    Get Length    ${actual_content}

        Log    Retrieved message with ${content_length} characters

        # Log preview if message is large
        IF    ${content_length} > 500
            ${preview}=    Get Substring    ${actual_content}    0    500
            Log    Message preview (first 500 chars): ${preview}...
        ELSE
            Log    Full message: ${actual_content}
        END

        # Verify content if expected content provided
        ${has_expected_content}=    Run Keyword And Return Status
        ...    Should Not Be Equal As Strings    ${expected_content}    ${None}

        IF    ${has_expected_content}
            Should Be Equal As Strings    ${actual_content}    ${expected_content}
            ...    msg=Message content does not match expected
            Log    ✅ Message content matches expected (${content_length} chars)
        END

        # Clean up
        Unsubscribe From Queue    ${consumer_id}

        RETURN    ${actual_content}
    EXCEPT    AS    ${error}
        Run Keyword And Ignore Error    Unsubscribe From Queue    ${consumer_id}
        Log    Failed to consume message from ${queue_name}: ${error}    ERROR
        Fail    Could not consume and verify message from queue: ${queue_name}
    END

Verify Message Content Length
    [Documentation]    Verify that messages in queue exceed minimum length.
    ...    Can either browse (default) or consume messages.
    ...
    ...    Arguments:
    ...    queue_name    - Name of the queue to check
    ...    expected_min_length    - Minimum expected message length
    ...    consume    - If True, consumes messages; if False, browses (default: False)
    ...
    ...    Example:
    ...    Verify Message Content Length    test.queue    1000
    ...    Verify Message Content Length    test.queue    5000    consume=True
    [Arguments]    ${queue_name}    ${expected_min_length}    ${consume}=False

    Log    Verifying message length in queue ${queue_name} (min: ${expected_min_length} chars)

    IF    ${consume}
        # Consume and check
        ${content}=    Consume And Verify Full Message    ${queue_name}
        ${actual_length}=    Get Length    ${content}

        Should Be True    ${actual_length} >= ${expected_min_length}
        ...    Message length ${actual_length} is less than expected ${expected_min_length}

        Log    ✅ Message length ${actual_length} >= ${expected_min_length} (consumed)
    ELSE
        # Browse and check
        ${messages}=    Browse Queue Messages    ${queue_name}    10

        Should Not Be Empty    ${messages}    No messages found in queue ${queue_name}

        FOR    ${msg}    IN    @{messages}
            ${length}=    Get From Dictionary    ${msg}    length
            Should Be True    ${length} >= ${expected_min_length}
            ...    Message ${msg['id']} length ${length} is less than expected ${expected_min_length}
            Log    Message ${msg['id']}: ${length} chars ✓
        END

        Log    ✅ All ${messages.__len__()} messages exceed minimum length ${expected_min_length}
    END

Get Full Message Preview
    [Documentation]    Get a preview of a specific message in the queue without consuming it.
    ...    Useful for debugging large messages.
    ...
    ...    Arguments:
    ...    queue_name    - Name of the queue
    ...    preview_length    - Maximum characters to preview (default: 1000)
    ...    message_index    - Index of message to preview (default: 0 - first message)
    ...
    ...    Example:
    ...    ${preview}=    Get Full Message Preview    test.queue    500    0
    ...    Log    Message preview: ${preview}
    [Arguments]    ${queue_name}    ${preview_length}=1000    ${message_index}=0

    Log    Getting message preview from queue ${queue_name} (index: ${message_index})

    TRY
        ${messages}=    Browse Queue Messages    ${queue_name}    ${message_index + 1}

        Should Not Be Empty    ${messages}    No messages found in queue ${queue_name}

        ${length}=    Evaluate    len(${messages})
        Should Be True    ${length} > ${message_index}
        ...    Message index ${message_index} not found (queue has ${length} messages)

        ${msg}=    Get From List    ${messages}    ${message_index}
        ${full_text}=    Get From Dictionary    ${msg}    text
        ${full_length}=    Get From Dictionary    ${msg}    length

        # Create preview
        ${actual_preview_length}=    Evaluate    min(${preview_length}, ${full_length})
        ${preview}=    Get Substring    ${full_text}    0    ${actual_preview_length}

        # Add ellipsis if truncated
        IF    ${full_length} > ${preview_length}
            ${preview}=    Set Variable    ${preview}...
        END

        Log    Message preview (${actual_preview_length} of ${full_length} chars): ${preview}

        RETURN    ${preview}
    EXCEPT    AS    ${error}
        Log    Failed to get message preview: ${error}    ERROR
        Fail    Could not get message preview from queue: ${queue_name}
    END

Compare UI Display With Actual Message
    [Documentation]    Compare what ActiveMQ UI shows versus the actual message content.
    ...    Demonstrates the difference between UI truncation and full message.
    ...    Note: This keyword consumes one message from the queue.
    ...
    ...    Arguments:
    ...    queue_name    - Name of the queue to check
    ...    ui_display_limit    - UI character display limit (default: 256)
    ...
    ...    Example:
    ...    Compare UI Display With Actual Message    test.queue
    [Arguments]    ${queue_name}    ${ui_display_limit}=256

    Log    Comparing UI display vs actual message for queue: ${queue_name}

    TRY
        # Consume one message to check its content
        ${consumer_id}=    Create Consumer    ${queue_name}
        ${received}=    Wait For Messages    1    5.0

        IF    ${received} == 0
            Unsubscribe From Queue    ${consumer_id}
            Fail    No messages found in queue ${queue_name}
        END

        ${full_text}=    Get Text From Last Received Message
        ${actual_length}=    Get Length    ${full_text}

        # Clean up consumer
        Unsubscribe From Queue    ${consumer_id}

        Log    \n=== UI DISPLAY vs ACTUAL MESSAGE ===    console=yes
        Log    Queue: ${queue_name}    console=yes
        Log    Actual message length: ${actual_length} characters    console=yes
        Log    UI display limit: ${ui_display_limit} characters    console=yes

        IF    ${actual_length} > ${ui_display_limit}
            ${ui_preview}=    Get Substring    ${full_text}    0    ${ui_display_limit}
            ${missing_chars}=    Evaluate    ${actual_length} - ${ui_display_limit}
            ${percentage_hidden}=    Evaluate    ${missing_chars} * 100.0 / ${actual_length}

            Log    \n📊 COMPARISON:    console=yes
            Log    UI shows: "${ui_preview}..."    console=yes
            Log    Missing: ${missing_chars} characters (${percentage_hidden:.1f}% of message)    console=yes
            Log    \n⚠️    UI truncates the message!    console=yes
        ELSE
            Log    \n✅ Message fits within UI display limit    console=yes
            Log    Full message (${actual_length} chars): ${full_text}    console=yes
        END

        Log
        ...    \n💡 Use 'Browse Queue Messages' or 'Consume And Verify Full Message' to access full content
        ...    console=yes

        # Return comparison info
        ${truncated}=    Evaluate    ${actual_length} > ${ui_display_limit}
        ${missing}=    Evaluate
        ...    ${actual_length} - ${ui_display_limit} if ${actual_length} > ${ui_display_limit} else 0
        ${comparison}=    Create Dictionary
        ...    actual_length=${actual_length}
        ...    ui_limit=${ui_display_limit}
        ...    truncated=${truncated}
        ...    missing_chars=${missing}

        RETURN    ${comparison}
    EXCEPT    AS    ${error}
        Log    Failed to compare UI display: ${error}    ERROR
        Fail    Could not compare UI display with actual message
    END
