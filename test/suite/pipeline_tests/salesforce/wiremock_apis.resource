*** Settings ***
Documentation       WireMock Salesforce API Keywords
...                 This resource file contains API keywords for Salesforce operations via WireMock.
...                 All keywords use a shared session defined in Variables section.

Library             RequestsLibrary
Library             JSONLibrary
Library             Collections


*** Variables ***
${WIREMOCK_SESSION}     salesforce-mock
${BASE_URL}             https://salesforce-api-mock:8443
${VERIFY_SSL}           ${FALSE}
${API_VERSION}          v59.0
${AUTH_TOKEN}           ${EMPTY}


*** Keywords ***
# ============================================================================
# SESSION MANAGEMENT
# ============================================================================

Create Salesforce Session Api
    [Documentation]    Creates a session for Salesforce WireMock API access.
    ...
    ...    *Example:*
    ...    | Create Salesforce Session Api |

    Create Session    ${WIREMOCK_SESSION}    ${BASE_URL}    verify=${VERIFY_SSL}
    Log    Session created: ${WIREMOCK_SESSION} at ${BASE_URL}

# ============================================================================
# AUTHENTICATION APIs
# ============================================================================

Authenticate Api
    [Documentation]    Authenticates with Salesforce mock and retrieves access token.
    ...
    ...    *Arguments:*
    ...    - ``username``: Username for authentication
    ...    - ``password``: Password for authentication
    ...
    ...    *Returns:*
    ...    - Response object containing access token
    [Arguments]    ${username}    ${password}

    ${auth_data}    Create Dictionary
    ...    grant_type=password
    ...    username=${username}
    ...    password=${password}

    ${response}    POST On Session    ${WIREMOCK_SESSION}    /services/oauth2/token
    ...    data=${auth_data}

    # Store token if successful
    IF    ${response.status_code} == 200
        ${token}    Get From Dictionary    ${response.json()}    access_token
        Set Suite Variable    ${AUTH_TOKEN}    ${token}
    END

    RETURN    ${response}

Refresh Token Api
    [Documentation]    Refreshes authentication token using refresh token.
    ...
    ...    *Arguments:*
    ...    - ``refresh_token``: Refresh token for authentication
    ...
    ...    *Returns:*
    ...    - Response object containing new access token
    [Arguments]    ${refresh_token}

    ${auth_data}    Create Dictionary
    ...    grant_type=refresh_token
    ...    refresh_token=${refresh_token}

    ${response}    POST On Session    ${WIREMOCK_SESSION}    /services/oauth2/token
    ...    data=${auth_data}

    RETURN    ${response}

Revoke Token Api
    [Documentation]    Revokes an authentication token.
    ...
    ...    *Arguments:*
    ...    - ``token``: Token to revoke
    ...
    ...    *Returns:*
    ...    - Response object
    [Arguments]    ${token}

    ${data}    Create Dictionary    token=${token}

    ${response}    POST On Session    ${WIREMOCK_SESSION}    /services/oauth2/revoke
    ...    data=${data}

    RETURN    ${response}

# ============================================================================
# ACCOUNT APIs
# ============================================================================

Create Account Api
    [Documentation]    Creates a new Account record.
    ...
    ...    *Arguments:*
    ...    - ``account_data``: Dictionary containing account fields
    ...
    ...    *Returns:*
    ...    - Response object containing created account ID
    [Arguments]    ${account_data}

    ${headers}    Create Dictionary
    ...    Authorization=Bearer ${AUTH_TOKEN}
    ...    Content-Type=application/json

    ${response}    POST On Session    ${WIREMOCK_SESSION}
    ...    /services/data/${API_VERSION}/sobjects/Account
    ...    json=${account_data}
    ...    headers=${headers}

    RETURN    ${response}

Get Account Api
    [Documentation]    Retrieves an Account record by ID.
    ...
    ...    *Arguments:*
    ...    - ``account_id``: ID of the account to retrieve
    ...
    ...    *Returns:*
    ...    - Response object containing account data
    [Arguments]    ${account_id}

    ${headers}    Create Dictionary    Authorization=Bearer ${AUTH_TOKEN}

    ${response}    GET On Session    ${WIREMOCK_SESSION}
    ...    /services/data/${API_VERSION}/sobjects/Account/${account_id}
    ...    headers=${headers}

    RETURN    ${response}

