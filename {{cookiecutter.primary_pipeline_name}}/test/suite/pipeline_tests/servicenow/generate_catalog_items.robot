*** Settings ***
Documentation       Bulk generates Service Catalog items in ServiceNow for AWS Q connector testing.
...                 Uses the ServiceNow REST API via shared keywords in servicenow.resource.
...
...                 Baseline scale: 20 catalog items spread across 7 categories with name variety.

Resource            ../../../resources/servicenow/servicenow.resource
Library             Collections
Library             String

Suite Setup         Connect To ServiceNow


*** Variables ***
${CATALOG_ITEM_COUNT}    5000

# Prefix added to every generated record — makes it easy to filter and clean up
# robot-generated test data later. Keep consistent with generate_kb_articles.robot.
${DATA_PREFIX}           ROBOT-

# Catalog category sys_ids — spread items across these
@{CAT_CATEGORY_SYS_IDS}
...    %{SERVICENOW_SC_CATEGORY_SYS_ID}
...    %{SERVICENOW_SC_CATEGORY_OFFICE_SYS_ID}
...    %{SERVICENOW_SC_CATEGORY_SOFTWARE_SYS_ID}
...    %{SERVICENOW_SC_CATEGORY_LAPTOPS_SYS_ID}
...    %{SERVICENOW_SC_CATEGORY_DESKTOPS_SYS_ID}
...    %{SERVICENOW_SC_CATEGORY_TABLETS_SYS_ID}
...    %{SERVICENOW_SC_CATEGORY_PRINTERS_SYS_ID}

@{CAT_CATEGORY_NAMES}
...    Services    Office    Software    Laptops    Desktops    Tablets    Printers

# Name templates
@{NAME_TEMPLATES}
...    Request a
...    Order a new
...    Standard
...    Bulk order of
...    Premium

# Items
@{ITEM_TYPES}
...    laptop
...    desktop
...    tablet
...    monitor
...    printer
...    keyboard and mouse set
...    headset
...    software license
...    Office 365 subscription
...    VPN access
...    mobile phone
...    docking station
...    external hard drive
...    webcam
...    secondary monitor
...    standing desk
...    chair upgrade
...    audio conferencing kit
...    Mac configuration
...    Windows configuration


*** Test Cases ***
Generate Baseline Service Catalog Items With Variety
    [Documentation]    Creates ${CATALOG_ITEM_COUNT} catalog items spread across 7 categories
    ...                with name variety. No attachments on catalog items in this baseline.
    [Tags]    servicenow    data-generation    catalog-items    baseline

    ${num_categories}=    Get Length    ${CAT_CATEGORY_SYS_IDS}
    ${num_templates}=     Get Length    ${NAME_TEMPLATES}
    ${num_items}=         Get Length    ${ITEM_TYPES}

    @{created_ids}=    Create List

    FOR    ${i}    IN RANGE    0    ${CATALOG_ITEM_COUNT}
        ${cat_idx}=        Evaluate    ${i} % ${num_categories}
        ${tmpl_idx}=       Evaluate    ${i} % ${num_templates}
        ${item_idx}=       Evaluate    ${i} % ${num_items}

        ${name_template}=  Set Variable    ${NAME_TEMPLATES}[${tmpl_idx}]
        ${item_type}=      Set Variable    ${ITEM_TYPES}[${item_idx}]
        ${cat_sys_id}=     Set Variable    ${CAT_CATEGORY_SYS_IDS}[${cat_idx}]
        ${cat_name}=       Set Variable    ${CAT_CATEGORY_NAMES}[${cat_idx}]

        ${name}=        Set Variable    ${DATA_PREFIX} ${name_template} ${item_type} (${cat_name} #${i + 1})
        ${short_desc}=  Set Variable    Auto-generated catalog item. ${name_template} ${item_type}. Filed under ${cat_name}.

        ${sys_id}=    Create Service Catalog Item    ${name}    ${short_desc}
        ...    category_sys_id=${cat_sys_id}
        Append To List    ${created_ids}    ${sys_id}
    END

    Length Should Be    ${created_ids}    ${CATALOG_ITEM_COUNT}
    Log    Created ${CATALOG_ITEM_COUNT} catalog items across 7 categories.
