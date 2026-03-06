*** Settings ***
Library         OperatingSystem
Library         BuiltIn
Library         Process
Library         JSONLibrary
Resource        snaplogic_common_robot/snaplogic_apis_keywords/snaplogic_keywords.resource

Suite Setup     Before Suite


*** Variables ***
${account_payload_path}             ${CURDIR}/test_data/accounts_payload
${env_file_path}                    ${CURDIR}/../../.env
${env_files_dir}                    ${CURDIR}/../../env_files
# ${pipeline_payload_path}    /app/src/pipelines
${pipeline_payload_path}            ${CURDIR}/../../src/pipelines
${generative_slp_pipelines_path}    ${CURDIR}/../../src/generative_pipelines
# ENV override file - passed via command line: --variable ENV_OVERRIDE_FILE:/app/.env.stage
# When set, this file is loaded LAST and takes HIGHEST PRECEDENCE over all other env files
${ENV_OVERRIDE_FILE}                ${EMPTY}


*** Keywords ***
Before Suite
    # Generate Cookiecutter Context From Tags
    Log To Console    env_file_path is:${env_file_path}
    Load Environment Variables
    Detect Auth Method
    Validate Environment Variables
    Set Up Global Variables
    Project Set Up-Delete Project Space-Create New Project space-Create Accounts

Project Set Up-Delete Project Space-Create New Project space-Create Accounts
    ${auth_method}=    Get Environment Variable    AUTH_METHOD    basic
    Log To Console    \nAuthentication method: ${auth_method}

    IF    '${auth_method}' == 'basic'
        Set Up Data
        ...    ${URL}
        ...    ${ORG_ADMIN_USER}
        ...    ${ORG_ADMIN_PASSWORD}
        ...    ${ORG_NAME}
        ...    ${PROJECT_SPACE}
        ...    ${PROJECT_NAME}
        ...    ${env_file_path}
        ...    auth_method=basic
    ELSE IF    '${auth_method}' == 'jwt'
        ${bearer_token}=    Get Environment Variable    BEARER_TOKEN
        Set Up Data
        ...    ${URL}
        ...    org_name=${ORG_NAME}
        ...    project_space=${PROJECT_SPACE}
        ...    project_name=${PROJECT_NAME}
        ...    env_file_path=${env_file_path}
        ...    auth_method=jwt
        ...    bearer_token=${bearer_token}
    ELSE IF    '${auth_method}' == 'oauth2'
        ${oauth2_token_url}=    Get Environment Variable    OAUTH2_TOKEN_URL
        ${oauth2_client_id}=    Get Environment Variable    OAUTH2_CLIENT_ID
        ${oauth2_client_secret}=    Get Environment Variable    OAUTH2_CLIENT_SECRET
        ${oauth2_scope}=    Get Environment Variable    OAUTH2_SCOPE    ${EMPTY}
        Set Up Data
        ...    ${URL}
        ...    org_name=${ORG_NAME}
        ...    project_space=${PROJECT_SPACE}
        ...    project_name=${PROJECT_NAME}
        ...    env_file_path=${env_file_path}
        ...    auth_method=oauth2
        ...    oauth2_token_url=${oauth2_token_url}
        ...    oauth2_client_id=${oauth2_client_id}
        ...    oauth2_client_secret=${oauth2_client_secret}
        ...    oauth2_scope=${oauth2_scope}
    ELSE IF    '${auth_method}' == 'sltoken'
        Set Up Data
        ...    ${URL}
        ...    ${ORG_ADMIN_USER}
        ...    ${ORG_ADMIN_PASSWORD}
        ...    ${ORG_NAME}
        ...    ${PROJECT_SPACE}
        ...    ${PROJECT_NAME}
        ...    ${env_file_path}
        ...    auth_method=sltoken
    ELSE
        Fail    Invalid AUTH_METHOD: ${auth_method}. Supported values: basic, jwt, oauth2, sltoken
    END

Set Up Global Variables
    # Set up the path variables as global
    # Set Global Variable    ${TASKS_PAYLOAD_PATH}
    Set Global Variable    ${account_payload_path}
    Set Global Variable    ${env_file_path}
    Set Global Variable    ${pipeline_payload_path}
    Set Global Variable    ${generative_slp_pipelines_path}

    Log To Console    env file path(from init_file):${env_file_path}