Update Account Api
    [Documentation]    Updates an existing Account record.
    ...
    ...    *Arguments:*
    ...    - ``account_id``: ID of the account to update
    ...    - ``update_data``: Dictionary containing fields to update
    ...
    ...    *Returns:*
    ...    - Response object
    [Arguments]    ${account_id}    ${update_data}

    ${headers}    Create Dictionary
    ...    Authorization=Bearer ${AUTH_TOKEN}
    ...    Content-Type=application/json

    ${response}    PATCH On Session    ${WIREMOCK_SESSION}
    ...    /services/data/${API_VERSION}/sobjects/Account/${account_id}
    ...    json=${update_data}
    ...    headers=${headers}

    RETURN    ${response}

Delete Account Api
    [Documentation]    Deletes an Account record.
    ...
    ...    *Arguments:*
    ...    - ``account_id``: ID of the account to delete
    ...
    ...    *Returns:*
    ...    - Response object
    [Arguments]    ${account_id}

    ${headers}    Create Dictionary    Authorization=Bearer ${AUTH_TOKEN}

    ${response}    DELETE On Session    ${WIREMOCK_SESSION}
    ...    /services/data/${API_VERSION}/sobjects/Account/${account_id}
    ...    headers=${headers}

    RETURN    ${response}

# ============================================================================
# CONTACT APIs
# ============================================================================

Create Contact Api
    [Documentation]    Creates a new Contact record.
    ...
    ...    *Arguments:*
    ...    - ``contact_data``: Dictionary containing contact fields
    ...
    ...    *Returns:*
    ...    - Response object containing created contact ID
    [Arguments]    ${contact_data}

    ${headers}    Create Dictionary
    ...    Authorization=Bearer ${AUTH_TOKEN}
    ...    Content-Type=application/json

    ${response}    POST On Session    ${WIREMOCK_SESSION}
    ...    /services/data/${API_VERSION}/sobjects/Contact
    ...    json=${contact_data}
    ...    headers=${headers}

    RETURN    ${response}

Get Contact Api
    [Documentation]    Retrieves a Contact record by ID.
    ...
    ...    *Arguments:*
    ...    - ``contact_id``: ID of the contact to retrieve
    ...
    ...    *Returns:*
    ...    - Response object containing contact data
    [Arguments]    ${contact_id}

    ${headers}    Create Dictionary    Authorization=Bearer ${AUTH_TOKEN}

    ${response}    GET On Session    ${WIREMOCK_SESSION}
    ...    /services/data/${API_VERSION}/sobjects/Contact/${contact_id}
    ...    headers=${headers}

    RETURN    ${response}

Update Contact Api
    [Documentation]    Updates an existing Contact record.
    ...
    ...    *Arguments:*
    ...    - ``contact_id``: ID of the contact to update
    ...    - ``update_data``: Dictionary containing fields to update
    ...
    ...    *Returns:*
    ...    - Response object
    [Arguments]    ${contact_id}    ${update_data}

    ${headers}    Create Dictionary
    ...    Authorization=Bearer ${AUTH_TOKEN}
    ...    Content-Type=application/json

    ${response}    PATCH On Session    ${WIREMOCK_SESSION}
    ...    /services/data/${API_VERSION}/sobjects/Contact/${contact_id}
    ...    json=${update_data}
    ...    headers=${headers}

    RETURN    ${response}

Delete Contact Api
    [Documentation]    Deletes a Contact record.
    ...
    ...    *Arguments:*
    ...    - ``contact_id``: ID of the contact to delete
    ...
    ...    *Returns:*
    ...    - Response object
    [Arguments]    ${contact_id}

    ${headers}    Create Dictionary    Authorization=Bearer ${AUTH_TOKEN}

    ${response}    DELETE On Session    ${WIREMOCK_SESSION}
    ...    /services/data/${API_VERSION}/sobjects/Contact/${contact_id}
    ...    headers=${headers}

    RETURN    ${response}

# ============================================================================
# LEAD APIs
# ============================================================================

Create Lead Api
    [Documentation]    Creates a new Lead record.
    ...
    ...    *Arguments:*
    ...    - ``lead_data``: Dictionary containing lead fields
    ...
    ...    *Returns:*
    ...    - Response object containing created lead ID
    [Arguments]    ${lead_data}

    ${headers}    Create Dictionary
    ...    Authorization=Bearer ${AUTH_TOKEN}
    ...    Content-Type=application/json

    ${response}    POST On Session    ${WIREMOCK_SESSION}
    ...    /services/data/${API_VERSION}/sobjects/Lead
    ...    json=${lead_data}
    ...    headers=${headers}

    RETURN    ${response}

