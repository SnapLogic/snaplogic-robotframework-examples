*** Settings ***
Documentation       Common Used Keywords for API Testing
...                 This resource file contains high-level keywords that build upon the API keywords.
...                 Keywords cover project setup, account management, file operations, and task execution.

Library             Collections
Library             DateTime
Library             OperatingSystem
Library             JSONLibrary
Library             RequestsLibrary
Resource            files.resource
Resource            database.resource
Resource            minio.resource


*** Keywords ***
Get Unique Id
    [Documentation]    Generates a unique ID using the current timestamp.
    ...
    ...    *Returns:*
    ...    - A string containing a unique ID based on the current date and time
    ...
    ...    *Example:*
    ...    | ${unique_id} | Get Unique Id |
    ${UNIQUE_ID}    Get Current Date    result_format=%Y%m%d%H%M%S%f
    RETURN    ${UNIQUE_ID}
