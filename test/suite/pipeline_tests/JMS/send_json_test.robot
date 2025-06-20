*** Settings ***
Documentation       Demo Test - Send SAP IDoc JSON as Queue and Topic Messages

# Resource    ../../../resources/jms.resource
Resource            snaplogic_common_robot/snaplogic_apis_keywords/snaplogic_keywords.resource
Resource            snaplogic_common_robot/snaplogic_apis_keywords/jms.resource
Resource            ../../../resources/files.resource
Library             OperatingSystem
Library             String
Library             Collections
Library             DateTime

Suite Setup         Start Connection
Suite Teardown      Stop Connection


*** Variables ***
${SAP_IDOC_JSON_PATH}       ${CURDIR}/../../test_data/actual_expected_data/input_data/SAP_IDoc Read output0.json
# ${SAP_IDOC_JSON_PATH}    ${CURDIR}/../../test_data/actual_expected_data/input_data/employees.json


*** Test Cases ***
Send Any JSON File With Both Routing Types
    [Documentation]    Send any JSON file using both ANYCAST and MULTICAST routing
    ...    Demonstrates the difference between routing types
    ...    Example:
    ...    robot -v JSON_FILE_PATH:/path/to/file.json -t "Test Send Any JSON File With Both Routing Types" demo_test.robot
    [Tags]    json    routing    anycast    multicast4

    # Get file path from variable or use default
    ${json_file_path}=    Get Variable Value    ${JSON_FILE_PATH}    ${SAP_IDOC_JSON_PATH}
    ${base_name}=    Get Variable Value    ${BASE_NAME}    test.routing

    Log    \n=== SEND JSON WITH BOTH ROUTING TYPES ===    console=yes
    Log    File: ${json_file_path}    console=yes

    # Read and validate JSON file
    File Should Exist    ${json_file_path}
    ${json_content}=    Get File    ${json_file_path}
    ${file_name}=    Evaluate    os.path.basename("${json_file_path}")    os
    ${content_length}=    Get Length    ${json_content}

    # Validate JSON
    ${json_data}=    Evaluate    json.loads($json_content)    json
    Log    ✅ Valid JSON file: ${file_name} (${content_length} chars)    console=yes

    # === ANYCAST ROUTING ===
    Log    \n=== 1. ANYCAST ROUTING (Queue Pattern) ===    console=yes
    ${anycast_address}=    Set Variable    ${base_name}.anycast.address
    ${anycast_queue}=    Set Variable    ${base_name}.anycast.queue

    # Create ANYCAST queue
    ${anycast_dest}=    Create Queue    ${anycast_address}    ${anycast_queue}    ANYCAST
    Log    Created ANYCAST queue: ${anycast_queue}    console=yes

    # Send to ANYCAST
    ${anycast_headers}=    Create Dictionary
    ...    routing-type=ANYCAST
    ...    delivery-pattern=point-to-point
    ...    file=${file_name}
    Send Text Message    ${anycast_dest}    ${json_content}    anycast-msg-001    ${anycast_headers}
    Log    ✅ Sent to ANYCAST - only ONE consumer will receive this    console=yes

    # NEW: Verify full message content
    Log    \n=== VERIFYING FULL MESSAGE CONTENT ===    console=yes

    # Get the full message content from the queue
    Log    \nRetrieving full message content from queue...    console=yes
    ${queue_content}    ${msg_length}=    Get Full Message Content From Queue    ${anycast_dest}
    Log    Message length in queue: ${msg_length} chars    console=yes

    # Verify the original JSON length matches what's in the queue
    Should Be Equal As Numbers    ${msg_length}    ${content_length}
    ...    msg=Queue message length (${msg_length}) doesn't match sent message length (${content_length})
    Log    ✅ Message length verified!    console=yes

    # Save the queue content to file
    ${output_dir}=    Set Variable    ${CURDIR}/../../test_data/actual_expected_data/actual_jms_content
    ${saved_file}=    Save Queue Content To File    ${queue_content}    ${file_name}    ${output_dir}
    Log    \n💾 Queue content saved to file for verification    console=yes

    # Compare the original file with the file saved from queue
    Log    \n=== COMPARING ORIGINAL FILE WITH QUEUE CONTENT ===    console=yes
    ${base_name}=    Evaluate    os.path.splitext("${file_name}")[0]    os
    ${queue_file_path}=    Set Variable    ${output_dir}/${base_name}_from_queue.json

    # Use Compare JSON Files Template with all required arguments
    ${comparison_result}=    Compare JSON Files Template
    ...    ${json_file_path}    # file1_path
    ...    ${queue_file_path}    # file2_path
    ...    ${TRUE}    # ignore_order
    ...    ${TRUE}    # show_details
    ...    IDENTICAL    # expected_status

    Log    ✅ Original file and queue content are IDENTICAL!    console=yes
    Log    Comparison result: ${comparison_result}    console=yes

    # Display the actual content from the queue
    Log    \n=== ACTUAL MESSAGE CONTENT FROM QUEUE ===    console=yes
    Log    First 500 characters:    console=yes
    ${preview}=    Get Substring    ${queue_content}    0    500
    Log    ${preview}...    console=yes

    # Display what the UI shows
    Log    \n=== WHAT ACTIVEMQ UI SHOWS ===    console=yes
    ${ui_preview}=    Get Substring    ${queue_content}    0    256
    Log    ${ui_preview}...    console=yes

    # Show results
    Log    \n=== RESULTS ===    console=yes
    Log    Original JSON file: ${content_length} chars    console=yes
    Log    Message sent: ${content_length} chars    console=yes
    Log    Message in queue: ${msg_length} chars    console=yes
    Log    Saved to: ${saved_file}    console=yes

    Log    \n📊 KEY FINDINGS:    console=yes
    Log    - ActiveMQ successfully stores the full ${content_length} character message    console=yes
    Log    - The Web UI only displays the first 256 characters    console=yes
    IF    ${content_length} > 256
        ${missing_in_ui}=    Evaluate    ${content_length} - 256
        Log    - UI shows only 256 of ${content_length} chars (missing ${missing_in_ui} chars)    console=yes
        ${ui_percentage}=    Evaluate    round(256.0 / ${content_length} * 100, 1)
        Log    - That's only ${ui_percentage}% of the actual message!    console=yes
    END
    Log    - The 256 char limit is ONLY a UI display limitation    console=yes
    Log    - Full content saved to: actual_jms_content/${file_name}    console=yes
    Log    \n✅ Test proves ActiveMQ stores complete messages beyond UI limit!    console=yes