Get Lead Api
    [Documentation]    Retrieves a Lead record by ID.
    ...
    ...    *Arguments:*
    ...    - ``lead_id``: ID of the lead to retrieve
    ...
    ...    *Returns:*
    ...    - Response object containing lead data
    [Arguments]    ${lead_id}

    ${headers}    Create Dictionary    Authorization=Bearer ${AUTH_TOKEN}

    ${response}    GET On Session    ${WIREMOCK_SESSION}
    ...    /services/data/${API_VERSION}/sobjects/Lead/${lead_id}
    ...    headers=${headers}

    RETURN    ${response}

Update Lead Api
    [Documentation]    Updates an existing Lead record.
    ...
    ...    *Arguments:*
    ...    - ``lead_id``: ID of the lead to update
    ...    - ``update_data``: Dictionary containing fields to update
    ...
    ...    *Returns:*
    ...    - Response object
    [Arguments]    ${lead_id}    ${update_data}

    ${headers}    Create Dictionary
    ...    Authorization=Bearer ${AUTH_TOKEN}
    ...    Content-Type=application/json

    ${response}    PATCH On Session    ${WIREMOCK_SESSION}
    ...    /services/data/${API_VERSION}/sobjects/Lead/${lead_id}
    ...    json=${update_data}
    ...    headers=${headers}

    RETURN    ${response}

Delete Lead Api
    [Documentation]    Deletes a Lead record.
    ...
    ...    *Arguments:*
    ...    - ``lead_id``: ID of the lead to delete
    ...
    ...    *Returns:*
    ...    - Response object
    [Arguments]    ${lead_id}

    ${headers}    Create Dictionary    Authorization=Bearer ${AUTH_TOKEN}

    ${response}    DELETE On Session    ${WIREMOCK_SESSION}
    ...    /services/data/${API_VERSION}/sobjects/Lead/${lead_id}
    ...    headers=${headers}

    RETURN    ${response}

Convert Lead Api
    [Documentation]    Converts a Lead to Account, Contact, and Opportunity.
    ...
    ...    *Arguments:*
    ...    - ``lead_id``: ID of the lead to convert
    ...    - ``conversion_data``: Dictionary with conversion parameters
    ...
    ...    *Returns:*
    ...    - Response object with conversion results
    [Arguments]    ${lead_id}    ${conversion_data}

    ${headers}    Create Dictionary
    ...    Authorization=Bearer ${AUTH_TOKEN}
    ...    Content-Type=application/json

    Set To Dictionary    ${conversion_data}    leadId=${lead_id}

    ${response}    POST On Session    ${WIREMOCK_SESSION}
    ...    /services/data/${API_VERSION}/sobjects/Lead/convert
    ...    json=${conversion_data}
    ...    headers=${headers}

    RETURN    ${response}

# ============================================================================
# OPPORTUNITY APIs
# ============================================================================

Create Opportunity Api
    [Documentation]    Creates a new Opportunity record.
    ...
    ...    *Arguments:*
    ...    - ``opportunity_data``: Dictionary containing opportunity fields
    ...
    ...    *Returns:*
    ...    - Response object containing created opportunity ID
    [Arguments]    ${opportunity_data}

    ${headers}    Create Dictionary
    ...    Authorization=Bearer ${AUTH_TOKEN}
    ...    Content-Type=application/json

    ${response}    POST On Session    ${WIREMOCK_SESSION}
    ...    /services/data/${API_VERSION}/sobjects/Opportunity
    ...    json=${opportunity_data}
    ...    headers=${headers}

    RETURN    ${response}

Get Opportunity Api
    [Documentation]    Retrieves an Opportunity record by ID.
    ...
    ...    *Arguments:*
    ...    - ``opportunity_id``: ID of the opportunity to retrieve
    ...
    ...    *Returns:*
    ...    - Response object containing opportunity data
    [Arguments]    ${opportunity_id}

    ${headers}    Create Dictionary    Authorization=Bearer ${AUTH_TOKEN}

    ${response}    GET On Session    ${WIREMOCK_SESSION}
    ...    /services/data/${API_VERSION}/sobjects/Opportunity/${opportunity_id}
    ...    headers=${headers}

    RETURN    ${response}

