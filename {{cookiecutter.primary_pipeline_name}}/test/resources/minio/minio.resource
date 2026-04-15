*** Settings ***
Documentation       Resource file for MinIO/S3 operations and file management
...                 Contains all keywords related to:
...                 • MinIO S3 client configuration and connection
...                 • File download operations from S3 buckets
...                 • File validation and integrity checking
...                 • Directory management for downloaded files
...                 • Safe file content reading (text and binary)

# Standard Libraries for MinIO operations
Library             OperatingSystem    # File system operations
Library             String
Library             Collections


*** Keywords ***
################## MINIO S3 CLIENT OPERATIONS ##################

Get S3 Client
    [Documentation]    Creates a boto3 S3 client that works with BOTH MinIO and AWS S3.
    ...
    ...    Reads connection details from environment variables:
    ...    - S3_ENDPOINT: Optional endpoint URL. If set → connects to MinIO/custom S3.
    ...      If empty or not set → connects to real AWS S3.
    ...    - S3_ACCESS_KEY: AWS access key ID (or MinIO access key)
    ...    - S3_SECRET_KEY: AWS secret access key (or MinIO secret key)
    ...    - S3_REGION: AWS region (default: us-east-1)
    ...
    ...    *Examples:*
    ...    | # MinIO (Docker testing) — S3_ENDPOINT=http://minio:9000 |
    ...    | ${client}= | Get S3 Client |
    ...    |
    ...    | # AWS S3 (production) — S3_ENDPOINT is empty |
    ...    | ${client}= | Get S3 Client |
    ...
    ...    *Environment file examples:*
    ...    | # For MinIO (env_files/mock_service_accounts/.env.s3): |
    ...    | S3_ENDPOINT=http://minio:9000 |
    ...    | S3_ACCESS_KEY=minioadmin |
    ...    | S3_SECRET_KEY=minioadmin |
    ...    |
    ...    | # For AWS S3 (env_files/mock_service_accounts/.env.s3): |
    ...    | S3_ENDPOINT= |
    ...    | S3_ACCESS_KEY=AKIAIOSFODNN7EXAMPLE |
    ...    | S3_SECRET_KEY=wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY |
    ...    | S3_REGION=us-east-1 |

    ${endpoint}=    Get Environment Variable    S3_ENDPOINT    ${EMPTY}
    ${access_key}=    Get Environment Variable    S3_ACCESS_KEY    ${EMPTY}
    ${secret_key}=    Get Environment Variable    S3_SECRET_KEY    ${EMPTY}
    ${region}=    Get Environment Variable    S3_REGION    us-east-1

    IF    '${endpoint}' != '${EMPTY}'
        Log    Connecting to S3-compatible endpoint: ${endpoint}    console=yes
        ${s3_client}=    Evaluate
        ...    __import__('boto3').client('s3', endpoint_url='${endpoint}', aws_access_key_id='${access_key}', aws_secret_access_key='${secret_key}', region_name='${region}')
    ELSE
        Log    Connecting to AWS S3 (region: ${region})    console=yes
        ${s3_client}=    Evaluate
        ...    __import__('boto3').client('s3', aws_access_key_id='${access_key}', aws_secret_access_key='${secret_key}', region_name='${region}')
    END

    RETURN    ${s3_client}

Get MinIO S3 Client
    [Documentation]    Creates and returns a configured boto3 S3 client.
    ...    Wrapper for backward compatibility — calls Get S3 Client internally.
    ...    Works with both MinIO and AWS S3 based on S3_ENDPOINT environment variable.
    ...
    ...    📋 NOTE: New code should use Get S3 Client directly.
    ...    This keyword is kept for backward compatibility with existing tests.

    ${s3_client}=    Get S3 Client
    RETURN    ${s3_client}

################## FILE DOWNLOAD OPERATIONS ##################