Validate Environment Variables
    # Common variables required regardless of auth method
    @{required_env_vars}=    Create List
    ...    URL
    ...    ORG_NAME
    ...    PROJECT_SPACE
    ...    PROJECT_NAME
    ...    GROUNDPLEX_NAME

    # Add auth-method-specific required variables
    ${auth_method}=    Get Environment Variable    AUTH_METHOD    basic

    IF    '${auth_method}' == 'basic'
        Append To List    ${required_env_vars}    ORG_ADMIN_USER
        Append To List    ${required_env_vars}    ORG_ADMIN_PASSWORD
    ELSE IF    '${auth_method}' == 'jwt'
        Append To List    ${required_env_vars}    BEARER_TOKEN
    ELSE IF    '${auth_method}' == 'oauth2'
        Append To List    ${required_env_vars}    OAUTH2_TOKEN_URL
        Append To List    ${required_env_vars}    OAUTH2_CLIENT_ID
        Append To List    ${required_env_vars}    OAUTH2_CLIENT_SECRET
    ELSE IF    '${auth_method}' == 'sltoken'
        Append To List    ${required_env_vars}    ORG_ADMIN_USER
        Append To List    ${required_env_vars}    ORG_ADMIN_PASSWORD
    ELSE
        Fail    Invalid AUTH_METHOD: ${auth_method}. Supported values: basic, jwt, oauth2, sltoken
    END

    @{missing_vars}=    Create List

    FOR    ${var}    IN    @{required_env_vars}
        ${env_value}=    Get Environment Variable    ${var}    ${EMPTY}
        IF    '${env_value}' == '${EMPTY}'
            Append To List    ${missing_vars}    ${var}
        END
    END

    ${missing_count}=    Get Length    ${missing_vars}
    IF    ${missing_count} > 0
        ${missing_vars_str}=    Evaluate    ", ".join($missing_vars)
        Fail
        ...    Missing required environment variables for AUTH_METHOD=${auth_method}: ${missing_vars_str}. Please check your .env file and ensure all required variables are defined.
    END

Detect Auth Method
    [Documentation]    Auto-detects authentication method from environment variables.
    ...    If AUTH_METHOD is explicitly set in .env, uses that value.
    ...    Otherwise, infers the method from which auth-related env vars are present:
    ...    - OAUTH2_TOKEN_URL present → oauth2
    ...    - BEARER_TOKEN present → jwt
    ...    - Otherwise → basic (default)
    ${explicit_method}=    Get Environment Variable    AUTH_METHOD    ${EMPTY}
    IF    '${explicit_method}' != '${EMPTY}'
        Log To Console    \nAUTH_METHOD explicitly set to: ${explicit_method}
        RETURN
    END
    # Auto-detect based on available env vars
    ${oauth2_url}=    Get Environment Variable    OAUTH2_TOKEN_URL    ${EMPTY}
    ${bearer}=    Get Environment Variable    BEARER_TOKEN    ${EMPTY}
    IF    '${oauth2_url}' != '${EMPTY}'
        Set Environment Variable    AUTH_METHOD    oauth2
        Log To Console    \nAuto-detected AUTH_METHOD=oauth2 (OAUTH2_TOKEN_URL is set)
    ELSE IF    '${bearer}' != '${EMPTY}'
        Set Environment Variable    AUTH_METHOD    jwt
        Log To Console    \nAuto-detected AUTH_METHOD=jwt (BEARER_TOKEN is set)
    ELSE
        Set Environment Variable    AUTH_METHOD    basic
        Log To Console    \nAuto-detected AUTH_METHOD=basic (default)
    END

