*** Settings ***
Documentation       Environment Configuration Management
Library             OperatingSystem
Library             String

*** Variables ***
${ENVIRONMENT}      ${EMPTY}    # Will be set from command line
${ENV_FILE}         ${EMPTY}    # Will be set from command line

*** Keywords ***
Load Environment Configuration
    [Documentation]    Load configuration based on environment
    [Arguments]    ${env}=${ENVIRONMENT}
    
    Log    Loading configuration for environment: ${env}    console=yes
    
    # Set environment-specific variables
    IF    '${env}' == 'dev' or '${env}' == 'development'
        Set Development Configuration
    ELSE IF    '${env}' == 'stage' or '${env}' == 'staging'
        Set Staging Configuration
    ELSE IF    '${env}' == 'prod' or '${env}' == 'production'
        Set Production Configuration
    ELSE
        Log    Unknown environment: ${env}, using default    level=WARN
        Set Development Configuration
    END
    
    Log Environment Info

Set Development Configuration
    [Documentation]    Set variables for development environment
    Set Suite Variable    ${ENV_NAME}    development
    Set Suite Variable    ${DB_HOST}    localhost
    Set Suite Variable    ${API_URL}    https://dev-api.example.com
    Set Suite Variable    ${LOG_LEVEL}    DEBUG
    Set Suite Variable    ${RETRY_COUNT}    3
    Set Suite Variable    ${TIMEOUT}    30s

Set Staging Configuration
    [Documentation]    Set variables for staging environment
    Set Suite Variable    ${ENV_NAME}    staging
    Set Suite Variable    ${DB_HOST}    stage-db.example.com
    Set Suite Variable    ${API_URL}    https://stage-api.example.com
    Set Suite Variable    ${LOG_LEVEL}    INFO
    Set Suite Variable    ${RETRY_COUNT}    2
    Set Suite Variable    ${TIMEOUT}    60s

Set Production Configuration
    [Documentation]    Set variables for production environment
    Set Suite Variable    ${ENV_NAME}    production
    Set Suite Variable    ${DB_HOST}    prod-db.example.com
    Set Suite Variable    ${API_URL}    https://api.example.com
    Set Suite Variable    ${LOG_LEVEL}    WARNING
    Set Suite Variable    ${RETRY_COUNT}    1
    Set Suite Variable    ${TIMEOUT}    120s

Log Environment Info
    [Documentation]    Display current environment configuration
    Log    \n========== ENVIRONMENT CONFIGURATION ==========    console=yes
    Log    Environment: ${ENV_NAME}    console=yes
    Log    Database Host: ${DB_HOST}    console=yes
    Log    API URL: ${API_URL}    console=yes
    Log    Log Level: ${LOG_LEVEL}    console=yes
    Log    Retry Count: ${RETRY_COUNT}    console=yes
    Log    Timeout: ${TIMEOUT}    console=yes
    Log    ===============================================\n    console=yes

Get Environment Variable With Default
    [Documentation]    Get environment variable with fallback to default
    [Arguments]    ${var_name}    ${default_value}=${EMPTY}
    
    ${value}=    Get Environment Variable    ${var_name}    ${default_value}
    RETURN    ${value}

Should Be In Environment
    [Documentation]    Verify we're in the expected environment
    [Arguments]    ${expected_env}
    
    ${current_env}=    Get Environment Variable    TEST_ENVIRONMENT    unknown
    Should Be Equal    ${current_env}    ${expected_env}
    ...    Wrong environment! Expected ${expected_env} but in ${current_env}

Skip If Not Environment
    [Documentation]    Skip test if not in specified environment
    [Arguments]    ${required_env}
    
    ${current_env}=    Get Environment Variable    TEST_ENVIRONMENT    unknown
    Skip If    '${current_env}' != '${required_env}'
    ...    Test only runs in ${required_env} environment

Run Only In Production
    [Documentation]    Ensure test only runs in production
    Skip If Not Environment    production

Run Only In Development
    [Documentation]    Ensure test only runs in development
    Skip If Not Environment    development

Run Only In Staging
    [Documentation]    Ensure test only runs in staging
    Skip If Not Environment    staging
