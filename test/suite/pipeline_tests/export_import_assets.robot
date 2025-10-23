*** Settings ***
# Standard Libraries
Library         OperatingSystem    # File system operations
Library         DateTime    # For timestamp generation
Resource        snaplogic_common_robot/snaplogic_apis_keywords/snaplogic_keywords.resource    # SnapLogic API keywords from installed package

Suite Setup     Setup Export Directory


*** Variables ***
# Export directory under src/ (will be automatically created and gitignored)
${EXPORT_DIR}         ${CURDIR}/../../../src/exported_assets
${TIMESTAMP}          ${EMPTY}
${EXPORT_FILENAME}    ${EMPTY}

# Optional variables that can be overridden from command line (make targets)
# Using safe defaults that don't reference undefined variables
${PROJECT_PATH}       ${EMPTY}
${ASSET_TYPES}        All
${EXPORT_FILE_NAME}   ${EMPTY}
${IMPORT_PATH}        ${EMPTY}
${ZIP_FILE_PATH}      ${EMPTY}
${DUPLICATE_CHECK}    false


*** Test Cases ***
Export Assets From a Project
    [Documentation]    Exports pipeline assets from SnapLogic project to a local backup folder.
    ...    This test case creates a backup of all pipeline assets (pipelines, accounts, etc.)
    ...    by exporting them as a ZIP file to a local directory for version control,
    ...    disaster recovery, or migration purposes.
    ...
    ...    📋 PREREQUISITES:
    ...    • Pipeline and related assets exist in the SnapLogic project
    ...    • Local backup directory is writable
    ...    • ${ORG_SNODE_ID} is set (done during suite setup)
    ...
    ...    📋 ARGUMENT DETAILS:
    ...    • Argument 1: project_path - Path to the project in SnapLogic
    ...    (e.g., ${PIPELINES_LOCATION_PATH} = shared/pipelines or project_space/project)
    ...    • Argument 2: save_to_file - Local file path where the exported ZIP will be saved
    ...    (e.g., ${CURDIR}/src/exported_assets/snowflake_backup.zip)
    ...    • Argument 3: asset_types (Optional) - Type of assets to export
    ...    (default: All - exports pipelines, accounts, and all other assets)
    ...    Options: All, Pipeline, Account, File, etc.
    ...
    ...    💡 TO EXPORT MULTIPLE PROJECTS OR ASSET TYPES:
    ...    You can add multiple records to export different projects or asset types:
    ...    # Export all assets from pipelines folder
    ...    ${PIPELINES_LOCATION_PATH}    ${EXPORT_DIR}/all_assets_${TIMESTAMP}.zip    All
    ...    # Export only pipelines
    ...    ${PIPELINES_LOCATION_PATH}    ${EXPORT_DIR}/pipelines_only_${TIMESTAMP}.zip    Pipeline
    ...    # Export from different project paths
    ...    shared/accounts    ${EXPORT_DIR}/accounts_backup_${TIMESTAMP}.zip    Account
    ...
    ...    📝 USAGE EXAMPLES:
    ...    # Example 1: Export all assets with timestamp (automatically added)
    ...    ${PIPELINES_LOCATION_PATH}    ${EXPORT_DIR}/backup_${TIMESTAMP}.zip
    ...
    ...    # Example 2: Export only pipelines
    ...    ${PIPELINES_LOCATION_PATH}    ${EXPORT_DIR}/pipelines_${TIMESTAMP}.zip    Pipeline
    ...
    ...    # Example 3: Export to different locations
    ...    project_space/dev    ${EXPORT_DIR}/dev_backup_${TIMESTAMP}.zip
    ...    project_space/prod    ${EXPORT_DIR}/prod_backup_${TIMESTAMP}.zip
    ...
    ...    📋 ASSERTIONS:
    ...    • Export API call succeeds with status 200
    ...    • ZIP file is created at the specified location
    ...    • ZIP file contains the expected assets
    ...
    ...    📁 EXPORT LOCATION:
    ...    Files are exported to: ${EXPORT_DIR}
    ...    This directory is automatically created and excluded from git
    ...
    ...    🎯 OPTIONAL PARAMETERS (can be overridden from make):
    ...    • PROJECT_PATH (default: ${PIPELINES_LOCATION_PATH} if available)
    ...    • ASSET_TYPES (default: All)
    ...    • EXPORT_FILE_NAME (default: snaplogic_assets_backup_<TIMESTAMP>.zip)
    [Tags]    export_assets    assets
    [Template]    Export Assets Template
    ${PROJECT_PATH}    ${EXPORT_FILENAME}    ${ASSET_TYPES}