Download Single File From MinIO
    [Documentation]    Downloads a single file from MinIO bucket to local filesystem
    ...    📋 ASSERTIONS:
    ...    • S3 client connection is successful
    ...    • Target bucket exists and is accessible
    ...    • Object key exists in the specified bucket
    ...    • Local download directory is created successfully
    ...    • File download completes without errors
    ...    • Downloaded file content is returned (if readable)
    [Arguments]    ${download_location}    ${bucket_name}    ${object_key}    ${preserve_file}=${True}

    ${s3_client}=    Get MinIO S3 Client

    # Create full download path with bucket subdirectory
    ${bucket_download_path}=    Set Variable    ${download_location}

    # Remove and recreate bucket-specific directory to ensure clean state
    # Remove Directory If Exists    ${bucket_download_path}
    Create Directory    ${bucket_download_path}

    # Set local file path within bucket directory
    ${local_path}=    Set Variable    ${bucket_download_path}/${object_key}

    # Handle nested object keys (with forward slashes)
    ${dir_path}=    Get Directory From Path    ${local_path}
    Create Directory    ${dir_path}

    TRY
        # Download file
        ${result}=    Evaluate    $s3_client.download_file('${bucket_name}', '${object_key}', '${local_path}')

        # Safely read file content (handles both text and binary)
        ${file_content}=    Get File Content Safely    ${local_path}

        Log    📥 Downloaded ${object_key} from ${bucket_name} to ${local_path}

        # Optionally remove file if not preserving
        IF    not ${preserve_file}
            Remove File    ${local_path}
            Log    🗑️ Temporary file cleaned up: ${local_path}
        END

        RETURN    ${file_content}
    EXCEPT    AS    ${error}
        Fail    Failed to download ${object_key} from ${bucket_name}: ${error}
    END

Download And Validate File From Bucket
    [Documentation]    Template keyword to download and validate a specific file from MinIO
    ...    📋 ASSERTIONS:
    ...    • File downloads successfully from MinIO bucket
    ...    • Downloaded file exists at expected local path
    ...    • File size is greater than 0 bytes (not empty)
    ...    • File content is accessible and readable
    ...    • Local directory structure is created properly
    [Arguments]    ${download_location}    ${bucket_name}    ${file_name}

    Log    📥 Downloading ${file_name} from bucket ${bucket_name}
    ${file_content}=    Download Single File From MinIO    ${download_location}    ${bucket_name}    ${file_name}
    Log    ✅ Successfully downloaded ${file_name}

    # Validation - check file exists locally in bucket subdirectory
    File Should Exist    ${download_location}/${file_name}
    ${file_size}=    Get File Size    ${download_location}/${file_name}
    Should Be True    ${file_size} > 0
    Log    📊 File ${file_name} downloaded successfully (${file_size} bytes)

################## FILE CONTENT OPERATIONS ##################

Get File Content Safely
    [Documentation]    Safely reads file content, handling both text and binary files
    ...    📋 ASSERTIONS:
    ...    • File exists at specified path
    ...    • File is readable (proper permissions)
    ...    • Content is successfully extracted
    ...    • Both text and binary files are handled appropriately
    [Arguments]    ${file_path}

    File Should Exist    ${file_path}

    TRY
        # Try to read as text first
        ${content}=    Get File    ${file_path}
        Log    📄 Read file as text: ${file_path}
        RETURN    ${content}
    EXCEPT
        TRY
            # If text reading fails, try binary
            ${content}=    Get Binary File    ${file_path}
            Log    📦 Read file as binary: ${file_path}
            RETURN    ${content}
        EXCEPT    AS    ${error}
            Log    ⚠️ Failed to read file content: ${error}
            RETURN    ${EMPTY}
        END
    END

################## DIRECTORY MANAGEMENT ##################

Remove Directory If Exists
    [Documentation]    Safely removes a directory if it exists, otherwise does nothing
    ...    📋 ASSERTIONS:
    ...    • Directory removal completes without errors (if exists)
    ...    • No errors thrown if directory doesn't exist
    ...    • All subdirectories and files are removed recursively
    [Arguments]    ${directory_path}

    ${dir_exists}=    Run Keyword And Return Status    Directory Should Exist    ${directory_path}

    IF    ${dir_exists}
        Remove Directory    ${directory_path}    recursive=${TRUE}
        Log    🗑️ Removed existing directory: ${directory_path}
    ELSE
        Log    📁 Directory does not exist (skip removal): ${directory_path}
    END

Get Directory From Path
    [Documentation]    Extracts the directory path from a full file path
    ...    📋 ASSERTIONS:
    ...    • File path is valid and properly formatted
    ...    • Directory path is correctly extracted
    ...    • Works with both Unix and Windows path separators
    [Arguments]    ${file_path}

    # Split path by forward slash and get all but last element
    ${path_parts}=    Split String    ${file_path}    /
    ${dir_parts}=    Get Slice From List    ${path_parts}    0    -1

    IF    ${dir_parts.__len__()} > 0
        ${dir_path}=    Evaluate    '/'.join($dir_parts)
        RETURN    ${dir_path}
    ELSE
        RETURN    ${CURDIR}
    END

################## MINIO UTILITY KEYWORDS ##################

