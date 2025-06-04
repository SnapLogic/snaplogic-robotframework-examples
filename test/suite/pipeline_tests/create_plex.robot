*** Settings ***
Documentation       Test Suite for Snaplex Creation and Configuration
...                 This suite validates Snaplex deployment functionality by:

Resource            snaplogic_common_robot/snaplogic_apis_keywords/snaplogic_keywords.resource    # SnapLogic API keywords


*** Test Cases ***
Create Snaplex In Project Space
    [Tags]    createplex    project_space    create_project
    [Template]    Create Snaplex
    ${env_file_path}    ${GROUNDPLEX_NAME}    ${GROUNDPLEX_ENV}    ${ORG_NAME}    ${RELEASE_BUILD_VERSION}    ${GROUNDPLEX_LOCATION_PATH}

Download And Save slpropz File
    [Tags]    createplex    project_space    create_project
    [Template]    Download And Save Config File
    ./.config    ${GROUNDPLEX_LOCATION_PATH}    ${GROUNDPLEX_NAME}.slpropz
