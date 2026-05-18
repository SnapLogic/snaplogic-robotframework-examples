*** Settings ***
Documentation       Shared keywords for ServiceNow REST API operations.
...
...                 Used by tests that bulk-create Knowledge Articles, Service Catalog
...                 items, and attachments via the ServiceNow Table API.
...
...                 Credentials and sys_ids come from env_files/external_accounts/.env.servicenow.

Library             RequestsLibrary
Library             Collections
Library             String
Library             OperatingSystem


*** Variables ***
# Loaded from .env.servicenow at runtime
${SN_INSTANCE_URL}      %{SERVICENOW_INSTANCE_URL}
${SN_USERNAME}          %{SERVICENOW_USERNAME}
${SN_PASSWORD}          %{SERVICENOW_PASSWORD}
${SN_KB_IT_SYS_ID}      %{SERVICENOW_KB_BASE_IT_SYS_ID}
${SN_CAT_FAQ_SYS_ID}    %{SERVICENOW_CATEGORY_FAQ_SYS_ID}
${SN_WORKFLOW_STATE}    %{SERVICENOW_DEFAULT_WORKFLOW_STATE}
${SN_ARTICLE_TYPE}      %{SERVICENOW_DEFAULT_ARTICLE_TYPE}
${SN_VALID_TO}          %{SERVICENOW_DEFAULT_VALID_TO}
${SN_SC_CATALOG_SYS_ID}     %{SERVICENOW_SC_CATALOG_SYS_ID}
${SN_SC_CATEGORY_SYS_ID}    %{SERVICENOW_SC_CATEGORY_SYS_ID}


*** Keywords ***
Connect To ServiceNow
    [Documentation]    Creates a reusable HTTP session to the ServiceNow instance.
    ...                Uses HTTP Basic Auth with credentials from .env.servicenow.
    ...
    ...                Must be called once before any other ServiceNow keyword in a test.
    ...
    ...                *Example:*
    ...                | Connect To ServiceNow |
    ${auth}=    Create List    ${SN_USERNAME}    ${SN_PASSWORD}
    Create Session    servicenow    ${SN_INSTANCE_URL}    auth=${auth}    verify=True
    Log    Connected to ServiceNow at ${SN_INSTANCE_URL}

Create Knowledge Article
    [Documentation]    Creates a single Knowledge Article via the ServiceNow REST API.
    ...                Posts to /api/now/table/kb_knowledge with a JSON payload.
    ...
    ...                *Arguments:*
    ...                - ``short_description``: Article title
    ...                - ``body_text``: Article body (HTML or plain text)
    ...                - ``kb_base_sys_id``: Knowledge Base sys_id (default: IT)
    ...                - ``category_sys_id``: Category sys_id (default: FAQ)
    ...
    ...                *Returns:*
    ...                - The sys_id of the newly created article
    ...
    ...                *Example:*
    ...                | ${sys_id}= | Create Knowledge Article | My Title | <p>My body</p> |
    [Arguments]    ${short_description}    ${body_text}
    ...    ${kb_base_sys_id}=${SN_KB_IT_SYS_ID}
    ...    ${category_sys_id}=${SN_CAT_FAQ_SYS_ID}

    # Creates the article in DRAFT state (ServiceNow default — workflow_state can't be
    # set on insert). To make it published, call "Publish Knowledge Article" afterwards
    # with the returned sys_id.
    ${payload}=    Create Dictionary
    ...    short_description=${short_description}
    ...    text=${body_text}
    ...    kb_knowledge_base=${kb_base_sys_id}
    ...    kb_category=${category_sys_id}
    ...    active=true
    ...    article_type=${SN_ARTICLE_TYPE}
    ...    valid_to=${SN_VALID_TO}

    ${response}=    POST On Session    servicenow    /api/now/table/kb_knowledge    json=${payload}
    Status Should Be    201    ${response}

    ${result}=    Set Variable    ${response.json()}[result]
    ${sys_id}=    Set Variable    ${result}[sys_id]
    ${number}=    Set Variable    ${result}[number]

    Log    Created article: ${number} (sys_id=${sys_id}) - "${short_description}"
    RETURN    ${sys_id}