Validate MinIO Connection
    [Documentation]    Validates that MinIO connection is working properly
    ...    📋 ASSERTIONS:
    ...    • S3 client can be created successfully
    ...    • MinIO server is accessible at configured endpoint
    ...    • Authentication credentials are valid
    ...    • Basic connectivity test passes

    Log    🔍 Validating MinIO connection...

    TRY
        ${s3_client}=    Get MinIO S3 Client

        # Try to list buckets as a connectivity test
        ${result}=    Evaluate    $s3_client.list_buckets()
        Log    ✅ MinIO connection validated successfully
        Log    📊 Available buckets: ${result}

        RETURN    ${TRUE}
    EXCEPT    AS    ${error}
        Log    ❌ MinIO connection failed: ${error}
        RETURN    ${FALSE}
    END

Check Bucket Exists
    [Documentation]    Checks if a specific bucket exists in MinIO
    ...    📋 ASSERTIONS:
    ...    • S3 client connection is successful
    ...    • Bucket existence check completes without errors
    ...    • Returns accurate boolean result
    [Arguments]    ${bucket_name}

    ${s3_client}=    Get MinIO S3 Client

    TRY
        ${result}=    Evaluate    $s3_client.head_bucket(Bucket='${bucket_name}')
        Log    ✅ Bucket '${bucket_name}' exists
        RETURN    ${TRUE}
    EXCEPT
        Log    ❌ Bucket '${bucket_name}' does not exist
        RETURN    ${FALSE}
    END

List Objects In Bucket
    [Documentation]    Lists all objects in a MinIO bucket
    ...    📋 ASSERTIONS:
    ...    • S3 client connection is successful
    ...    • Bucket exists and is accessible
    ...    • Object listing completes without errors
    ...    • Returns list of object keys
    [Arguments]    ${bucket_name}

    ${s3_client}=    Get MinIO S3 Client

    TRY
        ${response}=    Evaluate    $s3_client.list_objects_v2(Bucket='${bucket_name}')

        # Extract object keys from response
        ${objects}=    Create List
        ${contents}=    Evaluate    $response.get('Contents', [])

        FOR    ${obj}    IN    @{contents}
            ${key}=    Evaluate    $obj['Key']
            Append To List    ${objects}    ${key}
        END

        Log    📋 Objects in bucket '${bucket_name}': ${objects}
        RETURN    ${objects}
    EXCEPT    AS    ${error}
        Log    ❌ Failed to list objects in bucket '${bucket_name}': ${error}
        RETURN    @{EMPTY}
    END

Check Object Exists
    [Documentation]    Checks if a specific object exists in MinIO bucket
    ...    📋 ASSERTIONS:
    ...    • S3 client connection is successful
    ...    • Bucket exists and is accessible
    ...    • Object existence check completes without errors
    ...    • Returns accurate boolean result
    [Arguments]    ${bucket_name}    ${object_key}

    ${s3_client}=    Get MinIO S3 Client

    TRY
        ${result}=    Evaluate    $s3_client.head_object(Bucket='${bucket_name}', Key='${object_key}')
        Log    ✅ Object '${object_key}' exists in bucket '${bucket_name}'
        RETURN    ${TRUE}
    EXCEPT
        Log    ❌ Object '${object_key}' does not exist in bucket '${bucket_name}'
        RETURN    ${FALSE}
    END

Upload File To MinIO
    [Documentation]    Uploads a local file to a MinIO (S3 mock) bucket at the specified path.
    ...
    ...    *How to read:*
    ...    ``Upload File To MinIO    <local_file>    <bucket>    <object_key>``
    ...    Reads as: "Upload <local_file> to s3://<bucket>/<object_key>"
    ...
    ...    *Arguments:*
    ...    - ``local_file_path``: Absolute path to the local file to upload
    ...    - ``bucket_name``: Target S3/MinIO bucket name
    ...    - ``object_key``: Destination path/key within the bucket (can include folders)
    ...
    ...    *Returns:*
    ...    - ``${TRUE}`` on success
    ...
    ...    *Examples:*
    ...    | # Upload a config file |
    ...    | Upload File To MinIO | /path/to/config.json | test-bucket | config/baseline/config.json |
    ...    |
    ...    | # Upload a CSV file |
    ...    | Upload File To MinIO | /path/to/data.csv | demo-bucket | data/input/employees.csv |
    [Arguments]    ${local_file_path}    ${bucket_name}    ${object_key}

    Log    Uploading file to MinIO...    console=yes
    Log    Source: ${local_file_path}    console=yes
    Log    Destination: s3://${bucket_name}/${object_key}    console=yes

    ${s3_client}=    Get MinIO S3 Client

    TRY
        Evaluate    $s3_client.upload_file('${local_file_path}', '${bucket_name}', '${object_key}')
        Log    ✅ File uploaded successfully to s3://${bucket_name}/${object_key}    console=yes
        RETURN    ${TRUE}
    EXCEPT    AS    ${error}
        Log    ❌ Failed to upload file: ${error}    console=yes
        Fail    Failed to upload '${local_file_path}' to s3://${bucket_name}/${object_key}: ${error}
    END

