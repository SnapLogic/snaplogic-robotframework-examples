*** Settings ***
Documentation       Bulk generates Knowledge Articles in ServiceNow for AWS Q connector testing.
...                 Uses the ServiceNow REST API via shared keywords in servicenow.resource.
...
...                 Baseline scale: 50 articles, spread across 10 categories with title/body variety.
...                 First 10 articles also get a sample attachment.

Resource            ../../../resources/servicenow/servicenow.resource
Library             Collections
Library             String

Suite Setup         Connect To ServiceNow


*** Variables ***
# Volume controls
${ARTICLE_COUNT}      10000
${ATTACHMENT_COUNT}   2000

# Prefix added to every generated record's title — makes it easy to filter,
# identify, and cleanly delete robot-generated test data later.
${DATA_PREFIX}        ROBOT-

# Sample attachment path
${ATTACHMENT_PATH}    ${CURDIR}/../../test_data/actual_expected_data/input_data/servicenow/sample_attachment.txt

# Category sys_ids — spread articles across these for realistic variety
@{CATEGORY_SYS_IDS}
...    %{SERVICENOW_CATEGORY_FAQ_SYS_ID}
...    %{SERVICENOW_CATEGORY_HOW_TO_SYS_ID}
...    %{SERVICENOW_CATEGORY_EMAIL_SYS_ID}
...    %{SERVICENOW_CATEGORY_VPN_SYS_ID}
...    %{SERVICENOW_CATEGORY_APPLE_SYS_ID}
...    %{SERVICENOW_CATEGORY_JAVA_SYS_ID}
...    %{SERVICENOW_CATEGORY_SECURITY_SYS_ID}
...    %{SERVICENOW_CATEGORY_POLICIES_SYS_ID}
...    %{SERVICENOW_CATEGORY_WINDOWS_SYS_ID}
...    %{SERVICENOW_CATEGORY_IE_SYS_ID}

@{CATEGORY_NAMES}
...    FAQ    How To    Email    VPN    Apple    Java    Security    Policies    Windows    IE

# Title templates — combined with topics for variety
@{TITLE_TEMPLATES}
...    How to configure
...    Troubleshooting
...    Setup guide for
...    Best practices for
...    FAQ about
...    Common issues with
...    Quick reference for
...    Step-by-step
...    Tips and tricks for
...    Overview of

# Topics — combined with templates
@{TOPICS}
...    VPN access
...    email setup
...    Windows 10
...    password reset
...    laptop request
...    printer setup
...    multi-factor authentication
...    file sharing
...    remote desktop
...    software installation
...    Apple devices
...    backup and recovery
...    network configuration
...    Java runtime
...    security policies
...    Internet Explorer
...    Microsoft Office
...    Outlook calendar
...    mobile devices
...    operating system updates

# Body templates
@{BODY_TEMPLATES}
...    <p>This article describes the standard procedure for {topic}. Follow each step in order. If you encounter issues, contact the IT service desk via the Service Catalog.</p><ul><li>Step 1: Verify prerequisites</li><li>Step 2: Apply the configuration</li><li>Step 3: Test and validate</li></ul>
...    <p>{topic} is a commonly-requested area. This guide covers the most frequent questions and provides links to deeper documentation. Last reviewed by IT Operations.</p><p>For escalations, open a ticket in the Service Catalog.</p>
...    <p>Below is a quick reference covering {topic}. The intended audience is end users who need a fast answer without reading full documentation.</p><ol><li>Identify the symptom</li><li>Apply the suggested fix</li><li>Validate the resolution</li></ol>
...    <p>Many employees have asked about {topic}. This article consolidates the standard answer used by IT to reduce ticket volume. Updated for the current fiscal year.</p>
...    <p>This document explains {topic} in terms suitable for a general audience. Technical details are provided in linked deep-dive articles for engineers who need the full picture.</p>


*** Test Cases ***
Generate Baseline Knowledge Articles With Variety
    [Documentation]    Creates ${ARTICLE_COUNT} Knowledge Articles spread across 10 categories
    ...                with title and body variety. First ${ATTACHMENT_COUNT} articles get
    ...                a sample attachment.
    ...
    ...                Articles are created in draft state (ServiceNow blocks API publish).
    [Tags]    servicenow    data-generation    kb-articles    baseline

    ${num_categories}=    Get Length    ${CATEGORY_SYS_IDS}
    ${num_titles}=        Get Length    ${TITLE_TEMPLATES}
    ${num_topics}=        Get Length    ${TOPICS}
    ${num_bodies}=        Get Length    ${BODY_TEMPLATES}

    @{created_ids}=    Create List
    @{attached_ids}=   Create List

    FOR    ${i}    IN RANGE    0    ${ARTICLE_COUNT}
        ${cat_idx}=     Evaluate    ${i} % ${num_categories}
        ${title_idx}=   Evaluate    ${i} % ${num_titles}
        ${topic_idx}=   Evaluate    ${i} % ${num_topics}
        ${body_idx}=    Evaluate    ${i} % ${num_bodies}

        ${title_template}=    Set Variable    ${TITLE_TEMPLATES}[${title_idx}]
        ${topic}=             Set Variable    ${TOPICS}[${topic_idx}]
        ${body_template}=     Set Variable    ${BODY_TEMPLATES}[${body_idx}]
        ${cat_sys_id}=        Set Variable    ${CATEGORY_SYS_IDS}[${cat_idx}]
        ${cat_name}=          Set Variable    ${CATEGORY_NAMES}[${cat_idx}]

        ${title}=    Set Variable    ${DATA_PREFIX} ${title_template} ${topic} (${cat_name} #${i + 1})
        ${body}=     Replace String    ${body_template}    {topic}    ${topic}

        ${sys_id}=   Create Knowledge Article    ${title}    ${body}
        ...    category_sys_id=${cat_sys_id}
        Append To List    ${created_ids}    ${sys_id}

        # Attach a file to the first ${ATTACHMENT_COUNT} articles only
        IF    ${i} < ${ATTACHMENT_COUNT}
            Attach File To Record    kb_knowledge    ${sys_id}    ${ATTACHMENT_PATH}    text/plain
            Append To List    ${attached_ids}    ${sys_id}
        END
    END

    Length Should Be    ${created_ids}     ${ARTICLE_COUNT}
    Length Should Be    ${attached_ids}    ${ATTACHMENT_COUNT}
    Log    Created ${ARTICLE_COUNT} articles, ${ATTACHMENT_COUNT} with attachments.
    Log    Spread across categories: ${CATEGORY_NAMES}
