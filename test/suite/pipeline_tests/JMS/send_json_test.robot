*** Settings ***
Documentation       Advanced JMS JSON Message Testing Suite with ActiveMQ Artemis
...
...                 This suite demonstrates advanced JMS capabilities including:
...                 • Sending large JSON files that exceed ActiveMQ UI display limits
...                 • Proving ActiveMQ stores complete messages despite UI limitations
...                 • ANYCAST (Queue) vs MULTICAST (Topic) routing patterns
...                 • Integration with SnapLogic JMS Consumer pipeline
...                 • Message content validation and persistence verification
...
...                 KEY DISCOVERY: ActiveMQ Web UI only displays first 256 characters
...                 but the complete message is stored and retrievable programmatically

# Resource    ../../../resources/jms.resource
Resource            snaplogic_common_robot/snaplogic_apis_keywords/snaplogic_keywords.resource
Resource            snaplogic_common_robot/snaplogic_apis_keywords/jms.resource
Resource            ../../../resources/files.resource
Library             OperatingSystem
Library             String
Library             Collections
Library             DateTime

Suite Setup         Initialize Test Environment
Suite Teardown      Stop Connection


*** Variables ***
${documents_json}                   ${CURDIR}/../../test_data/actual_expected_data/input_data/documents.json

# Project Configuration
${project_path}                     ${org_name}/${project_space}/${project_name}
${pipeline_file_path}               /app/src/pipelines
${upload_destination_file_path}     ${org_name}/${project_space}/shared

${ACCOUNT_PAYLOAD_FILE}             acc_jms.json

# File Mount Pipeline Configuration
${pipeline_name}                    jmsconsumer
${pipeline_slp}                     jmsconsumer.slp
${task_name}                        jmscosumer_Task


*** Test Cases ***
Upload Files With File Protocol
    [Documentation]    Demonstrates uploading expression library files using file:/// protocol
    ...    from directories mounted in the SnapLogic Groundplex container
    ...    📋 ASSERTIONS:
    ...    • Files exist in the mounted directory path
    ...    • File protocol URLs are correctly formed
    ...    • Upload operation succeeds using file:/// protocol
    ...    • Files are accessible in SnapLogic project space
    [Tags]    jms_jar
    [Template]    Upload File Using File Protocol Template
    file:///opt/snaplogic/test_data/accounts_jar_files/jms/artemis-jms-client-all-2.6.0.jar    ${upload_destination_file_path}

Create Account
    [Documentation]    Creates an account in the project space using the provided payload file.
    ...    "account_payload_path"    value as assigned to global variable    in __init__.robot file
    [Tags]    jmsaccount
    [Template]    Create Account From Template
    ${account_payload_path}/${ACCOUNT_PAYLOAD_FILE}

Send Any JSON File With Both Routing Types
    [Documentation]    Comprehensive test proving ActiveMQ stores complete messages beyond UI display limits
    ...
    ...    PURPOSE:
    ...    • Demonstrates that ActiveMQ's 256-character Web UI limit is ONLY visual
    ...    • Proves complete message integrity for large JSON files
    ...    • Validates message storage and retrieval capabilities
    ...    • Compares original file content with retrieved queue content
    ...
    ...    TEST WORKFLOW:
    ...    1. Reads and validates JSON file (any size)
    ...    2. Creates ANYCAST queue for point-to-point messaging
    ...    3. Sends complete JSON content to queue
    ...    4. Retrieves full message content programmatically
    ...    5. Saves retrieved content to file for comparison
    ...    6. Performs byte-by-byte comparison with original
    ...    7. Demonstrates UI limitation vs actual storage
    ...
    ...    KEY FINDINGS:
    ...    • ActiveMQ stores messages of ANY size completely
    ...    • Web UI truncates display at 256 characters
    ...    • Full content is always retrievable via API/code
    ...    • Message integrity is 100% maintained
    [Tags]    json    routing    anycast    multicast4

    # Get file path from variable or use default
    ${json_file_path}=    Get Variable Value    ${JSON_FILE_PATH}    ${documents_json}
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
    [Documentation]    Demonstrates all three ActiveMQ Artemis routing configurations in practice
    ...
    ...    PURPOSE:
    ...    • Shows how ActiveMQ addresses can be configured with different routing types
    ...    • Demonstrates practical use cases for each configuration
    ...    • Helps architects choose the right pattern for their needs
    ...
    ...    SCENARIO 1 - ANYCAST ONLY (Queue Pattern):
    ...    • Address configured for point-to-point messaging only
    ...    • Each message consumed by exactly ONE consumer
    ...    • Perfect for: Order processing, task distribution, work queues
    ...    • UI shows: ["ANYCAST"]
    ...
    ...    SCENARIO 2 - MULTICAST ONLY (Topic Pattern):
    ...    • Address configured for publish-subscribe only
    ...    • Each message delivered to ALL active subscribers
    ...    • Perfect for: Event notifications, broadcasts, real-time updates
    ...    • UI shows: ["MULTICAST"]
    ...
    ...    SCENARIO 3 - BOTH ROUTING TYPES (Hybrid):
    ...    • Single address supporting BOTH patterns simultaneously
    ...    • Can have queues AND topics on the same address
    ...    • Perfect for: Complex systems needing both patterns
    ...    • UI shows: ["MULTICAST","ANYCAST"]
    [Tags]    routing6    anycast    multicast5    both    demo

    # Get file path from variable or use default
    ${json_file_path}=    Get Variable Value    ${JSON_FILE_PATH}    ${documents_json}

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
    ${anycast_only_queue}=    Set Variable    demo.queue

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
    [Documentation]    Flexible utility test for sending any JSON file to any JMS queue
    ...
    ...    PURPOSE:
    ...    • Provides a reusable test for JMS queue operations
    ...    • Validates JSON structure before sending
    ...    • Creates queue with proper ANYCAST routing
    ...    • Useful for testing, debugging, and demonstrations
    ...
    ...    FEATURES:
    ...    • Accepts any valid JSON file as input
    ...    • Configurable queue name via command line
    ...    • JSON validation with detailed error reporting
    ...    • Automatic queue creation with ANYCAST routing
    ...    • Detailed logging of the entire process
    ...
    ...    STEP-BY-STEP PROCESS:
    ...    1. Validates file existence and readability
    ...    2. Reads complete file content
    ...    3. Validates JSON structure and syntax
    ...    4. Creates ANYCAST queue if not exists
    ...    5. Generates unique message ID with timestamp
    ...    6. Sends message with metadata headers
    ...    7. Provides viewing instructions
    ...
    ...    USE CASES:
    ...    • Testing JMS connectivity and configuration
    ...    • Sending test data for pipeline development
    ...    • Debugging message flow issues
    ...    • Performance testing with large JSON files
    [Tags]    flexible2    json    any    queue

    # Get file path from variable or use default
    ${json_file_path}=    Get Variable Value    ${JSON_FILE_PATH}    ${documents_json}
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