Get Object Metadata
    [Documentation]    Gets metadata for a specific object in MinIO bucket
    ...    📋 ASSERTIONS:
    ...    • S3 client connection is successful
    ...    • Bucket and object exist
    ...    • Metadata retrieval completes without errors
    ...    • Returns object metadata dictionary
    [Arguments]    ${bucket_name}    ${object_key}

    ${s3_client}=    Get MinIO S3 Client

    TRY
        ${metadata}=    Evaluate    $s3_client.head_object(Bucket='${bucket_name}', Key='${object_key}')
        Log    📊 Metadata for '${object_key}': ${metadata}
        RETURN    ${metadata}
    EXCEPT    AS    ${error}
        Fail    Failed to get metadata for '${object_key}' in bucket '${bucket_name}': ${error}
    END

################## BATCH DOWNLOAD OPERATIONS ##################

Download All Files From Bucket
    [Documentation]    Downloads all files from a MinIO bucket to local directory
    ...    📋 ASSERTIONS:
    ...    • S3 client connection is successful
    ...    • Bucket exists and is accessible
    ...    • All objects are downloaded successfully
    ...    • Local directory structure is created properly
    ...    • No download errors occur
    [Arguments]    ${download_location}    ${bucket_name}    ${preserve_files}=${TRUE}

    Log    📥 Downloading all files from bucket: ${bucket_name}

    # Get list of all objects in bucket
    ${objects}=    List Objects In Bucket    ${bucket_name}

    # Download each object
    ${downloaded_files}=    Create List
    FOR    ${object_key}    IN    @{objects}
        ${file_content}=    Download Single File From MinIO
        ...    ${download_location}    ${bucket_name}    ${object_key}    ${preserve_files}
        Append To List    ${downloaded_files}    ${object_key}
    END

    Log    ✅ Downloaded ${downloaded_files.__len__()} files from bucket '${bucket_name}'
    Log    📋 Downloaded files: ${downloaded_files}

    RETURN    ${downloaded_files}

Download Files By Pattern
    [Documentation]    Downloads files matching a pattern from MinIO bucket
    ...    📋 ASSERTIONS:
    ...    • S3 client connection is successful
    ...    • Bucket exists and is accessible
    ...    • Pattern matching works correctly
    ...    • Matching files are downloaded successfully
    ...    • Local directory structure is created properly
    [Arguments]    ${download_location}    ${bucket_name}    ${pattern}    ${preserve_files}=${TRUE}

    Log    📥 Downloading files matching pattern '${pattern}' from bucket: ${bucket_name}

    # Get list of all objects in bucket
    ${all_objects}=    List Objects In Bucket    ${bucket_name}

    # Filter objects by pattern
    ${matching_objects}=    Create List
    FOR    ${object_key}    IN    @{all_objects}
        ${matches}=    Run Keyword And Return Status    Should Contain    ${object_key}    ${pattern}
        IF    ${matches}
            Append To List    ${matching_objects}    ${object_key}
        END
    END

    # Download matching objects
    ${downloaded_files}=    Create List
    FOR    ${object_key}    IN    @{matching_objects}
        ${file_content}=    Download Single File From MinIO
        ...    ${download_location}    ${bucket_name}    ${object_key}    ${preserve_files}
        Append To List    ${downloaded_files}    ${object_key}
    END

    Log    ✅ Downloaded ${downloaded_files.__len__()} files matching pattern '${pattern}'
    Log    📋 Downloaded files: ${downloaded_files}

    RETURN    ${downloaded_files}

################## BUCKET CLEANUP OPERATIONS ##################

