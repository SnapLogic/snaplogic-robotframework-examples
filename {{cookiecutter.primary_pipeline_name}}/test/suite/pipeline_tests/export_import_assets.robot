*** Settings ***
# Standard Libraries
Library         OperatingSystem    # File system operations
Library         DateTime    # For timestamp generation
Resource        snaplogic_common_robot/snaplogic_apis_keywords/snaplogic_keywords.resource    # SnapLogic API keywords from installed package

Suite Setup     Setup Export Directory


*** Variables ***
# Export directory under src/ (will be automatically created and added to gitignore)
${export_dir}               ${CURDIR}/../../../src/exported_assets
${export_file_name}         snaplogic_assets_backup2.zip
${timestamp}                ${EMPTY}

${PROJECT_PATH}             ${EMPTY}
${asset_types}              Pipeline
${import_path}              ${PROJECT_SPACE}/test
${zip_file_path}            ${EMPTY}
${duplicate_check}          false
${pipeline_file_name}       snowflake.slp


*** Test Cases ***
Export Assets From a Project
    [Documentation]    Exports pipeline assets from SnapLogic project to a local backup folder.
    ...    This test case creates a backup of all pipeline assets (pipelines, accounts, etc.)
    ...    by exporting them as a ZIP file to a local directory for version control,
    ...    disaster recovery, or migration purposes.
    ...
    ...    📋 PREREQUISITES:
    ...    • Pipeline and related assets exist in the SnapLogic project
    ...
    ...    📋 ARGUMENT DETAILS:
    ...    • Argument 1: project_path - Path of the project From which assets to be exported
    ...    (e.g., ${PIPELINES_LOCATION_PATH} = shared/pipelines or project_space/project)
    ...    • Argument 2: save_to_file - Local file path where the exported ZIP will be saved
    ...    (e.g., ${CURDIR}/src/exported_assets/snowflake_backup.zip)
    ...    • Argument 3: asset_types (Optional) - Type of assets to export
    ...    (default: All - exports pipelines, accounts, and all other assets)
    ...    Options: All, Pipeline, Account, File, etc.
    ...
    ...    📁 EXPORT LOCATION:
    ...    Files are exported to: ${export_dir}
    ...    This directory is automatically created and excluded from git
    [Tags]    export_assets    assets
    [Template]    Export Assets Template

    ${PROJECT_PATH}    ${export_filename}    ${asset_types}

Import Assets To a project
    [Documentation]    Imports pipeline assets from a backup ZIP file into a SnapLogic project.
    ...    This test case imports    assets from a previously exported backup file,
    ...
    ...    📋 PREREQUISITES:
    ...    • Backup ZIP file exists (created by Export Pipeline Assets test case)
    ...    • Target project path exists in SnapLogic
    ...    • User has permissions to import assets to the target path
    ...
    ...    📋 ARGUMENT DETAILS:
    ...    • Argument 1: import_path - Target path in SnapLogic where assets will be imported
    ...    (e.g., ${PIPELINES_LOCATION_PATH}_restored or shared/imported_pipelines)
    ...    Note: This can be the same path (to restore) or different path (to migrate/clone)
    ...    • Argument 2: zip_file_path - Local path to the backup ZIP file to import
    ...    (e.g., ${export_dir}/snaplogic_assets_backup_<timestamp>.zip)
    ...    • Argument 3: duplicate_check (Optional) - Whether to check for duplicate assets
    ...    (default: false - allows overwriting existing assets)
    ...    Options: true (prevent duplicates), false (allow overwrite)
    ...
    ...    ⚠️    NOTE: Importing to a NEW location (e.g., ${PIPELINES_LOCATION_PATH}_restored)
    ...    is recommended to avoid conflicts with existing pipelines.
    [Tags]    import_assets    assets
    [Template]    Import Assets Template
    ${import_path}    ${export_filename}    ${duplicate_check}

Import Pipeline
    [Documentation]    Imports Snowflake pipeline files (.slp) into the SnapLogic project space.
    ...    This test case uploads pipeline definitions and deploys them to the specified location,
    ...    making them available for task creation and execution.
    ...
    ...    📋 PREREQUISITES:
    ...    • ${unique_id} - Generated from suite setup (Check connections keyword)
    ...    • Pipeline .slp files must exist in the test_data directory
    ...    • SnapLogic project and folder structure must be in place
    ...
    ...    📋 ARGUMENT DETAILS:
    ...    • Argument 1: ${unique_id} - Unique test execution identifier for naming/tracking
    ...    (Generated automatically in suite setup)
    ...    • Argument 2: ${PIPELINES_LOCATION_PATH} - SnapLogic folder path where pipelines will be imported
    ...    (e.g., /org/project/pipelines or /shared/pipelines)
    ...    • Argument 3: ${pipeline_name} - Logical name for the pipeline (without .slp extension)
    ...    (e.g., snowflake_pl1, data_processor, etl_pipeline)
    ...    • Argument 4: ${pipeline_file_name} - Physical .slp file name to import
    ...    (e.g., snowflake1.slp, pipeline.slp)
    ...
    ...    💡 TO IMPORT MULTIPLE PIPELINES:
    ...    You can import multiple pipeline files by adding more records to this template.
    ...    Each record represents one pipeline import operation.
    [Tags]    upload_pipeline

    Log To Console
    ...    GENERATIVE_SLP_PIPELINES_PATH path is:${GENERATIVE_SLP_PIPELINES_PATH}/${pipeline_file_name}

    Import Pipeline
    ...    ${GENERATIVE_SLP_PIPELINES_PATH}/${pipeline_file_name}
    ...    ${pipeline_file_name}
    ...    ${project_path}


*** Keywords ***
Setup Export Directory
    [Documentation]    Creates the export directory and generates a timestamp for unique filenames.
    ...    This keyword runs before all tests in the suite.
    ...    Creates: ${export_dir} directory under src/
    ...    Generates: timestamp in format YYYYMMDD_HHMMSS
    ...    Sets up safe defaults for variables that might not be defined
    Log    Setting up export directory: ${export_dir}

    # Create the export directory if it doesn't exist
    Create Directory    ${export_dir}
    Log    Export directory created: ${export_dir}

    # Generate timestamp for unique backup filenames
    ${current_time}=    Get Current Date    result_format=%Y%m%d_%H%M%S
    Set Suite Variable    ${timestamp}    ${current_time}
    Log    timestamp generated: ${timestamp}

    # Determine the export filename if it is empty (custom or timestamped) also make it as suite variable
    ${export_file}=    Set Variable If
    ...    '${export_file_name}' != '${EMPTY}'    ${export_file_name}
    ...    snaplogic_assets_backup_${timestamp}.zip
    Set Suite Variable    ${export_filename}    ${export_dir}/${export_file}
    Log    Export filename: ${export_filename}