Import Assets To a project
    [Documentation]    Imports pipeline assets from a backup ZIP file into a SnapLogic project.
    ...    This test case restores pipeline assets from a previously exported backup file,
    ...    allowing you to migrate assets between environments, restore from backups,
    ...    or deploy assets to new project locations.
    ...
    ...    📋 PREREQUISITES:
    ...    • Backup ZIP file exists (created by Export Pipeline Assets test case)
    ...    • Target project path exists in SnapLogic
    ...    • ${ORG_SNODE_ID} is set (done during suite setup)
    ...    • User has permissions to import assets to the target path
    ...
    ...    📋 ARGUMENT DETAILS:
    ...    • Argument 1: import_path - Target path in SnapLogic where assets will be imported
    ...    (e.g., ${PIPELINES_LOCATION_PATH}_restored or shared/imported_pipelines)
    ...    Note: This can be the same path (to restore) or different path (to migrate/clone)
    ...    • Argument 2: zip_file_path - Local path to the backup ZIP file to import
    ...    (e.g., ${EXPORT_DIR}/snaplogic_assets_backup_<timestamp>.zip)
    ...    • Argument 3: duplicate_check (Optional) - Whether to check for duplicate assets
    ...    (default: false - allows overwriting existing assets)
    ...    Options: true (prevent duplicates), false (allow overwrite)
    ...
    ...    💡 COMMON USE CASES:
    ...    # Use Case 1: Import to new location (migration/cloning) - RECOMMENDED
    ...    shared/imported_pipelines    ${EXPORT_DIR}/backup.zip    false
    ...
    ...    # Use Case 2: Restore to original location (overwrite existing)
    ...    ${PIPELINES_LOCATION_PATH}    ${EXPORT_DIR}/backup.zip    false
    ...
    ...    # Use Case 3: Import with duplicate check (prevent overwrite)
    ...    ${PIPELINES_LOCATION_PATH}    ${EXPORT_DIR}/backup.zip    true
    ...
    ...    📝 USAGE EXAMPLES:
    ...    # Example 1: Import to a different location (recommended to avoid conflicts)
    ...    ${PIPELINES_LOCATION_PATH}_restored    ${EXPORT_DIR}/snaplogic_assets_backup_20241022_143000.zip
    ...
    ...    # Example 2: Import to same location with duplicate check
    ...    ${PIPELINES_LOCATION_PATH}    ${EXPORT_DIR}/snaplogic_assets_backup_20241022_143000.zip    true
    ...
    ...    📋 ASSERTIONS:
    ...    • ZIP file exists and is readable
    ...    • Import API call succeeds with status 200
    ...    • Assets are imported to the specified location
    ...    • Import result contains success status
    ...
    ...    ⚠️    NOTE: Importing to a NEW location (e.g., ${PIPELINES_LOCATION_PATH}_restored)
    ...    is recommended to avoid conflicts with existing pipelines.
    ...
    ...    🎯 OPTIONAL PARAMETERS (can be overridden from make):
    ...    • IMPORT_PATH (default: ${PROJECT_SPACE}/test if PROJECT_SPACE is defined)
    ...    • ZIP_FILE_PATH (default: src/exported_assets/snaplogic_assets_backup_<TIMESTAMP>.zip)
    ...    • DUPLICATE_CHECK (default: false)
    [Tags]    import_assets    assets
    [Template]    Import Assets Template
    ${IMPORT_PATH}    ${ZIP_FILE_PATH}    ${DUPLICATE_CHECK}


*** Keywords ***
Setup Export Directory
    [Documentation]    Creates the export directory and generates a timestamp for unique filenames.
    ...    This keyword runs before all tests in the suite.
    ...    Creates: ${EXPORT_DIR} directory under src/
    ...    Generates: Timestamp in format YYYYMMDD_HHMMSS
    ...    Sets up safe defaults for variables that might not be defined
    Log    Setting up export directory: ${EXPORT_DIR}

    # Create the export directory if it doesn't exist
    Create Directory    ${EXPORT_DIR}
    Log    Export directory created: ${EXPORT_DIR}

    # Generate timestamp for unique backup filenames
    ${current_time}=    Get Current Date    result_format=%Y%m%d_%H%M%S
    Set Suite Variable    ${TIMESTAMP}    ${current_time}
    Log    Timestamp generated: ${TIMESTAMP}

    # Set PROJECT_PATH default if not provided
    ${project_path_final}=    Run Keyword If    '${PROJECT_PATH}' == '${EMPTY}'
    ...    Get Default Project Path
    ...    ELSE    Set Variable    ${PROJECT_PATH}
    Set Suite Variable    ${PROJECT_PATH}    ${project_path_final}
    Log    Project path: ${PROJECT_PATH}

    # Determine the export filename (custom or timestamped)
    ${export_file}=    Set Variable If    
    ...    '${EXPORT_FILE_NAME}' != '${EMPTY}'    ${EXPORT_FILE_NAME}
    ...    snaplogic_assets_backup_${TIMESTAMP}.zip
    Set Suite Variable    ${EXPORT_FILENAME}    ${EXPORT_DIR}/${export_file}
    Log    Export filename: ${EXPORT_FILENAME}

    # Set default IMPORT_PATH if not provided
    ${import_path_final}=    Run Keyword If    '${IMPORT_PATH}' == '${EMPTY}'
    ...    Get Default Import Path
    ...    ELSE    Set Variable    ${IMPORT_PATH}
    Set Suite Variable    ${IMPORT_PATH}    ${import_path_final}
    Log    Import path: ${IMPORT_PATH}

    # Set default ZIP_FILE_PATH for import if not provided
    ${import_zip}=    Set Variable If
    ...    '${ZIP_FILE_PATH}' == '${EMPTY}'    ${EXPORT_DIR}/snaplogic_assets_backup_${TIMESTAMP}.zip
    ...    ${ZIP_FILE_PATH}
    Set Suite Variable    ${ZIP_FILE_PATH}    ${import_zip}
    Log    Import ZIP file path: ${ZIP_FILE_PATH}

Get Default Project Path
    [Documentation]    Returns default project path, checking if PIPELINES_LOCATION_PATH is available
    ${has_pipelines_path}=    Run Keyword And Return Status    Variable Should Exist    ${PIPELINES_LOCATION_PATH}
    ${default_path}=    Set Variable If    ${has_pipelines_path}    ${PIPELINES_LOCATION_PATH}    shared/pipelines
    Log    Using default project path: ${default_path}
    RETURN    ${default_path}

Get Default Import Path
    [Documentation]    Returns default import path, checking if PROJECT_SPACE is available
    ${has_project_space}=    Run Keyword And Return Status    Variable Should Exist    ${PROJECT_SPACE}
    ${default_path}=    Set Variable If    ${has_project_space}    ${PROJECT_SPACE}/test    shared/imported_pipelines
    Log    Using default import path: ${default_path}
    RETURN    ${default_path}