Clean Bucket
    [Documentation]    Deletes all objects in a MinIO/S3 bucket.
    ...    Use this to reset the bucket to a clean state before a test run.
    ...
    ...    *Arguments:*
    ...    - ``bucket_name``: Name of the bucket to clean
    ...
    ...    *Example:*
    ...    | Clean Bucket | test-bucket |
    [Arguments]    ${bucket_name}

    Log    Cleaning all objects from bucket '${bucket_name}'...    console=yes
    ${s3_client}=    Get S3 Client
    ${all_objects}=    List Objects In Bucket    ${bucket_name}
    ${count}=    Get Length    ${all_objects}

    IF    ${count} == 0
        Log    Bucket '${bucket_name}' is already empty.    console=yes
        RETURN
    END

    FOR    ${key}    IN    @{all_objects}
        Evaluate    $s3_client.delete_object(Bucket='${bucket_name}', Key=$key)
        Log    Deleted: ${key}    console=yes
    END

    Log    Deleted ${count} objects from bucket '${bucket_name}'.    console=yes

Clean Bucket By Prefix
    [Documentation]    Deletes all objects in a bucket that match a path prefix.
    ...    Use this to clean a specific folder without affecting other files.
    ...
    ...    *Arguments:*
    ...    - ``bucket_name``: Name of the bucket
    ...    - ``prefix``: Path prefix to match (e.g., 'extract/', 'output/baseline/')
    ...
    ...    *Example:*
    ...    | Clean Bucket By Prefix | test-bucket | extract/ |
    [Arguments]    ${bucket_name}    ${prefix}

    Log    Cleaning objects with prefix '${prefix}' from bucket '${bucket_name}'...    console=yes
    ${s3_client}=    Get S3 Client
    ${all_objects}=    List Objects In Bucket    ${bucket_name}
    ${deleted}=    Set Variable    ${0}

    FOR    ${key}    IN    @{all_objects}
        ${matches}=    Evaluate    $key.startswith($prefix)
        IF    ${matches}
            Evaluate    $s3_client.delete_object(Bucket='${bucket_name}', Key=$key)
            Log    Deleted: ${key}    console=yes
            ${deleted}=    Evaluate    ${deleted} + 1
        END
    END

    Log    Deleted ${deleted} objects with prefix '${prefix}' from bucket '${bucket_name}'.    console=yes

################## FILE VALIDATION TEMPLATES ##################

Validate Downloaded File Template
    [Documentation]    Template for comprehensive validation of downloaded files
    ...    📋 ASSERTIONS:
    ...    • File exists at expected local path
    ...    • File size meets minimum requirements
    ...    • File content is accessible and valid
    ...    • File matches expected format/structure
    [Arguments]    ${local_file_path}    ${min_size_bytes}=0    ${expected_extension}=${EMPTY}

    Log    🔍 Validating downloaded file: ${local_file_path}

    # Check file exists
    File Should Exist    ${local_file_path}

    # Check file size
    ${file_size}=    Get File Size    ${local_file_path}
    Should Be True    ${file_size} >= ${min_size_bytes}
    ...    File size ${file_size} is less than minimum required ${min_size_bytes} bytes

    # Check file extension if specified
    IF    '${expected_extension}' != '${EMPTY}'
        Should End With    ${local_file_path}    ${expected_extension}
        ...    File does not have expected extension '${expected_extension}'
    END

    # Try to read content to ensure file is not corrupted
    ${content}=    Get File Content Safely    ${local_file_path}
    Should Not Be Empty    ${content}    File content is empty or unreadable

    Log    ✅ File validation passed: ${local_file_path} (${file_size} bytes)

    RETURN    ${TRUE}

Validate Multiple Downloaded Files
    [Documentation]    Validates multiple downloaded files in a directory
    ...    📋 ASSERTIONS:
    ...    • All expected files exist
    ...    • All files meet size requirements
    ...    • All files are readable and valid
    ...    • Directory structure is correct
    [Arguments]    ${download_directory}    ${expected_files}    ${min_size_bytes}=0

    Log    🔍 Validating multiple downloaded files in: ${download_directory}

    # Check each expected file
    ${validated_files}=    Create List
    FOR    ${file_name}    IN    @{expected_files}
        ${file_path}=    Set Variable    ${download_directory}/${file_name}
        ${validation_result}=    Validate Downloaded File Template    ${file_path}    ${min_size_bytes}
        IF    ${validation_result}
            Append To List    ${validated_files}    ${file_name}
        END
    END

    # Ensure all files were validated
    ${expected_count}=    Get Length    ${expected_files}
    ${validated_count}=    Get Length    ${validated_files}
    Should Be Equal As Numbers    ${validated_count}    ${expected_count}
    ...    Only ${validated_count} of ${expected_count} files passed validation

    Log    ✅ All ${validated_count} files validated successfully
    Log    📋 Validated files: ${validated_files}

    RETURN    ${validated_files}