Test Send JSON With Three Routing Scenarios
    [Documentation]    Demonstrates three routing scenarios:
    ...    1. ANYCAST only address
    ...    2. MULTICAST only address
    ...    3. BOTH routing types on same address
    ...    Example:
    ...    robot -v JSON_FILE_PATH:/path/to/file.json -t "Test Send JSON With Three Routing Scenarios" demo_test.robot
    [Tags]    routing6    anycast    multicast5    both    demo

    # Get file path from variable or use default
    ${json_file_path}=    Get Variable Value    ${JSON_FILE_PATH}    ${SAP_IDOC_JSON_PATH}

    Log    \n=== THREE ROUTING SCENARIOS DEMO ===    console=yes
    Log    File: ${json_file_path}    console=yes

    # Read and validate JSON file
    File Should Exist    ${json_file_path}
    ${json_content}=    Get File    ${json_file_path}
    ${file_name}=    Evaluate    os.path.basename("${json_file_path}")    os
    ${content_length}=    Get Length    ${json_content}
    ${json_data}=    Evaluate    json.loads($json_content)    json
    Log    ✅ Valid JSON file: ${file_name} (${content_length} chars)    console=yes

    # === SCENARIO 1: ANYCAST ONLY ===
    Log    \n=== SCENARIO 1: ANYCAST ONLY ADDRESS ===    console=yes
    Log    This address will ONLY support point-to-point delivery    console=yes

    ${anycast_only_address}=    Set Variable    demo.anycast.only.address
    ${anycast_only_queue}=    Set Variable    demo.anycast.only.queue

    # Create queue with ANYCAST routing
    ${anycast_dest}=    Create Queue    ${anycast_only_address}    ${anycast_only_queue}    ANYCAST
    Log    Created ANYCAST-only queue: ${anycast_only_queue}    console=yes

    # Send to ANYCAST-only queue
    ${anycast_headers}=    Create Dictionary
    ...    scenario=anycast-only
    ...    routing-type=ANYCAST
    ...    delivery=point-to-point

    Send Text Message    ${anycast_dest}    ${json_content}    anycast-only-msg-001    ${anycast_headers}
    Log    ✅ Sent to ANYCAST-only address    console=yes

    # === SCENARIO 2: MULTICAST ONLY ===
    Log    \n=== SCENARIO 2: MULTICAST ONLY ADDRESS ===    console=yes
    Log    This address will ONLY support publish-subscribe delivery    console=yes

    ${multicast_only_address}=    Set Variable    demo.multicast.only.address
    ${multicast_only_topic}=    Set Variable    demo.multicast.only.topic

    # Create topic with MULTICAST routing
    ${multicast_dest}=    Create Topic    ${multicast_only_address}    ${multicast_only_topic}
    Log    Created MULTICAST-only topic: ${multicast_only_topic}    console=yes

    # Send to MULTICAST-only topic
    ${multicast_headers}=    Create Dictionary
    ...    scenario=multicast-only
    ...    routing-type=MULTICAST
    ...    delivery=publish-subscribe

    Send Text Message    ${multicast_dest}    ${json_content}    multicast-only-msg-001    ${multicast_headers}
    Log    ✅ Sent to MULTICAST-only address    console=yes

    # === SCENARIO 3: BOTH ROUTING TYPES ===
    Log    \n=== SCENARIO 3: ADDRESS WITH BOTH ROUTING TYPES ===    console=yes
    Log    This address supports BOTH point-to-point AND publish-subscribe    console=yes

    ${both_address}=    Set Variable    demo.both.routing.address

    # Create ANYCAST queue on the address
    ${both_anycast_queue}=    Set Variable    demo.both.anycast.queue
    ${both_anycast_dest}=    Create Queue    ${both_address}    ${both_anycast_queue}    ANYCAST
    Log    Created ANYCAST queue on 'both' address: ${both_anycast_queue}    console=yes

    # Create MULTICAST topic on the SAME address
    ${both_multicast_topic}=    Set Variable    demo.both.multicast.topic
    ${both_multicast_dest}=    Create Topic    ${both_address}    ${both_multicast_topic}
    Log    Created MULTICAST topic on 'both' address: ${both_multicast_topic}    console=yes

    # Send to ANYCAST queue on 'both' address
    ${both_anycast_headers}=    Create Dictionary
    ...    scenario=both-anycast
    ...    routing-type=ANYCAST
    ...    address-type=both

    Send Text Message    ${both_anycast_dest}    ${json_content}    both-anycast-msg-001    ${both_anycast_headers}
    Log    ✅ Sent to ANYCAST queue on 'both' address    console=yes

    # Send to MULTICAST topic on 'both' address
    ${both_multicast_headers}=    Create Dictionary
    ...    scenario=both-multicast
    ...    routing-type=MULTICAST
    ...    address-type=both

    Send Text Message
    ...    ${both_multicast_dest}
    ...    ${json_content}
    ...    both-multicast-msg-001
    ...    ${both_multicast_headers}
    Log    ✅ Sent to MULTICAST topic on 'both' address    console=yes

    # === SUMMARY ===
    Log    \n=== ROUTING SCENARIOS SUMMARY ===    console=yes

    Log    \n1️⃣ ANYCAST ONLY:    console=yes
    Log    Address: ${anycast_only_address}    console=yes
    Log    Queue: ${anycast_only_queue}    console=yes
    Log    - Only supports point-to-point delivery    console=yes
    Log    - View: python view_messages.py ${anycast_only_queue}    console=yes

    Log    \n2️⃣ MULTICAST ONLY:    console=yes
    Log    Address: ${multicast_only_address}    console=yes
    Log    Topic: ${multicast_only_topic}    console=yes
    Log    - Only supports publish-subscribe    console=yes
    Log    - Messages visible only to active subscribers    console=yes

    Log    \n3️⃣ BOTH ROUTING TYPES:    console=yes
    Log    Address: ${both_address}    console=yes
    Log    ANYCAST Queue: ${both_anycast_queue}    console=yes
    Log    MULTICAST Topic: ${both_multicast_topic}    console=yes
    Log    - Same address supports both patterns!    console=yes
    Log    - View queue: python view_messages.py ${both_anycast_queue}    console=yes

    Log    \n💡 In the Web UI, you'll see:    console=yes
    Log    - ${anycast_only_address} with ["ANYCAST"]    console=yes
    Log    - ${multicast_only_address} with ["MULTICAST"]    console=yes
    Log    - ${both_address} with ["MULTICAST","ANYCAST"]    console=yes

    Log    \n✅ Successfully demonstrated all three routing scenarios!    console=yes

