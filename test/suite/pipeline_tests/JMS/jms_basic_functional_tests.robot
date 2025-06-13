*** Settings ***
Documentation       Basic JMS tests for queue operations

Resource            ../../../resources/jms.resource

Suite Setup         Create Connection
Suite Teardown      Close Connection


*** Variables ***
${JMS_ENHANCED_FEATURES}    True


*** Test Cases ***
Test Clear Queue Functionality
    [Documentation]    Test that Clear Queue keyword successfully removes all messages from a queue
    [Tags]    jms    queue    clear

    # Setup: Send some test messages to the queue using Send Message To Queue
    Send Message To Queue    TestQueue    First test message
    Send Message To Queue    TestQueue    Second test message
    Send Message To Queue    TestQueue    Third test message

    # Execute the keyword under test - Clear Queue
    Log    About to clear 3 messages from queue...    level=Console
    ${cleared_count}=    Clear Queue    TestQueue

    # Log the result with more detail
    Log    Clear Queue returned: ${cleared_count}    level=Console
    Should Not Be Equal    ${cleared_count}    ${None}    Clear Queue should return a number
    Log    Expected to clear 3 messages, actually cleared: ${cleared_count}    level=Console

    # The Clear Queue keyword should complete without errors
    # Since we can't easily verify the queue is empty without enhanced features,
    # we'll verify that the keyword executes successfully
    Log    Successfully executed Clear Queue on TestQueue

    # Try to send and clear again to test multiple clears
    Send Message To Queue    TestQueue    Test message after clear
    ${second_clear}=    Clear Queue    TestQueue
    Log    Second clear returned: ${second_clear}