Update Opportunity Api
    [Documentation]    Updates an existing Opportunity record.
    ...
    ...    *Arguments:*
    ...    - ``opportunity_id``: ID of the opportunity to update
    ...    - ``update_data``: Dictionary containing fields to update
    ...
    ...    *Returns:*
    ...    - Response object
    [Arguments]    ${opportunity_id}    ${update_data}

    ${headers}    Create Dictionary
    ...    Authorization=Bearer ${AUTH_TOKEN}
    ...    Content-Type=application/json

    ${response}    PATCH On Session    ${WIREMOCK_SESSION}
    ...    /services/data/${API_VERSION}/sobjects/Opportunity/${opportunity_id}
    ...    json=${update_data}
    ...    headers=${headers}

    RETURN    ${response}

Delete Opportunity Api
    [Documentation]    Deletes an Opportunity record.
    ...
    ...    *Arguments:*
    ...    - ``opportunity_id``: ID of the opportunity to delete
    ...
    ...    *Returns:*
    ...    - Response object
    [Arguments]    ${opportunity_id}

    ${headers}    Create Dictionary    Authorization=Bearer ${AUTH_TOKEN}

    ${response}    DELETE On Session    ${WIREMOCK_SESSION}
    ...    /services/data/${API_VERSION}/sobjects/Opportunity/${opportunity_id}
    ...    headers=${headers}

    RETURN    ${response}

# ============================================================================
# QUERY APIs
# ============================================================================

Execute Query Api
    [Documentation]    Executes a SOQL query.
    ...
    ...    *Arguments:*
    ...    - ``query``: SOQL query string
    ...
    ...    *Returns:*
    ...    - Response object containing query results
    [Arguments]    ${query}

    ${headers}    Create Dictionary    Authorization=Bearer ${AUTH_TOKEN}
    ${params}    Create Dictionary    q=${query}

    ${response}    GET On Session    ${WIREMOCK_SESSION}
    ...    /services/data/${API_VERSION}/query
    ...    headers=${headers}
    ...    params=${params}

    RETURN    ${response}

Execute Query All Api
    [Documentation]    Executes a SOQL query including deleted records.
    ...
    ...    *Arguments:*
    ...    - ``query``: SOQL query string
    ...
    ...    *Returns:*
    ...    - Response object containing query results
    [Arguments]    ${query}

    ${headers}    Create Dictionary    Authorization=Bearer ${AUTH_TOKEN}
    ${params}    Create Dictionary    q=${query}

    ${response}    GET On Session    ${WIREMOCK_SESSION}
    ...    /services/data/${API_VERSION}/queryAll
    ...    headers=${headers}
    ...    params=${params}

    RETURN    ${response}

Get Next Query Results Api
    [Documentation]    Gets next batch of query results using nextRecordsUrl.
    ...
    ...    *Arguments:*
    ...    - ``next_records_url``: URL for next batch of records
    ...
    ...    *Returns:*
    ...    - Response object containing next batch of results
    [Arguments]    ${next_records_url}

    ${headers}    Create Dictionary    Authorization=Bearer ${AUTH_TOKEN}

    ${response}    GET On Session    ${WIREMOCK_SESSION}    ${next_records_url}
    ...    headers=${headers}

    RETURN    ${response}

# ============================================================================
# BULK API 2.0
# ============================================================================

Create Bulk Job Api
    [Documentation]    Creates a bulk API 2.0 job.
    ...
    ...    *Arguments:*
    ...    - ``job_data``: Dictionary with job configuration
    ...
    ...    *Returns:*
    ...    - Response object containing job ID
    [Arguments]    ${job_data}

    ${headers}    Create Dictionary
    ...    Authorization=Bearer ${AUTH_TOKEN}
    ...    Content-Type=application/json

    ${response}    POST On Session    ${WIREMOCK_SESSION}
    ...    /services/data/${API_VERSION}/jobs/ingest
    ...    json=${job_data}
    ...    headers=${headers}

    RETURN    ${response}

Upload Bulk Data Api
    [Documentation]    Uploads data to a bulk job.
    ...
    ...    *Arguments:*
    ...    - ``job_id``: ID of the bulk job
    ...    - ``csv_data``: CSV data to upload
    ...
    ...    *Returns:*
    ...    - Response object
    [Arguments]    ${job_id}    ${csv_data}

    ${headers}    Create Dictionary
    ...    Authorization=Bearer ${AUTH_TOKEN}
    ...    Content-Type=text/csv

    ${response}    PUT On Session    ${WIREMOCK_SESSION}
    ...    /services/data/${API_VERSION}/jobs/ingest/${job_id}/batches
    ...    data=${csv_data}
    ...    headers=${headers}

    RETURN    ${response}