Test Send Any JSON File To Queue
    [Documentation]    Flexible test - Send any JSON file to a queue
    ...    Can be run with custom file path and queue name
    ...    Examples:
    ...    robot -v JSON_FILE_PATH:/path/to/file.json -t "Test Send Any JSON File To Queue" demo_test.robot
    ...    robot -v QUEUE_NAME:my.custom.queue -t "Test Send Any JSON File To Queue" demo_test.robot
    [Tags]    flexible2    json    any    queue

    # Get file path from variable or use default
    ${json_file_path}=    Get Variable Value    ${JSON_FILE_PATH}    ${SAP_IDOC_JSON_PATH}
    ${queue_name}=    Get Variable Value    ${QUEUE_NAME}    test.json.queue

    Log    \n=== SEND ANY JSON FILE TO QUEUE ===    console=yes
    Log    File: ${json_file_path}    console=yes
    Log    Queue: ${queue_name}    console=yes

    # Step 1: Verify file exists
    Log    \nStep 1: Checking if file exists...    console=yes
    File Should Exist    ${json_file_path}    File not found: ${json_file_path}
    ${file_name}=    Evaluate    os.path.basename("${json_file_path}")    os
    Log    ✅ File found: ${file_name}    console=yes

    # Step 2: Read the JSON file
    Log    \nStep 2: Reading JSON file...    console=yes
    ${json_content}=    Get File    ${json_file_path}
    ${content_length}=    Get Length    ${json_content}
    Log    ✅ File read: ${content_length} characters    console=yes

    # Step 3: Validate JSON
    Log    \nStep 3: Validating JSON...    console=yes
    TRY
        ${json_data}=    Evaluate    json.loads($json_content)    json
        ${is_valid}=    Set Variable    True
        Log    ✅ Valid JSON structure    console=yes

        # Try to determine JSON type
        ${json_type}=    Evaluate    type($json_data).__name__
        Log    JSON type: ${json_type}    console=yes

        # Show preview of JSON structure
        ${preview}=    Evaluate
        ...    json.dumps($json_data, indent=2)[:500] + "..." if len(json.dumps($json_data)) > 500 else json.dumps($json_data, indent=2)
        ...    json
        Log    JSON Preview:\n${preview}    console=yes
    EXCEPT    AS    ${error}
        Log    ❌ Invalid JSON: ${error}    console=yes
        Fail    File contains invalid JSON
    END

    # Step 4: Create queue destination
    Log    \nStep 4: Creating ANYCAST queue destination...    console=yes
    # Use explicit ANYCAST routing
    ${queue_address}=    Set Variable    ${queue_name}.address
    ${queue_dest}=    Create Queue    ${queue_address}    ${queue_name}    ANYCAST
    Log    ✅ ANYCAST Queue created: ${queue_name}    console=yes
    Log    Address: ${queue_address}, Routing: ANYCAST    console=yes

    # Step 5: Generate message ID and headers
    ${timestamp}=    Get Current Date    result_format=epoch
    ${message_id}=    Set Variable    anycast-json-msg-${timestamp}

    # Add routing type to headers
    ${headers}=    Create Dictionary
    ...    routing-type=ANYCAST
    ...    file-name=${file_name}
    ...    content-size=${content_length}

    # Step 6: Send JSON to ANYCAST queue
    Log    \nStep 5: Sending JSON to ANYCAST queue...    console=yes
    Send Text Message    ${queue_dest}    ${json_content}    ${message_id}    ${headers}
    Log    ✅ Message sent successfully to ANYCAST queue!    console=yes

    # Step 7: Display summary
    Log    \n=== SUMMARY ===    console=yes
    Log    File: ${file_name}    console=yes
    Log    Queue: ${queue_name}    console=yes
    Log    Message ID: ${message_id}    console=yes
    Log    Size: ${content_length} characters    console=yes

    Log    \n📋 TO VIEW THE MESSAGE:    console=yes
    Log    1. Web UI: http://localhost:8161/console → Queues → ${queue_name}    console=yes
    Log    2. Python: python view_messages.py ${queue_name}    console=yes

    Log    \n💡 TIP: Run with custom file/queue:    console=yes
    Log
    ...    robot -v JSON_FILE_PATH:/your/file.json -v QUEUE_NAME:your.queue -t "Test Send Any JSON File To Queue" demo_test.robot
    ...    console=yes

    Log    \n✅ Test completed successfully!    console=yes