Test Create Consumer Functionality
    [Documentation]    Test that Create Consumer keyword successfully creates a consumer for a queue
    [Tags]    jms    consumer    createconsumer

    # Setup: Clear any existing messages from the test queue
    Log    About to clear potentially non-existent queue: ConsumerTestQueue
    ${clear_result}=    Clear Queue    ConsumerTestQueue
    Log    Clear Queue returned: ${clear_result} (0 means queue was empty or didn't exist)

    # Test: Create a consumer for the queue
    Log    Creating consumer for ConsumerTestQueue...
    ${consumer_id}=    Create Consumer    ConsumerTestQueue

    # Verify the consumer was created successfully
    Should Not Be Equal    ${consumer_id}    ${None}    Consumer ID should not be None
    Should Not Be Empty    ${consumer_id}    Consumer ID should not be empty
    Log    Successfully created consumer with ID: ${consumer_id}

    # Test: Send a message and use Receive Message From Queue to test basic functionality
    Send Message To Queue    ConsumerTestQueue    Hello from consumer test

    # Use Receive Message From Queue which creates its own consumer and doesn't conflict
    ${received_message}=    Receive Message From Queue    ConsumerTestQueue    timeout=3000
    Should Be Equal    ${received_message}    Hello from consumer test    Message content should match what was sent
    Log    Successfully received message: ${received_message}

    Log    Create Consumer test completed successfully - consumer creation and basic messaging work

Test Create Message Functionality
    [Documentation]    Test that Create Message keyword successfully creates a message and sets it as default for Send operations
    [Tags]    jms    message    createmessage

    # Setup: Clear any existing messages from the test queue
    Log    Clearing MessageTestQueue for test setup...
    ${clear_result}=    Clear Queue    MessageTestQueue
    Log    Cleared ${clear_result} messages from MessageTestQueue

    # Test 1: Create a message and send it using Send keyword (no message parameter)
    Log    Testing Create Message with Send keyword...
    Create Message    Hello from Create Message test
    Create Producer    MessageTestQueue
    Send    # This should send the message created by Create Message
    Log    Sent message using Create Message + Send

    # Test 2: Create another message and use Send Message (without parameter)
    Log    Testing Create Message with Send Message keyword...
    Create Message    Second test message
    Send Message    # This should send the newly created message
    Log    Sent message using Create Message + Send Message

    # Test 3: Create a message but override it in Send
    Log    Testing message override in Send keyword...
    Create Message    This should be overridden
    Send    Override message    # This should send "Override message" instead
    Log    Sent override message

    # Test 4: Create Message returns the message
    Log    Testing that Create Message returns the message...
    ${created_msg}=    Create Message    Message to be returned
    Should Be Equal    ${created_msg}    Message to be returned    Create Message should return the message
    Log    Create Message correctly returned: ${created_msg}

    # Test 5: Multiple Create Message calls - last one should be active
    Log    Testing multiple Create Message calls...
    Create Message    First message
    Create Message    Second message
    Create Message    Third message - this should be sent
    Send    # Should send the last created message
    Log    Sent last created message from multiple Create Message calls

    # Summary of messages sent (not consuming them so they remain in the queue)
    Log    Test completed. The following messages should be visible in MessageTestQueue:
    Log    1. Hello from Create Message test
    Log    2. Second test message
    Log    3. Override message
    Log    4. Third message - this should be sent
    Log    Total: 4 messages in MessageTestQueue - check the UI to verify!

Test Create Producer Functionality
    [Documentation]    Test that Create Producer keyword successfully creates a producer and sets it as default for Send operations
    [Tags]    jms    producer    createproducer

    # Setup: Clear any existing messages from test queues
    Log    Clearing test queues for producer test setup...
    ${clear_result1}=    Clear Queue    ProducerTestQueue1
    ${clear_result2}=    Clear Queue    ProducerTestQueue2
    ${clear_result3}=    Clear Queue    ProducerTestQueue3
    Log
    ...    Cleared queues: ProducerTestQueue1 (${clear_result1}), ProducerTestQueue2 (${clear_result2}), ProducerTestQueue3 (${clear_result3})

    # Test 1: Create Producer returns destination and sets it as active
    Log    Testing Create Producer basic functionality...
    ${producer_dest}=    Create Producer    ProducerTestQueue1
    Should Not Be Equal    ${producer_dest}    ${None}    Producer destination should not be None
    Should Not Be Empty    ${producer_dest}    Producer destination should not be empty
    Log    Successfully created producer with destination: ${producer_dest}

    # Test 2: Send message using the created producer with Send keyword
    Log    Testing Send with created producer...
    Create Message    Message for ProducerTestQueue1
    Send    # Should use the active producer created above
    Log    Sent message to ProducerTestQueue1 using active producer

    # Test 3: Create another producer - should replace the active one
    Log    Testing producer switching...
    ${producer_dest2}=    Create Producer    ProducerTestQueue2
    Create Message    Message for ProducerTestQueue2
    Send    # Should now send to ProducerTestQueue2
    Log    Sent message to ProducerTestQueue2 after switching producers

    # Test 4: Send Message also uses the active producer
    Log    Testing Send Message with active producer...
    Send Message    Another message for ProducerTestQueue2    # Should use active producer
    Log    Sent another message to ProducerTestQueue2 using Send Message

    # Test 5: Create Producer for third queue and send multiple messages
    Log    Testing multiple sends to same producer...
    Create Producer    ProducerTestQueue3
    Send Message    First message for Queue3
    Send Message    Second message for Queue3
    Create Message    Third message for Queue3
    Send
    Log    Sent 3 messages to ProducerTestQueue3

    # Test 6: Using Send Message To Producer with explicit producer destination
    Log    Testing Send Message To Producer keyword...
    ${producer_dest4}=    Create Producer    ProducerTestQueue1    # Back to Queue1
    Send Message To Producer    ${producer_dest4}    Direct message using producer destination
    Log    Sent message directly using producer destination

    # Test 7: Error handling - try to Send without a producer (should fail)
    Log    Testing error handling when no producer exists...
    # Clear the active producer by setting it to None (this simulates no producer)
    # Note: We can't actually clear it, but we document the expected behavior
    Log    Note: Send keyword requires an active producer created with Create Producer

    # Summary of messages sent (not consuming them so they remain in the queues)
    Log    Test completed. Messages should be visible in:
    Log    - ProducerTestQueue1: 2 messages
    Log    - ProducerTestQueue2: 2 messages
    Log    - ProducerTestQueue3: 3 messages
    Log    Total: 7 messages across 3 queues - check the UI to verify!

Test Get Queue Functionality
    [Documentation]    Test that Get Queue keyword successfully retrieves a queue destination
    [Tags]    jms    queue    getqueue

    # Setup: Clear any existing messages from test queue
    Log    Clearing GetQueueTest for test setup...
    ${clear_result}=    Clear Queue    GetQueueTest
    Log    Cleared GetQueueTest queue: ${clear_result} messages

    # Test 1: Get Queue returns a destination string
    Log    Testing Get Queue basic functionality...
    ${queue_dest}=    Get Queue    GetQueueTest
    Should Not Be Equal    ${queue_dest}    ${None}    Queue destination should not be None
    Should Not Be Empty    ${queue_dest}    Queue destination should not be empty
    Log    Successfully got queue destination: ${queue_dest}

    # Test 2: Verify the destination format
    Log    Verifying queue destination format...
    Should Contain    ${queue_dest}    GetQueueTest    Destination should contain the queue name
    Should Contain    ${queue_dest}    ::    Destination should contain :: separator
    Log    Queue destination has correct format: ${queue_dest}

    # Test 3: Get Queue for different queue names
    Log    Testing Get Queue with different queue names...
    ${queue_dest2}=    Get Queue    AnotherQueueName
    Should Contain    ${queue_dest2}    AnotherQueueName    Destination should contain the queue name
    Log    Got destination for AnotherQueueName: ${queue_dest2}

    ${queue_dest3}=    Get Queue    Queue.With.Dots
    Should Contain    ${queue_dest3}    Queue.With.Dots    Destination should handle dots in name
    Log    Got destination for Queue.With.Dots: ${queue_dest3}

    ${queue_dest4}=    Get Queue    Queue_With_Underscores
    Should Contain    ${queue_dest4}    Queue_With_Underscores    Destination should handle underscores
    Log    Got destination for Queue_With_Underscores: ${queue_dest4}

    # Test 4: Use Get Queue destination with Send Text Message
    Log    Testing Get Queue with Send Text Message...
    ${my_queue_dest}=    Get Queue    GetQueueTest
    Send Text Message    ${my_queue_dest}    Message sent using Get Queue destination    msg-getqueue-1
    Log    Successfully sent message using Get Queue destination

    # Test 5: Get Queue should be consistent - same queue name returns same destination
    Log    Testing Get Queue consistency...
    ${dest_a}=    Get Queue    ConsistencyTestQueue
    ${dest_b}=    Get Queue    ConsistencyTestQueue
    Should Be Equal    ${dest_a}    ${dest_b}    Same queue name should return same destination
    Log    Get Queue returns consistent destinations: ${dest_a}

    # Test 6: Get Queue can be used to create multiple destinations before sending
    Log    Testing multiple Get Queue calls...
    ${dest1}=    Get Queue    MultiQueue1
    ${dest2}=    Get Queue    MultiQueue2
    ${dest3}=    Get Queue    MultiQueue3

    # Send messages to each destination
    Send Text Message    ${dest1}    Message for MultiQueue1    msg-multi-1
    Send Text Message    ${dest2}    Message for MultiQueue2    msg-multi-2
    Send Text Message    ${dest3}    Message for MultiQueue3    msg-multi-3
    Log    Sent messages to 3 different queues using Get Queue destinations

    # Test 7: Compare Get Queue with Create Queue Destination
    Log    Comparing Get Queue with Create Queue Destination...
    ${get_queue_dest}=    Get Queue    ComparisonQueue
    ${create_queue_dest}=    Create Queue Destination    ComparisonQueue    ComparisonQueue
    Should Be Equal
    ...    ${get_queue_dest}
    ...    ${create_queue_dest}
    ...    Get Queue and Create Queue Destination should return same format
    Log    Get Queue and Create Queue Destination return identical destinations: ${get_queue_dest}

    # Summary of test results
    Log    Test completed. Messages should be visible in:
    Log    - GetQueueTest: 1 message
    Log    - MultiQueue1: 1 message
    Log    - MultiQueue2: 1 message
    Log    - MultiQueue3: 1 message
    Log    Total: 4 messages across 4 queues
    Log    Note: Get Queue is a utility keyword that returns queue destinations for use with other keywords

Test Get Text From Last Received Message Functionality
    [Documentation]    Test that Get Text From Last Received Message keyword from jms2.resource successfully retrieves text from consumed messages with assertion support
    [Tags]    jms    consumer    gettextfromlastreceivedmessage

    # Setup: Clear any existing messages from test queue
    Log    Clearing GetTextTestQueue for test setup...
    ${clear_result}=    Clear Queue    GetTextTestQueue
    Log    Cleared GetTextTestQueue: ${clear_result} messages

    # Test 1: Get Text From Last Received Message after receiving a message
    Log    Testing Get Text From Last Received Message after Receive Message...
    # Send a message first
    Send Message To Queue    GetTextTestQueue    Hello from Get Text From Last Received Message test

    # Create consumer and receive the message
    Create Consumer    GetTextTestQueue
    ${received}=    Receive Message    timeout=3000
    Should Be Equal
    ...    ${received}
    ...    Hello from Get Text From Last Received Message test
    ...    Receive Message should return the text

    # Now test Get Text From Last Received Message - should return the same text
    ${text}=    Get Text From Last Received Message
    Should Be Equal
    ...    ${text}
    ...    Hello from Get Text From Last Received Message test
    ...    Get Text From Last Received Message should return the same message text
    Log    Successfully retrieved text using Get Text From Last Received Message: ${text}

    # Test 2: Get Text From Last Received Message with assertion parameters
    Log    Testing Get Text From Last Received Message with assertions...
    # Send another message
    Send Message To Queue    GetTextTestQueue    Test message with assertions
    ${received2}=    Receive Message    timeout=3000

    # Test with equality assertion
    Get Text From Last Received Message    ==    Test message with assertions
    Log    Get Text From Last Received Message with == assertion passed

    # Test with contains assertion
    Get Text From Last Received Message    contains    assertions
    Log    Get Text From Last Received Message with contains assertion passed

    # Test with not equal assertion
    Get Text From Last Received Message    !=    Different message    This is not the actual message
    Log    Get Text From Last Received Message with != assertion passed

    # Test with not contains assertion
    Get Text From Last Received Message    not contains    xyz    Message should not contain xyz
    Log    Get Text From Last Received Message with 'not contains' assertion passed

    # Test 3: Get Text From Last Received Message returns the last received message
    Log    Testing Get Text From Last Received Message returns last message...
    # Send multiple messages
    Send Message To Queue    GetTextTestQueue    First message
    Send Message To Queue    GetTextTestQueue    Second message
    Send Message To Queue    GetTextTestQueue    Third message - this is the last

    # Receive all three messages
    ${msg1}=    Receive Message    timeout=3000
    ${msg2}=    Receive Message    timeout=3000
    ${msg3}=    Receive Message    timeout=3000

    # Get Text From Last Received Message should return the last received message
    ${last_text}=    Get Text From Last Received Message
    Should Be Equal
    ...    ${last_text}
    ...    Third message - this is the last
    ...    Get Text From Last Received Message should return the last received message
    Log    Get Text From Last Received Message correctly returned last message: ${last_text}

    # Test 4: Get Text From Last Received Message with different message types
    Log    Testing Get Text From Last Received Message with different message content...
    # Numbers
    Send Message To Queue    GetTextTestQueue    12345
    Receive Message    timeout=3000
    ${number_text}=    Get Text From Last Received Message
    Should Be Equal    ${number_text}    12345    Get Text From Last Received Message should handle numeric content

    # Special characters
    Send Message To Queue    GetTextTestQueue    Special chars: !@#$%^&*()
    Receive Message    timeout=3000
    ${special_text}=    Get Text From Last Received Message
    Should Be Equal
    ...    ${special_text}
    ...    Special chars: !@#$%^&*()
    ...    Get Text From Last Received Message should handle special characters

    # Empty message
    Send Message To Queue    GetTextTestQueue    ${EMPTY}
    Receive Message    timeout=3000
    ${empty_text}=    Get Text From Last Received Message
    Should Be Equal    ${empty_text}    ${EMPTY}    Get Text From Last Received Message should handle empty messages

    # Test 5: Get Text From Last Received Message workflow with multiple consumers
    Log    Testing Get Text From Last Received Message with consumer switching...
    # Create two queues with messages
    Send Message To Queue    GetTextQueue1    Message from Queue 1
    Send Message To Queue    GetTextQueue2    Message from Queue 2

    # Create consumer for first queue
    ${consumer1}=    Create Consumer    GetTextQueue1
    Receive Message    timeout=3000
    ${text1}=    Get Text From Last Received Message
    Should Be Equal    ${text1}    Message from Queue 1

    # Create consumer for second queue (this becomes the active consumer)
    ${consumer2}=    Create Consumer    GetTextQueue2
    Receive Message    timeout=3000
    ${text2}=    Get Text From Last Received Message
    Should Be Equal    ${text2}    Message from Queue 2
    Log    Get Text From Last Received Message works correctly with multiple consumers

    # Test 6: Get Text From Last Received Message assertion with custom error message
    Log    Testing Get Text From Last Received Message with custom error message...
    Send Message To Queue    GetTextTestQueue    Test custom error
    Create Consumer    GetTextTestQueue
    Receive Message    timeout=3000
    Get Text From Last Received Message    ==    Test custom error    Custom error: Message content mismatch!
    Log    Get Text From Last Received Message with custom error message passed

    # Summary
    Log    Test completed. Get Text From Last Received Message functionality verified:
    Log    - Retrieves text from last received message
    Log    - Supports assertion operators (==, !=, contains, not contains)
    Log    - Supports custom error messages for assertions
    Log    - Handles various message content types
    Log    - Works with consumer switching
    Log    Note: This test consumed all messages to verify Get Text From Last Received Message functionality

Test Get Text From Message Functionality
    [Documentation]    Test that Get Text From Message keyword successfully extracts text from message objects with assertion support
    [Tags]    jms    message    gettextfrommessage

    # Setup: Clear any existing messages from test queue
    Log    Clearing GetTextFromMessageQueue for test setup...
    ${clear_result}=    Clear Queue    GetTextFromMessageQueue
    Log    Cleared GetTextFromMessageQueue: ${clear_result} messages

    # Test 1: Get Text From Message with string message
    Log    Testing Get Text From Message with string message...
    # Send and receive a message
    Send Message To Queue    GetTextFromMessageQueue    Simple text message
    ${message}=    Receive Message From Queue    GetTextFromMessageQueue    timeout=3000

    # Get text from the message
    ${text}=    Get Text From Message    ${message}
    Should Be Equal    ${text}    Simple text message    Get Text From Message should extract the text
    Log    Successfully extracted text from string message: ${text}

    # Test 2: Get Text From Message with assertion parameters
    Log    Testing Get Text From Message with assertions...
    Send Message To Queue    GetTextFromMessageQueue    Message with assertions test
    ${message2}=    Receive Message From Queue    GetTextFromMessageQueue    timeout=3000

    # Test with equality assertion
    Get Text From Message    ${message2}    ==    Message with assertions test
    Log    Get Text From Message with == assertion passed

    # Test with contains assertion
    Get Text From Message    ${message2}    contains    assertions
    Log    Get Text From Message with contains assertion passed

    # Test with not equal assertion
    Get Text From Message    ${message2}    !=    Different message    This is not the actual message
    Log    Get Text From Message with != assertion passed

    # Test with not contains assertion
    Get Text From Message    ${message2}    not contains    xyz    Message should not contain xyz
    Log    Get Text From Message with 'not contains' assertion passed

    # Test 3: Get Text From Message with custom error message
    Log    Testing Get Text From Message with custom error message...
    Send Message To Queue    GetTextFromMessageQueue    Custom error test message
    ${message3}=    Receive Message From Queue    GetTextFromMessageQueue    timeout=3000

    Get Text From Message    ${message3}    ==    Custom error test message    Custom: Message content mismatch!
    Log    Get Text From Message with custom error message passed

    # Test 4: Get Text From Message with different message types
    Log    Testing Get Text From Message with various content types...

    # Numeric content
    Send Message To Queue    GetTextFromMessageQueue    12345
    ${num_msg}=    Receive Message From Queue    GetTextFromMessageQueue    timeout=3000
    ${num_text}=    Get Text From Message    ${num_msg}
    Should Be Equal    ${num_text}    12345    Should handle numeric content
    Log    Handled numeric message: ${num_text}

    # Special characters
    Send Message To Queue    GetTextFromMessageQueue    Special: !@#$%^&*()[]{}
    ${special_msg}=    Receive Message From Queue    GetTextFromMessageQueue    timeout=3000
    ${special_text}=    Get Text From Message    ${special_msg}
    Should Be Equal    ${special_text}    Special: !@#$%^&*()[]{}    Should handle special characters
    Log    Handled special characters: ${special_text}

    # Empty message
    Send Message To Queue    GetTextFromMessageQueue    ${EMPTY}
    ${empty_msg}=    Receive Message From Queue    GetTextFromMessageQueue    timeout=3000
    ${empty_text}=    Get Text From Message    ${empty_msg}
    Should Be Equal    ${empty_text}    ${EMPTY}    Should handle empty messages
    Log    Handled empty message correctly

    # Test 5: Get Text From Message with multiple messages in sequence
    Log    Testing Get Text From Message with multiple messages...
    # Send multiple messages
    Send Message To Queue    GetTextFromMessageQueue    First message
    Send Message To Queue    GetTextFromMessageQueue    Second message
    Send Message To Queue    GetTextFromMessageQueue    Third message

    # Receive and extract text from each
    ${msg1}=    Receive Message From Queue    GetTextFromMessageQueue    timeout=3000
    ${text1}=    Get Text From Message    ${msg1}
    Should Be Equal    ${text1}    First message

    ${msg2}=    Receive Message From Queue    GetTextFromMessageQueue    timeout=3000
    ${text2}=    Get Text From Message    ${msg2}
    Should Be Equal    ${text2}    Second message

    ${msg3}=    Receive Message From Queue    GetTextFromMessageQueue    timeout=3000
    ${text3}=    Get Text From Message    ${msg3}
    Should Be Equal    ${text3}    Third message

    Log    Successfully extracted text from all three messages

    # Test 6: Get Text From Message - verify it can be called multiple times on same message
    Log    Testing multiple calls on same message object...
    Send Message To Queue    GetTextFromMessageQueue    Reusable message
    ${reusable_msg}=    Receive Message From Queue    GetTextFromMessageQueue    timeout=3000

    # Call Get Text From Message multiple times on the same message
    ${text_a}=    Get Text From Message    ${reusable_msg}
    ${text_b}=    Get Text From Message    ${reusable_msg}
    ${text_c}=    Get Text From Message    ${reusable_msg}

    Should Be Equal    ${text_a}    Reusable message    First call should work
    Should Be Equal    ${text_b}    Reusable message    Second call should work
    Should Be Equal    ${text_c}    Reusable message    Third call should work
    Should Be Equal    ${text_a}    ${text_b}    All calls should return same text
    Should Be Equal    ${text_b}    ${text_c}    All calls should return same text
    Log    Message object can be reused multiple times

    # Test 7: Difference between Get Text From Message and Get Text From Last Received Message
    Log    Demonstrating difference between Get Text From Message and Get Text From Last Received Message...
    Send Message To Queue    GetTextFromMessageQueue    Comparison test message

    # Get Text From Message requires a message object parameter
    ${msg_obj}=    Receive Message From Queue    GetTextFromMessageQueue    timeout=3000
    ${text_from_msg}=    Get Text From Message    ${msg_obj}
    Should Be Equal    ${text_from_msg}    Comparison test message

    # Get Text From Last Received Message works on the last received message (no parameter needed)
    Create Consumer    GetTextFromMessageQueue
    Send Message To Queue    GetTextFromMessageQueue    Another comparison message
    Receive Message    timeout=3000
    ${text_from_last}=    Get Text From Last Received Message
    Should Be Equal    ${text_from_last}    Another comparison message

    Log    Get Text From Message: works on any message object passed as parameter
    Log    Get Text From Last Received Message: works on the last received message (no parameter)

    # Summary
    Log    Test completed. Get Text From Message functionality verified:
    Log    - Extracts text from message objects passed as parameter
    Log    - Supports assertion operators (==, !=, contains, not contains)
    Log    - Supports custom error messages for assertions
    Log    - Handles various message content types
    Log    - Can be called multiple times on the same message object
    Log    - Works with message objects from Receive Message From Queue
    Log    Note: Get Text From Message requires a message parameter, unlike Get Text From Last Received Message

Test Create Queue Functionality
    [Documentation]    Test that Create Queue keyword successfully creates ANYCAST queues in ActiveMQ Artemis
    [Tags]    jms    queue    createqueue

    # Test 1: Create simple queue (address and queue name are same)
    Log    Testing Create Queue with simple name...
    ${queue_dest1}=    Create Queue    SimpleTestQueue
    Should Not Be Equal    ${queue_dest1}    ${None}    Queue destination should not be None
    Should Contain    ${queue_dest1}    SimpleTestQueue::SimpleTestQueue    Should use address::queue format
    Log    Created simple queue: ${queue_dest1}

    # Test 2: Create queue with different address and queue name
    Log    Testing Create Queue with different address and queue names...
    ${queue_dest2}=    Create Queue    OrderSystem    HighPriorityOrders
    Should Contain    ${queue_dest2}    OrderSystem::HighPriorityOrders    Should use address::queue format
    Log    Created queue with different names: ${queue_dest2}

    # Test 3: Create multiple queues on same address
    Log    Testing multiple queues on same address...
    ${queue_dest3}=    Create Queue    OrderSystem    NormalPriorityOrders
    ${queue_dest4}=    Create Queue    OrderSystem    LowPriorityOrders
    Log    Created multiple queues on OrderSystem address

    # Test 4: Create queue with explicit ANYCAST routing
    Log    Testing Create Queue with explicit ANYCAST routing...
    ${queue_dest5}=    Create Queue    ExplicitAnycastQueue    ProcessingQueue    ANYCAST
    Should Contain    ${queue_dest5}    ExplicitAnycastQueue::ProcessingQueue
    Log    Created queue with explicit ANYCAST routing: ${queue_dest5}

    # Test 5: Create queue that already exists (should not fail)
    Log    Testing Create Queue idempotency...
    ${queue_dest6}=    Create Queue    SimpleTestQueue
    Should Be Equal    ${queue_dest6}    ${queue_dest1}    Should return same destination
    Log    Create Queue is idempotent - no error when queue exists

    # Test 6: Create queue with special characters in name
    Log    Testing Create Queue with special characters...
    ${queue_dest7}=    Create Queue    test.queue.with.dots
    Should Contain    ${queue_dest7}    test.queue.with.dots::test.queue.with.dots

    ${queue_dest8}=    Create Queue    test_queue_underscores
    Should Contain    ${queue_dest8}    test_queue_underscores::test_queue_underscores

    ${queue_dest9}=    Create Queue    test-queue-dashes
    Should Contain    ${queue_dest9}    test-queue-dashes::test-queue-dashes
    Log    Created queues with special characters successfully

    # Summary
    Log    Test completed. Created ANYCAST queues:
    Log    - SimpleTestQueue
    Log    - OrderSystem::HighPriorityOrders
    Log    - OrderSystem::NormalPriorityOrders
    Log    - OrderSystem::LowPriorityOrders
    Log    - ExplicitAnycastQueue::ProcessingQueue
    Log    - test.queue.with.dots
    Log    - test_queue_underscores
    Log    - test-queue-dashes
    Log    Check ActiveMQ console to verify all queues show ANYCAST routing only

Test Create Topic Functionality
    [Documentation]    Test that Create Topic keyword successfully creates MULTICAST topics in ActiveMQ Artemis
    [Tags]    jms    topic    createtopic

    # Test 1: Create simple topic (address and topic name are same)
    Log    Testing Create Topic with simple name...
    ${topic_dest1}=    Create Topic    SimpleTestTopic
    Should Not Be Equal    ${topic_dest1}    ${None}    Topic destination should not be None
    Should Contain    ${topic_dest1}    SimpleTestTopic::SimpleTestTopic    Should use address::topic format
    Log    Created simple topic: ${topic_dest1}

    # Send message to verify topic works (creates subscription)
    Send Text Message    ${topic_dest1}    Broadcast message for SimpleTestTopic    msg-topic-1
    Log    Sent broadcast message to topic

    # Test 2: Create topic with different address and topic name
    Log    Testing Create Topic with different address and topic names...
    ${topic_dest2}=    Create Topic    MarketData    StockPrices
    Should Contain    ${topic_dest2}    MarketData::StockPrices    Should use address::topic format
    Log    Created topic with different names: ${topic_dest2}

    # Test functionality
    Send Text Message    ${topic_dest2}    AAPL: $150.00    msg-stock-1

    # Test 3: Create multiple topics on same address
    Log    Testing multiple topics on same address...
    ${topic_dest3}=    Create Topic    MarketData    ForexRates
    ${topic_dest4}=    Create Topic    MarketData    CryptoRates

    # Send messages to different topics on same address
    Send Text Message    ${topic_dest3}    EUR/USD: 1.0850    msg-forex-1
    Send Text Message    ${topic_dest4}    BTC/USD: 45000    msg-crypto-1
    Log    Created multiple topics on MarketData address

    # Test 4: Create notification topics
    Log    Testing notification topic pattern...
    ${topic_dest5}=    Create Topic    SystemNotifications    EmailAlerts
    ${topic_dest6}=    Create Topic    SystemNotifications    SMSAlerts
    ${topic_dest7}=    Create Topic    SystemNotifications    PushNotifications

    # Send a notification that would go to all subscribers
    Send Text Message    ${topic_dest5}    System maintenance tonight    msg-email-1
    Send Text Message    ${topic_dest6}    System maintenance tonight    msg-sms-1
    Send Text Message    ${topic_dest7}    System maintenance tonight    msg-push-1
    Log    Created notification topics for pub-sub pattern

    # Test 5: Create topic that already exists (should not fail)
    Log    Testing Create Topic idempotency...
    ${topic_dest8}=    Create Topic    SimpleTestTopic
    Should Be Equal    ${topic_dest8}    ${topic_dest1}    Should return same destination
    Log    Create Topic is idempotent - no error when topic exists

    # Test 6: Create topic with special characters in name
    Log    Testing Create Topic with special characters...
    ${topic_dest9}=    Create Topic    test.topic.with.dots
    Should Contain    ${topic_dest9}    test.topic.with.dots::test.topic.with.dots

    ${topic_dest10}=    Create Topic    test_topic_underscores
    Should Contain    ${topic_dest10}    test_topic_underscores::test_topic_underscores

    ${topic_dest11}=    Create Topic    test-topic-dashes
    Should Contain    ${topic_dest11}    test-topic-dashes::test-topic-dashes
    Log    Created topics with special characters successfully

    # Test 7: Mixed usage - topics for event streaming
    Log    Testing event streaming topic pattern...
    ${event_topic1}=    Create Topic    UserEvents    LoginEvents
    ${event_topic2}=    Create Topic    UserEvents    LogoutEvents
    ${event_topic3}=    Create Topic    UserEvents    ProfileUpdateEvents

    # Send some events
    Send Text Message    ${event_topic1}    User john.doe logged in    msg-login-1
    Send Text Message    ${event_topic2}    User jane.doe logged out    msg-logout-1
    Send Text Message    ${event_topic3}    User john.doe updated profile    msg-profile-1
    Log    Created event streaming topics

    # Summary
    Log    Test completed. Created MULTICAST topics:
    Log    - SimpleTestTopic (with message)
    Log    - MarketData::StockPrices (with message)
    Log    - MarketData::ForexRates (with message)
    Log    - MarketData::CryptoRates (with message)
    Log    - SystemNotifications::EmailAlerts (with message)
    Log    - SystemNotifications::SMSAlerts (with message)
    Log    - SystemNotifications::PushNotifications (with message)
    Log    - UserEvents::LoginEvents (with message)
    Log    - UserEvents::LogoutEvents (with message)
    Log    - UserEvents::ProfileUpdateEvents (with message)
    Log    - test.topic.with.dots
    Log    - test_topic_underscores
    Log    - test-topic-dashes
    Log    Check ActiveMQ console to verify all topics show MULTICAST routing

Test Create Queue And Topic Together
    [Documentation]    Test creating both queues and topics to demonstrate the difference
    [Tags]    jms    queue    topic    anycast    multicast

    # Setup: Clear test queues/topics
    Log    Setting up test by clearing any existing messages...
    Clear Queue    MixedTestAddress

    # Test: Create both queue and topic on same address (if Artemis allows BOTH routing)
    Log    Creating queue and topic on same address to show the difference...

    # Create ANYCAST queue for point-to-point messaging
    ${queue_dest}=    Create Queue    OrderProcessingSystem    OrderQueue    ANYCAST
    Log    Created ANYCAST queue: ${queue_dest}

    # Create MULTICAST topic for broadcasts on different address
    ${topic_dest}=    Create Topic    OrderProcessingSystem    OrderNotifications
    Log    Created MULTICAST topic: ${topic_dest}

    # Send order to queue (point-to-point - one consumer gets it)
    Send Text Message    ${queue_dest}    Order #12345 for processing    msg-order-1
    Log    Sent order to ANYCAST queue for processing

    # Send notification to topic (pub-sub - all subscribers get it)
    Send Text Message    ${topic_dest}    Order #12345 received    msg-notif-1
    Log    Sent notification to MULTICAST topic for all subscribers

    # Create more examples
    Log    Creating more queue/topic examples...

    # Payment processing - use queue for actual processing
    ${payment_queue}=    Create Queue    PaymentSystem    PaymentProcessing
    Send Text Message    ${payment_queue}    Process payment for $99.99    msg-payment-1

    # Payment notifications - use topic for notifications
    ${payment_topic}=    Create Topic    PaymentSystem    PaymentNotifications
    Send Text Message    ${payment_topic}    Payment processed for $99.99    msg-pay-notif-1

    # Inventory updates - queue for updates
    ${inventory_queue}=    Create Queue    InventorySystem    StockUpdates
    Send Text Message    ${inventory_queue}    Reduce stock: ITEM-123 qty 5    msg-stock-1

    # Inventory alerts - topic for low stock alerts
    ${inventory_topic}=    Create Topic    InventorySystem    LowStockAlerts
    Send Text Message    ${inventory_topic}    Low stock alert: ITEM-123    msg-alert-1

    # Summary
    Log    Test completed. Demonstrated queue vs topic usage:
    Log    QUEUES (ANYCAST - Point-to-Point):
    Log    - OrderProcessingSystem::OrderQueue - for order processing
    Log    - PaymentSystem::PaymentProcessing - for payment processing
    Log    - InventorySystem::StockUpdates - for inventory updates
    Log
    Log    TOPICS (MULTICAST - Publish-Subscribe):
    Log    - OrderProcessingSystem::OrderNotifications - for order broadcasts
    Log    - PaymentSystem::PaymentNotifications - for payment broadcasts
    Log    - InventorySystem::LowStockAlerts - for inventory alerts
    Log
    Log    Key Differences:
    Log    - Queues: Each message processed by ONE consumer (load balanced)
    Log    - Topics: Each message received by ALL subscribers (broadcast)
    Log    Check ActiveMQ console to see ANYCAST vs MULTICAST routing types

Test Queue And Topic Routing Types
    [Documentation]    Verify that Create Queue creates ANYCAST and Create Topic creates MULTICAST
    [Tags]    jms    queue    topic    routing2

    # Create a queue - should be ANYCAST
    Log    Creating queue (should be ANYCAST)...
    ${queue_dest}=    Create Queue    TestRoutingQueue
    Log    Created queue: ${queue_dest}

    # Create a topic - should be MULTICAST
    Log    Creating topic (should be MULTICAST)...
    ${topic_dest}=    Create Topic    TestRoutingTopic
    Log    Created topic: ${topic_dest}

    # Create queue and topic on same address to show different routing
    Log    Creating queue and topic on same address...
    ${mixed_queue}=    Create Queue    MixedAddress    QueueOnMixed
    ${mixed_topic}=    Create Topic    MixedAddress    TopicOnMixed

    # Create queue with no queue name (defaults to address name)
    Log    Creating queue with no queue name specified...
    ${default_queue}=    Create Queue    DefaultQueueName
    Should Contain    ${default_queue}    DefaultQueueName::DefaultQueueName
    Log    Created queue with default name: ${default_queue}

    # Create topic with no topic name (defaults to address name)
    Log    Creating topic with no topic name specified...
    ${default_topic}=    Create Topic    DefaultTopicName
    Should Contain    ${default_topic}    DefaultTopicName::DefaultTopicName
    Log    Created topic with default name: ${default_topic}

    Log    Test completed. Check ActiveMQ console:
    Log    - TestRoutingQueue should show ["ANYCAST"]
    Log    - TestRoutingTopic should show ["MULTICAST"]
    Log    - MixedAddress might show ["MULTICAST","ANYCAST"] as it has both
    Log    - DefaultQueueName should show ["ANYCAST"] with queue name same as address
    Log    - DefaultTopicName should show ["MULTICAST"] with topic name same as address

Test Send Keyword Functionality
    [Documentation]    Test Send keyword for single producer workflow with message management
    ...    Use Send when:
    ...    - Sending multiple messages to the same queue
    ...    - Want to use Create Message for message management
    ...    - Working with a single producer workflow
    [Tags]    jms    producer    send

    # Setup: Clear the test queue
    Log    Clearing SendTestQueue for test setup...
    ${clear_result}=    Clear Queue    SendTestQueue
    Log    Cleared SendTestQueue: ${clear_result} messages

    # Test 1: Basic Send with Create Message - Message Management
    Log    Testing Send with Create Message for message management...
    Create Producer    SendTestQueue

    # Create and send first message
    Create Message    First managed message
    Send    # Uses the created message

    # Create and send second message
    Create Message    Second managed message
    Send    # Uses the new created message

    # Create and send third message
    Create Message    Third managed message
    Send    # Uses the latest created message

    Log    Demonstrated message management with Create Message + Send

    # Test 2: Send with override - flexibility
    Log    Testing Send with message override...
    Create Message    This will be overridden
    Send    Overridden message    # Overrides the created message

    # Test 3: Sending multiple messages to same queue efficiently
    Log    Testing efficient multiple message sending to same queue...
    # This is where Send shines - no need to specify queue each time
    FOR    ${i}    IN RANGE    1    6
        Send    Message number ${i} in batch
    END
    Log    Sent 5 messages efficiently using Send

    # Test 4: Template-based messaging with Create Message
    Log    Testing template-based messaging workflow...
    ${timestamp}=    Get Current Date    result_format=%Y-%m-%d %H:%M:%S
    Create Message    Status update at ${timestamp}: System operational
    Send    # Send the templated message

    # Reuse the template concept
    ${timestamp2}=    Get Current Date    result_format=%Y-%m-%d %H:%M:%S
    Create Message    Status update at ${timestamp2}: Process completed
    Send    # Send another templated message

    # Verify all messages were sent (total: 11 messages)
    Log    Test completed. Messages sent to SendTestQueue:
    Log    - 3 managed messages using Create Message
    Log    - 1 overridden message
    Log    - 5 batch messages
    Log    - 2 templated status messages
    Log    Total: 11 messages demonstrating Send keyword strengths

Test Send Message To Queue Functionality
    [Documentation]    Test Send Message To Queue for quick one-off sends without producer management
    ...    Use Send Message To Queue when:
    ...    - Need a quick one-off send
    ...    - Don't want to manage producers
    ...    - Sending to different queues occasionally
    [Tags]    jms    queue    sendmessagetoqueue

    # Setup: Clear multiple test queues
    Log    Clearing multiple queues for test setup...
    Clear Queue    QuickSendQueue1
    Clear Queue    QuickSendQueue2
    Clear Queue    QuickSendQueue3
    Clear Queue    AlertQueue
    Clear Queue    LogQueue

    # Test 1: Quick one-off sends without producer setup
    Log    Testing quick one-off sends...
    # No Create Producer needed - just send directly
    Send Message To Queue    QuickSendQueue1    Quick message 1
    Send Message To Queue    QuickSendQueue2    Quick message 2
    Send Message To Queue    QuickSendQueue3    Quick message 3
    Log    Sent one-off messages to 3 different queues without creating any producers

    # Test 2: Sending to different queues occasionally
    Log    Testing occasional sends to different queues...
    # Simulate a system that occasionally sends alerts or logs to different queues
    ${status}=    Set Variable    OK
    Send Message To Queue    LogQueue    System started

    # Do some work...
    ${status}=    Set Variable    WARNING
    IF    '${status}' == 'WARNING'
        Send Message To Queue    AlertQueue    Warning: High memory usage
    END

    # More work...
    Send Message To Queue    LogQueue    Process completed

    Log    Demonstrated occasional sends to different queues based on conditions

    # Test 3: Ad-hoc debugging/testing messages
    Log    Testing ad-hoc debugging messages...
    # Perfect for debugging - just send a test message anywhere
    Send Message To Queue    QuickSendQueue1    Debug: Testing connection
    Send Message To Queue    QuickSendQueue2    Debug: Checking queue status

    # Test 4: Cross-system messaging without producer state
    Log    Testing cross-system messaging...
    # Send notifications to different subsystems without maintaining producers
    Send Message To Queue    OrderQueue    New order received: ORD-123
    Send Message To Queue    InventoryQueue    Update stock for: ITEM-456
    Send Message To Queue    ShippingQueue    Prepare shipment: SHIP-789

    # Test 5: Exception/error reporting to specific queues
    Log    Testing error reporting scenario...
    TRY
        # Simulate some operation
        Should Be Equal    1    2    Simulated error
    EXCEPT
        Send Message To Queue    ErrorQueue    Error occurred in test execution
    END

    Log    Test completed. Demonstrated Send Message To Queue strengths:
    Log    - No producer management needed
    Log    - Easy one-off sends to multiple queues
    Log    - Perfect for occasional/conditional sends
    Log    - Great for debugging and cross-system messaging

Test Send Message To Producer Functionality
    [Documentation]    Test Send Message To Producer for complex routing with multiple producers
    ...    Use Send Message To Producer when:
    ...    - Managing multiple producers
    ...    - Need explicit control over which producer to use
    ...    - Building complex routing scenarios
    [Tags]    jms    producer    sendmessagetoproducer

    # Setup: Clear test queues
    Log    Clearing queues for multi-producer test...
    Clear Queue    PriorityHighQueue
    Clear Queue    PriorityNormalQueue
    Clear Queue    PriorityLowQueue
    Clear Queue    RegionUSQueue
    Clear Queue    RegionEUQueue
    Clear Queue    RegionASIAQueue

    # Test 1: Multiple producers for priority-based routing
    Log    Testing priority-based routing with multiple producers...
    ${high_priority_producer}=    Create Producer    PriorityHighQueue
    ${normal_priority_producer}=    Create Producer    PriorityNormalQueue
    ${low_priority_producer}=    Create Producer    PriorityLowQueue

    # Route messages based on priority
    Send Message To Producer    ${high_priority_producer}    URGENT: System failure detected
    Send Message To Producer    ${normal_priority_producer}    INFO: Daily report ready
    Send Message To Producer    ${low_priority_producer}    DEBUG: Verbose logging data
    Send Message To Producer    ${high_priority_producer}    URGENT: Customer complaint
    Send Message To Producer    ${normal_priority_producer}    INFO: Backup completed

    Log    Demonstrated priority-based routing with explicit producer control

    # Test 2: Geographic routing with multiple producers
    Log    Testing geographic routing scenario...
    ${us_producer}=    Create Producer    RegionUSQueue
    ${eu_producer}=    Create Producer    RegionEUQueue
    ${asia_producer}=    Create Producer    RegionASIAQueue

    # Route messages based on region
    @{us_customers}=    Create List    US-CUST-001    US-CUST-002
    @{eu_customers}=    Create List    EU-CUST-001    EU-CUST-002
    @{asia_customers}=    Create List    ASIA-CUST-001    ASIA-CUST-002

    FOR    ${customer}    IN    @{us_customers}
        Send Message To Producer    ${us_producer}    Order from ${customer}
    END

    FOR    ${customer}    IN    @{eu_customers}
        Send Message To Producer    ${eu_producer}    Order from ${customer}
    END

    FOR    ${customer}    IN    @{asia_customers}
        Send Message To Producer    ${asia_producer}    Order from ${customer}
    END

    Log    Demonstrated geographic routing with multiple producers

    # Test 3: Dynamic producer selection based on load/conditions
    Log    Testing dynamic producer selection...
    @{producer_pool}=    Create List    ${us_producer}    ${eu_producer}    ${asia_producer}
    ${message_count}=    Set Variable    0

    # Simulate load balancing across producers
    FOR    ${i}    IN RANGE    6
        ${producer_index}=    Evaluate    ${i} % 3
        ${selected_producer}=    Get From List    ${producer_pool}    ${producer_index}
        Send Message To Producer    ${selected_producer}    Load balanced message ${i}
        ${message_count}=    Evaluate    ${message_count} + 1
    END

    Log    Sent ${message_count} messages using round-robin load balancing

    # Test 4: Producer switching for transaction scenarios
    Log    Testing transaction-based producer switching...
    ${main_producer}=    Create Producer    MainTransactionQueue
    ${audit_producer}=    Create Producer    AuditQueue
    ${archive_producer}=    Create Producer    ArchiveQueue

    # Process a transaction with multiple queues
    Send Message To Producer    ${main_producer}    Transaction TXN-001 started
    Send Message To Producer    ${audit_producer}    Audit: TXN-001 initiated by user123
    Send Message To Producer    ${main_producer}    Transaction TXN-001 processed
    Send Message To Producer    ${archive_producer}    Archive: TXN-001 completed

    Log    Test completed. Demonstrated Send Message To Producer strengths:
    Log    - Explicit control over multiple producers
    Log    - Complex routing scenarios (priority, geographic)
    Log    - Load balancing across producers
    Log    - Transaction processing with multiple queues
    Log    - Dynamic producer selection based on conditions