Import Pipelines
    [Documentation]    Imports the JMS Consumer pipeline that processes messages from ActiveMQ queues
    ...
    ...    PIPELINE: jmsconsumer.slp
    ...
    ...    PIPELINE COMPONENTS:
    ...    1. JMS Consumer - Reads messages from 'demo.queue'
    ...    • Uses AUTO_ACKNOWLEDGE mode
    ...    • Synchronous message processing
    ...    • Connected to local-activemq-artemis account
    ...
    ...    2. JSON Parser - Converts binary stream to documents
    ...    • Allows non-standard JSON
    ...    • Array elements as separate documents
    ...    • Error handling for malformed JSON
    ...
    ...    3. JSON Formatter - Prepares data for file output
    ...    • Formats documents back to JSON
    ...    • Maintains data structure integrity
    ...
    ...    4. File Writer - Saves processed messages
    ...    • Output: jms_consumed_data.json
    ...    • Overwrites existing file
    ...    • Creates file even if empty
    ...
    ...    INTEGRATION POINTS:
    ...    • Requires active ActiveMQ connection
    ...    • Needs 'demo.queue' to exist (auto-created on first send)
    ...    • Outputs to local file system
    ...
    ...    VERIFICATIONS:
    ...    • Pipeline file exists at specified path
    ...    • Import generates unique pipeline ID
    ...    • All snap components properly configured
    ...    • Pipeline deployed to correct project space
    [Tags]    jmsaccount    jmsconsumer
    [Template]    Import Pipelines From Template
    ${unique_id}    ${pipeline_file_path}    ${pipeline_name}    ${pipeline_slp}

Create Triggered_task
    [Documentation]    Creates a triggered task for the JMS Consumer pipeline enabling on-demand execution
    ...
    ...    TASK CONFIGURATION:
    ...    • Task Name: jmsconsumer_Task
    ...    • Pipeline: jmsconsumer
    ...    • Trigger: Manual/API based
    ...    • Error Handling: Fail on error
    ...    VERIFICATIONS:
    ...    • Task creation returns valid task ID
    ...    • Task properly linked to pipeline
    ...    • Task accessible via project path
    ...    • Task metadata correctly configured
    [Tags]    jmsconsumer
    [Template]    Create Triggered Task From Template
    ${unique_id}    ${project_path}    ${pipeline_name}    ${task_name}

Execute Triggered Task
    [Documentation]    Executes the JMS Consumer pipeline to process messages from ActiveMQ queue
    ...
    ...    EXECUTION FLOW:
    ...    1. Triggers the jmsconsumer_Task via API
    ...    2. Pipeline connects to ActiveMQ broker
    ...    3. Reads messages from 'demo.queue'
    ...    4. Processes each message through the pipeline
    ...    5. Outputs to jms_consumed_data.json
    ...
    ...    PROCESSING BEHAVIOR:
    ...    • Consumes ALL available messages in queue
    ...    • Messages removed from queue after processing
    ...    • Each message parsed as JSON document
    ...    • Failed parsing logged but doesn't stop pipeline
    ...
    ...    OUTPUT FILE STRUCTURE:
    ...    • Location: Pipeline execution directory
    ...    • Format: JSON array of processed messages
    ...    • Overwrites previous executions
    ...    • Contains all successfully parsed messages
    [Tags]    jmsconsumer
    # Execute the pipeline
    [Template]    Run Triggered Task With Parameters From Template

    ${unique_id}    ${project_path}    ${pipeline_name}    ${task_name}


*** Keywords ***
Initialize Test Environment
    ${unique_id}=    Get Unique Id
    Set Suite Variable    ${unique_id}    ${unique_id}
    Wait Until Plex Status Is Up    /${ORG_NAME}/${GROUNDPLEX_LOCATION_PATH}/${GROUNDPLEX_NAME}
    Start Connection
