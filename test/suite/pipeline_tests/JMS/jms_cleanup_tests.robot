*** Settings ***
Documentation       JMS Cleanup Tests - Delete all addresses and queues except system ones

# Resource    ../../../resources/jms.resource
Resource            snaplogic_common_robot/snaplogic_apis_keywords/snaplogic_keywords.resource
Resource            snaplogic_common_robot/snaplogic_apis_keywords/jms.resource

Suite Setup         Connect To Artemis
Suite Teardown      Disconnect From Artemis


*** Variables ***
${JMS_HOST}                 activemq
${JMS_PORT}                 61613
${JMS_MANAGEMENT_PORT}      8161
${JMS_USERNAME}             admin
${JMS_PASSWORD}             admin
${JMS_ENHANCED_FEATURES}    True


*** Test Cases ***
Test Delete All Except System Addresses
    [Documentation]    Delete all user-created addresses and queues, keeping only system addresses
    [Tags]    cleanup

    Log    ⚠️ WARNING: This test will DELETE ALL user addresses and queues!    level=WARN    console=yes

    # First, create some test data to ensure there's something to clean
    Log    Creating test addresses for cleanup demonstration...    console=yes
    Create Queue    test.cleanup.queue1
    Create Queue    test.cleanup.queue2
    Create Queue    user.data.queue
    Create Topic    test.cleanup.topic

    # Get initial state
    ${initial_addresses}=    Get All Addresses
    ${initial_count}=    Get Length    ${initial_addresses}
    Log    Initial address count: ${initial_count}    console=yes

    # Get summary before cleanup
    ${before_summary}=    Get Cleanup Summary
    Log    Before cleanup:    console=yes
    Log    - Total addresses: ${before_summary}[total]    console=yes
    Log    - System addresses: ${before_summary}[system_count]    console=yes
    Log    - Test addresses: ${before_summary}[test_count]    console=yes
    Log    - User addresses: ${before_summary}[user_count]    console=yes

    # List system addresses that will be preserved
    Log    \nSystem addresses to preserve:    console=yes
    FOR    ${addr}    IN    @{before_summary}[system_addresses]
        Log    ✓ ${addr}    console=yes
    END

    # Only run cleanup if there are addresses to clean
    IF    ${before_summary}[user_count] > 0 or ${before_summary}[test_count] > 0
        # Perform the actual cleanup
        Log    \n🗑️ Deleting all addresses except system ones...    console=yes
        ${cleanup_result}=    Delete All Except System Addresses

        # Get final state
        ${final_addresses}=    Get All Addresses
        ${final_count}=    Get Length    ${final_addresses}
        ${after_summary}=    Get Cleanup Summary

        # Calculate deleted count
        ${deleted_count}=    Evaluate    ${initial_count} - ${final_count}

        Log    \n📊 Cleanup Results:    console=yes
        Log    - Initial addresses: ${initial_count}    console=yes
        Log    - Final addresses: ${final_count}    console=yes
        Log    - Deleted: ${deleted_count}    console=yes

        # Verify only system addresses remain
        Log    \nVerifying cleanup results...    console=yes
        Should Be Equal As Numbers    ${after_summary}[user_count]    0    User addresses should be deleted
        Should Be Equal As Numbers    ${after_summary}[test_count]    0    Test addresses should be deleted

        Log    ✅ Cleanup successful! Deleted ${deleted_count} non-system addresses.    console=yes
    ELSE
        Log    No user or test addresses found. Only system addresses exist (or broker is empty).    console=yes
        ${after_summary}=    Set Variable    ${before_summary}
    END

    # For empty brokers, just pass the test
    IF    ${after_summary}[total] == 0
        Log    Broker is empty (no addresses at all). This is OK for a fresh installation.    console=yes
        Pass Execution    Empty broker - nothing to cleanup
    END

    # Otherwise verify system addresses exist
    IF    ${after_summary}[system_count] > 0
        Log    ✅ ${after_summary}[system_count] system addresses preserved.    console=yes
    ELSE
        Log    NOTE: No system addresses found. This might be normal for your ActiveMQ setup.    console=yes
    END