Close Bulk Job Api
    [Documentation]    Closes a bulk job to start processing.
    ...
    ...    *Arguments:*
    ...    - ``job_id``: ID of the bulk job
    ...
    ...    *Returns:*
    ...    - Response object
    [Arguments]    ${job_id}

    ${headers}    Create Dictionary
    ...    Authorization=Bearer ${AUTH_TOKEN}
    ...    Content-Type=application/json

    ${job_state}    Create Dictionary    state=UploadComplete

    ${response}    PATCH On Session    ${WIREMOCK_SESSION}
    ...    /services/data/${API_VERSION}/jobs/ingest/${job_id}
    ...    json=${job_state}
    ...    headers=${headers}

    RETURN    ${response}

Get Bulk Job Status Api
    [Documentation]    Gets the status of a bulk job.
    ...
    ...    *Arguments:*
    ...    - ``job_id``: ID of the bulk job
    ...
    ...    *Returns:*
    ...    - Response object containing job status
    [Arguments]    ${job_id}

    ${headers}    Create Dictionary    Authorization=Bearer ${AUTH_TOKEN}

    ${response}    GET On Session    ${WIREMOCK_SESSION}
    ...    /services/data/${API_VERSION}/jobs/ingest/${job_id}
    ...    headers=${headers}

    RETURN    ${response}

Get Bulk Job Results Api
    [Documentation]    Gets the results of a completed bulk job.
    ...
    ...    *Arguments:*
    ...    - ``job_id``: ID of the bulk job
    ...
    ...    *Returns:*
    ...    - Response object containing job results
    [Arguments]    ${job_id}

    ${headers}    Create Dictionary    Authorization=Bearer ${AUTH_TOKEN}

    ${response}    GET On Session    ${WIREMOCK_SESSION}
    ...    /services/data/${API_VERSION}/jobs/ingest/${job_id}/successfulResults
    ...    headers=${headers}

    RETURN    ${response}

# ============================================================================
# METADATA APIs
# ============================================================================

Get Object Metadata Api
    [Documentation]    Gets metadata for a Salesforce object.
    ...
    ...    *Arguments:*
    ...    - ``object_name``: Name of the Salesforce object
    ...
    ...    *Returns:*
    ...    - Response object containing object metadata
    [Arguments]    ${object_name}

    ${headers}    Create Dictionary    Authorization=Bearer ${AUTH_TOKEN}

    ${response}    GET On Session    ${WIREMOCK_SESSION}
    ...    /services/data/${API_VERSION}/sobjects/${object_name}/describe
    ...    headers=${headers}

    RETURN    ${response}

Get All Objects Api
    [Documentation]    Gets list of all available Salesforce objects.
    ...
    ...    *Returns:*
    ...    - Response object containing list of objects

    ${headers}    Create Dictionary    Authorization=Bearer ${AUTH_TOKEN}

    ${response}    GET On Session    ${WIREMOCK_SESSION}
    ...    /services/data/${API_VERSION}/sobjects
    ...    headers=${headers}

    RETURN    ${response}

Get Field Metadata Api
    [Documentation]    Gets metadata for a specific field.
    ...
    ...    *Arguments:*
    ...    - ``object_name``: Name of the Salesforce object
    ...    - ``field_name``: Name of the field
    ...
    ...    *Returns:*
    ...    - Response object containing field metadata
    [Arguments]    ${object_name}    ${field_name}

    ${headers}    Create Dictionary    Authorization=Bearer ${AUTH_TOKEN}

    ${response}    GET On Session    ${WIREMOCK_SESSION}
    ...    /services/data/${API_VERSION}/sobjects/${object_name}/describe/fields/${field_name}
    ...    headers=${headers}

    RETURN    ${response}

# ============================================================================
# COMPOSITE APIs
# ============================================================================

Execute Composite Request Api
    [Documentation]    Executes multiple API requests in a single call.
    ...
    ...    *Arguments:*
    ...    - ``composite_request``: Dictionary containing composite request
    ...
    ...    *Returns:*
    ...    - Response object containing results of all subrequests
    [Arguments]    ${composite_request}

    ${headers}    Create Dictionary
    ...    Authorization=Bearer ${AUTH_TOKEN}
    ...    Content-Type=application/json

    ${response}    POST On Session    ${WIREMOCK_SESSION}
    ...    /services/data/${API_VERSION}/composite
    ...    json=${composite_request}
    ...    headers=${headers}

    RETURN    ${response}