Load Environment Variables
    [Documentation]    Loads environment variables in order of precedence (last file wins):
    ...    1. env_files/ directory files (lowest precedence)
    ...    2. Root .env file
    ...    3. ENV_OVERRIDE_FILE if specified via ENV= parameter (HIGHEST precedence)

    # First load all .env files from env_files directory and subdirectories
    ${env_dir_exists}=    Run Keyword And Return Status    Directory Should Exist    ${env_files_dir}

    IF    ${env_dir_exists}
        # Load .env files from root env_files directory
        @{env_files}=    List Files In Directory    ${env_files_dir}    pattern=.env*
        ${file_count}=    Get Length    ${env_files}

        IF    ${file_count} > 0
            Log To Console    \nLoading ${file_count} environment files from ${env_files_dir}:
            FOR    ${env_file}    IN    @{env_files}
                ${full_path}=    Join Path    ${env_files_dir}    ${env_file}
                Log To Console    Loading: ${env_file}
                Load Single Env File    ${full_path}
            END
        END

        # Load .env files from subdirectories
        @{subdirs}=    List Directories In Directory    ${env_files_dir}
        FOR    ${subdir}    IN    @{subdirs}
            ${subdir_path}=    Join Path    ${env_files_dir}    ${subdir}
            @{subdir_env_files}=    List Files In Directory    ${subdir_path}    pattern=.env*
            ${subdir_file_count}=    Get Length    ${subdir_env_files}

            IF    ${subdir_file_count} > 0
                Log To Console    \nLoading ${subdir_file_count} environment files from ${subdir_path}:
                FOR    ${env_file}    IN    @{subdir_env_files}
                    ${full_path}=    Join Path    ${subdir_path}    ${env_file}
                    Log To Console    Loading: ${env_file}
                    Load Single Env File    ${full_path}
                END
            END
        END
    ELSE
        Log To Console    \nEnvironment files directory not found: ${env_files_dir}
    END

    # Load the root .env file (high precedence - can override env_files values)
    Log To Console    \nLoading root .env file:
    Load Single Env File    ${env_file_path}

    # Finally load the ENV override file LAST if specified (HIGHEST PRECEDENCE)
    # This is set via: make robot-run-tests ENV=.env.stage
    IF    '${ENV_OVERRIDE_FILE}' != '${EMPTY}'
        Log To Console    \n========================================
        Log To Console    Loading ENV override file (HIGHEST PRECEDENCE):
        Log To Console    ${ENV_OVERRIDE_FILE}
        Log To Console    ========================================
        Load Single Env File    ${ENV_OVERRIDE_FILE}
    END

Load Single Env File
    [Documentation]    Loads environment variables from a single .env file and auto-detects JSON values
    [Arguments]    ${file_path}

    ${file_exists}=    Run Keyword And Return Status    File Should Exist    ${file_path}

    IF    not ${file_exists}
        Log To Console    ⚠️ WARNING: Environment file not found: ${file_path}
        RETURN
    END

    ${env_content}=    Get File    ${file_path}
    @{env_lines}=    Split To Lines    ${env_content}

    FOR    ${line}    IN    @{env_lines}
        ${line}=    Strip String    ${line}
        ${is_comment}=    Evaluate    $line.startswith("#") or $line == ""

        IF    not ${is_comment}
            ${var_name}    ${var_value}=    Split String    ${line}    separator==    max_split=1
            ${var_name}=    Strip String    ${var_name}
            ${var_value}=    Strip String    ${var_value}

            # Set as environment variable
            Set Environment Variable    ${var_name}    ${var_value}

            # Try to parse every value as JSON, fall back to string if it fails
            ${status}    ${json_result}=    Run Keyword And Ignore Error
            ...    Evaluate    json.loads(r'''${var_value}''')    json

            IF    '${status}' == 'PASS'
                # Successfully parsed as JSON - determine if it's a dictionary or list
                ${is_dict}=    Evaluate    isinstance($json_result, dict)
                ${is_list}=    Evaluate    isinstance($json_result, list)

                IF    ${is_dict}
                    # Create dictionary variable (convert name to lowercase)
                    ${dict_var_name}=    Convert To Lower Case    ${var_name}
                    Set Global Variable    \&{${dict_var_name}}    &{json_result}
                    Log    📝 Auto-detected JSON dict ${var_name} -> &{${dict_var_name}}    level=CONSOLE
                ELSE IF    ${is_list}
                    # Create list variable (convert name to lowercase)
                    ${list_var_name}=    Convert To Lower Case    ${var_name}
                    Set Global Variable    \@{${list_var_name}}    @{json_result}
                    Log    📝 Auto-detected JSON list ${var_name} -> @{${list_var_name}}    level=CONSOLE
                ELSE
                    # JSON primitive (string, number, boolean) - treat as regular variable
                    Set Global Variable    \${${var_name}}    ${json_result}
                    Log    📝 Auto-detected JSON primitive ${var_name} -> ${json_result}    level=CONSOLE
                END
            ELSE
                # Not JSON or failed to parse - treat as regular string
                Set Global Variable    \${${var_name}}    ${var_value}
            END
        END
    END

    Log To Console    Loaded environment variables from: ${file_path}