Publish Knowledge Article
    [Documentation]    Transitions an existing Knowledge Article from draft to published state.
    ...                Uses PATCH because ServiceNow ignores workflow_state on insert.
    ...
    ...                *Arguments:*
    ...                - ``sys_id``: The sys_id of an existing draft article
    ...
    ...                *Example:*
    ...                | ${sys_id}= | Create Knowledge Article | Title | Body |
    ...                | Publish Knowledge Article | ${sys_id} |
    [Arguments]    ${sys_id}

    ${today}=    Get Time    %Y-%m-%d
    ${payload}=    Create Dictionary
    ...    workflow_state=published
    ...    published=${today}

    ${response}=    PATCH On Session    servicenow    /api/now/table/kb_knowledge/${sys_id}    json=${payload}
    Status Should Be    200    ${response}

    Log    Published article sys_id=${sys_id}

Delete Knowledge Article
    [Documentation]    Permanently deletes a Knowledge Article by sys_id.
    ...                Used for cleanup of test data.
    ...
    ...                *Arguments:*
    ...                - ``sys_id``: The sys_id of the article to delete
    [Arguments]    ${sys_id}

    ${response}=    DELETE On Session    servicenow    /api/now/table/kb_knowledge/${sys_id}
    Status Should Be    204    ${response}

    Log    Deleted article sys_id=${sys_id}

Create Service Catalog Item
    [Documentation]    Creates a single Service Catalog item via the ServiceNow REST API.
    ...                Posts to /api/now/table/sc_cat_item with a JSON payload.
    ...
    ...                *Arguments:*
    ...                - ``name``: Catalog item name/title (visible to end users)
    ...                - ``short_description``: One-line summary
    ...
    ...                *Returns:*
    ...                - The sys_id of the newly created catalog item
    ...
    ...                *Example:*
    ...                | ${sys_id}= | Create Service Catalog Item | Order Laptop | Standard MacBook Pro |
    [Arguments]    ${name}    ${short_description}
    ...    ${catalog_sys_id}=${SN_SC_CATALOG_SYS_ID}
    ...    ${category_sys_id}=${SN_SC_CATEGORY_SYS_ID}

    ${payload}=    Create Dictionary
    ...    name=${name}
    ...    short_description=${short_description}
    ...    sc_catalogs=${catalog_sys_id}
    ...    category=${category_sys_id}
    ...    active=true

    ${response}=    POST On Session    servicenow    /api/now/table/sc_cat_item    json=${payload}
    Status Should Be    201    ${response}

    ${result}=    Set Variable    ${response.json()}[result]
    ${sys_id}=    Set Variable    ${result}[sys_id]

    Log    Created catalog item: sys_id=${sys_id} - "${name}"
    RETURN    ${sys_id}

Attach File To Record
    [Documentation]    Attaches a local file to any ServiceNow record (article, catalog item, etc.).
    ...                Posts to /api/now/attachment/file with the binary file contents.
    ...
    ...                *Arguments:*
    ...                - ``table_name``: ServiceNow table the record belongs to (e.g., kb_knowledge)
    ...                - ``record_sys_id``: The sys_id of the record to attach to
    ...                - ``file_path``: Absolute path to the local file
    ...                - ``content_type``: MIME type (default: application/pdf)
    ...
    ...                *Returns:*
    ...                - The sys_id of the attachment record
    ...
    ...                *Example:*
    ...                | Attach File To Record | kb_knowledge | ${article_id} | /tmp/test.pdf |
    [Arguments]    ${table_name}    ${record_sys_id}    ${file_path}
    ...    ${content_type}=application/pdf

    ${file_data}=    Get Binary File    ${file_path}
    ${file_name}=    Evaluate    "${file_path}".split("/")[-1]
    ${headers}=    Create Dictionary    Content-Type=${content_type}

    ${url}=    Catenate    SEPARATOR=
    ...    /api/now/attachment/file?table_name=${table_name}
    ...    &table_sys_id=${record_sys_id}
    ...    &file_name=${file_name}

    ${response}=    POST On Session    servicenow    ${url}
    ...    data=${file_data}    headers=${headers}
    Status Should Be    201    ${response}

    ${result}=    Set Variable    ${response.json()}[result]
    ${sys_id}=    Set Variable    ${result}[sys_id]

    Log    Attached file ${file_name} to ${table_name}/${record_sys_id}
    RETURN    ${sys_id}