Execute Batch Request Api
    [Documentation]    Executes multiple independent requests in batch.
    ...
    ...    *Arguments:*
    ...    - ``batch_requests``: List of batch request objects
    ...
    ...    *Returns:*
    ...    - Response object containing batch results
    [Arguments]    ${batch_requests}

    ${headers}    Create Dictionary
    ...    Authorization=Bearer ${AUTH_TOKEN}
    ...    Content-Type=application/json

    ${batch_data}    Create Dictionary    batchRequests=${batch_requests}

    ${response}    POST On Session    ${WIREMOCK_SESSION}
    ...    /services/data/${API_VERSION}/composite/batch
    ...    json=${batch_data}
    ...    headers=${headers}

    RETURN    ${response}

# ============================================================================
# GENERIC SOBJECT APIs
# ============================================================================

Create SObject Api
    [Documentation]    Creates a record for any Salesforce object type.
    ...
    ...    *Arguments:*
    ...    - ``object_type``: Type of Salesforce object
    ...    - ``record_data``: Dictionary containing record fields
    ...
    ...    *Returns:*
    ...    - Response object containing created record ID
    [Arguments]    ${object_type}    ${record_data}

    ${headers}    Create Dictionary
    ...    Authorization=Bearer ${AUTH_TOKEN}
    ...    Content-Type=application/json

    ${response}    POST On Session    ${WIREMOCK_SESSION}
    ...    /services/data/${API_VERSION}/sobjects/${object_type}
    ...    json=${record_data}
    ...    headers=${headers}

    RETURN    ${response}

Get SObject Api
    [Documentation]    Retrieves a record for any Salesforce object type.
    ...
    ...    *Arguments:*
    ...    - ``object_type``: Type of Salesforce object
    ...    - ``record_id``: ID of the record to retrieve
    ...
    ...    *Returns:*
    ...    - Response object containing record data
    [Arguments]    ${object_type}    ${record_id}

    ${headers}    Create Dictionary    Authorization=Bearer ${AUTH_TOKEN}

    ${response}    GET On Session    ${WIREMOCK_SESSION}
    ...    /services/data/${API_VERSION}/sobjects/${object_type}/${record_id}
    ...    headers=${headers}

    RETURN    ${response}

Update SObject Api
    [Documentation]    Updates a record for any Salesforce object type.
    ...
    ...    *Arguments:*
    ...    - ``object_type``: Type of Salesforce object
    ...    - ``record_id``: ID of the record to update
    ...    - ``update_data``: Dictionary containing fields to update
    ...
    ...    *Returns:*
    ...    - Response object
    [Arguments]    ${object_type}    ${record_id}    ${update_data}

    ${headers}    Create Dictionary
    ...    Authorization=Bearer ${AUTH_TOKEN}
    ...    Content-Type=application/json

    ${response}    PATCH On Session    ${WIREMOCK_SESSION}
    ...    /services/data/${API_VERSION}/sobjects/${object_type}/${record_id}
    ...    json=${update_data}
    ...    headers=${headers}

    RETURN    ${response}

Delete SObject Api
    [Documentation]    Deletes a record for any Salesforce object type.
    ...
    ...    *Arguments:*
    ...    - ``object_type``: Type of Salesforce object
    ...    - ``record_id``: ID of the record to delete
    ...
    ...    *Returns:*
    ...    - Response object
    [Arguments]    ${object_type}    ${record_id}

    ${headers}    Create Dictionary    Authorization=Bearer ${AUTH_TOKEN}

    ${response}    DELETE On Session    ${WIREMOCK_SESSION}
    ...    /services/data/${API_VERSION}/sobjects/${object_type}/${record_id}
    ...    headers=${headers}

    RETURN    ${response}

Upsert SObject Api
    [Documentation]    Upserts a record using external ID.
    ...
    ...    *Arguments:*
    ...    - ``object_type``: Type of Salesforce object
    ...    - ``external_id_field``: Name of external ID field
    ...    - ``external_id_value``: Value of external ID
    ...    - ``record_data``: Dictionary containing record fields
    ...
    ...    *Returns:*
    ...    - Response object
    [Arguments]    ${object_type}    ${external_id_field}    ${external_id_value}    ${record_data}

    ${headers}    Create Dictionary
    ...    Authorization=Bearer ${AUTH_TOKEN}
    ...    Content-Type=application/json

    ${response}    PATCH On Session    ${WIREMOCK_SESSION}
    ...    /services/data/${API_VERSION}/sobjects/${object_type}/${external_id_field}/${external_id_value}
    ...    json=${record_data}
    ...    headers=${headers}

    RETURN    ${response}