Test Safe Cleanup - Test Addresses Only
    [Documentation]    Safely cleanup only test-related addresses, preserving system and user addresses
    [Tags]    cleanup

    Log    Running safe cleanup of test addresses only...    console=yes

    # Get initial state
    ${before_summary}=    Get Cleanup Summary
    Log    Before cleanup: ${before_summary}[test_count] test addresses found    console=yes

    # Cleanup test data only
    ${result}=    Cleanup Test Addresses

    # Get final state
    ${after_summary}=    Get Cleanup Summary
    ${cleaned_count}=    Evaluate    ${before_summary}[test_count] - ${after_summary}[test_count]

    Log    Cleaned up ${cleaned_count} test addresses    console=yes
    Log    Remaining test addresses: ${after_summary}[test_count]    console=yes

    # Verify system addresses were not affected
    Should Be Equal As Numbers    ${after_summary}[system_count]    ${before_summary}[system_count]
    ...    System addresses should not be affected

Test Cleanup With Custom Patterns
    [Documentation]    Cleanup addresses matching specific patterns
    [Tags]    cleanup

    # First, create some test addresses to cleanup
    Log    Creating test addresses...    console=yes
    Create Queue    xml.test.queue1
    Create Queue    xml.test.queue2
    Create Queue    custom.pattern.queue
    Create Topic    broadcast.test.topic

    # Define cleanup patterns
    @{patterns}=    Create List    ^xml\\.    ^custom\\.pattern    \\.test\\.

    # List what will be deleted
    ${matching}=    List Addresses Matching Patterns    ${patterns}
    ${match_count}=    Get Length    ${matching}
    Log    Found ${match_count} addresses matching patterns:    console=yes
    FOR    ${addr}    IN    @{matching}
        Log    - ${addr}    console=yes
    END

    # Cleanup matching patterns
    ${result}=    Cleanup Specific Patterns    ${patterns}

    # Verify cleanup
    ${after_matching}=    List Addresses Matching Patterns    ${patterns}
    ${after_count}=    Get Length    ${after_matching}
    Should Be True    ${after_count} < ${match_count}    Some addresses should have been deleted

Test List All Addresses
    [Documentation]    List all addresses in the broker for inspection
    [Tags]    list

    ${addresses}=    Get All Addresses
    ${count}=    Get Length    ${addresses}

    Log    \n📋 All Addresses in Broker (${count} total):    console=yes
    FOR    ${addr}    IN    @{addresses}
        Log    - ${addr}    console=yes
    END

    # Get categorized summary
    ${summary}=    Get Cleanup Summary

    Log    \n📊 Address Categories:    console=yes
    Log    System addresses (${summary}[system_count]):    console=yes
    FOR    ${addr}    IN    @{summary}[system_addresses]
        Log    - ${addr}    console=yes
    END

    Log    \nTest addresses (${summary}[test_count]):    console=yes
    FOR    ${addr}    IN    @{summary}[test_addresses]
        Log    - ${addr}    console=yes
    END

    Log    \nUser addresses (${summary}[user_count]):    console=yes
    FOR    ${addr}    IN    @{summary}[user_addresses]
        Log    - ${addr}    console=yes
    END

Test Verify System Addresses Exist
    [Documentation]    Verify that critical system addresses are present
    [Tags]    verify    system

    ${addresses}=    Get All Addresses

    # Check for critical system addresses
    ${has_dlq}=    Run Keyword And Return Status
    ...    Should Contain    ${addresses}    DLQ
    ${has_expiry}=    Run Keyword And Return Status
    ...    Should Contain    ${addresses}    ExpiryQueue

    Log    System address check:    console=yes
    Log    - DLQ present: ${has_dlq}    console=yes
    Log    - ExpiryQueue present: ${has_expiry}    console=yes

    IF    not ${has_dlq}
        Log    ⚠️ WARNING: DLQ system address not found!    level=WARN    console=yes
    END

    IF    not ${has_expiry}
        Log    ⚠️ WARNING: ExpiryQueue system address not found!    level=WARN    console=yes
    END

    Should Be True    ${has_dlq}    DLQ system address must exist
    Should Be True    ${has_expiry}    ExpiryQueue system address must exist
