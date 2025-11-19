*** Settings ***
Library         OperatingSystem
Library         BuiltIn
Library         Process
Library         JSONLibrary
Resource        snaplogic_common_robot/snaplogic_apis_keywords/snaplogic_keywords.resource

Suite Setup     Before Suite


*** Variables ***
${ACCOUNT_PAYLOAD_PATH}             ${CURDIR}/test_data/accounts_payload
${ENV_FILE_PATH}                    ${CURDIR}/../../.env
${ENV_FILES_DIR}                    ${CURDIR}/../../env_files
# ${PIPELINE_PAYLOAD_PATH}    /app/src/pipelines
${PIPELINE_PAYLOAD_PATH}            ${CURDIR}/../../src/pipelines
${GENERATIVE_SLP_PIPELINES_PATH}    ${CURDIR}/../../src/generative_pipelines


*** Keywords ***
Before Suite
    # Generate Cookiecutter Context From Tags
    Log To Console    env_file_path is:${ENV_FILE_PATH}
    Load Environment Variables
    Validate Environment Variables
    Set Up Global Variables
    Project Set Up-Delete Project Space-Create New Project space-Create Accounts

Project Set Up-Delete Project Space-Create New Project space-Create Accounts
    Set Up Data
    ...    ${URL}
    ...    ${ORG_ADMIN_USER}
    ...    ${ORG_ADMIN_PASSWORD}
    ...    ${ORG_NAME}
    ...    ${PROJECT_SPACE}
    ...    ${PROJECT_NAME}
    ...    ${ENV_FILE_PATH}

Set Up Global Variables
    # Set up the path variables as global
    # Set Global Variable    ${TASKS_PAYLOAD_PATH}
    Set Global Variable    ${ACCOUNT_PAYLOAD_PATH}
    Set Global Variable    ${ENV_FILE_PATH}
    Set Global Variable    ${PIPELINE_PAYLOAD_PATH}
    Set Global Variable    ${GENERATIVE_SLP_PIPELINES_PATH}

    Log To Console    env file path(from init_file):${env_file_path}

Validate Environment Variables
    @{required_env_vars}=    Create List
    ...    URL
    ...    ORG_ADMIN_USER
    ...    ORG_ADMIN_PASSWORD
    ...    ORG_NAME
    ...    PROJECT_SPACE
    ...    PROJECT_NAME
    ...    GROUNDPLEX_NAME

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
        ...    Missing required environment variables: ${missing_vars_str}. Please check your .env file and ensure all required variables are defined.
    END

Load Environment Variables
    [Documentation]    Loads environment variables from env_files directory first, then root .env file last (highest precedence)

    # First load all .env files from env_files directory and subdirectories
    ${env_dir_exists}=    Run Keyword And Return Status    Directory Should Exist    ${ENV_FILES_DIR}

    IF    ${env_dir_exists}
        # Load .env files from root env_files directory
        @{env_files}=    List Files In Directory    ${ENV_FILES_DIR}    pattern=.env*
        ${file_count}=    Get Length    ${env_files}

        IF    ${file_count} > 0
            Log To Console    \nLoading ${file_count} environment files from ${ENV_FILES_DIR}:
            FOR    ${env_file}    IN    @{env_files}
                ${full_path}=    Join Path    ${ENV_FILES_DIR}    ${env_file}
                Log To Console    Loading: ${env_file}
                Load Single Env File    ${full_path}
            END
        END

        # Load .env files from subdirectories
        @{subdirs}=    List Directories In Directory    ${ENV_FILES_DIR}
        FOR    ${subdir}    IN    @{subdirs}
            ${subdir_path}=    Join Path    ${ENV_FILES_DIR}    ${subdir}
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
        Log To Console    \nEnvironment files directory not found: ${ENV_FILES_DIR}
    END

    # Finally load the root .env file LAST (highest precedence - can override all previous values)
    Log To Console    \nLoading root .env file (HIGHEST PRECEDENCE):
    Load Single Env File    ${ENV_FILE_PATH}

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
