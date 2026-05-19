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

# Project libraries — Python helpers that need type-based exception handling
# (botocore raises distinct exception classes for each SSO failure mode,
# which Robot's TRY/EXCEPT can't match by type — only by message substring).
#
# Relative path is resolved from the location of THIS resource file.
# (Tried ${EXECDIR}-based path but it's brittle in this framework because
# Robot is invoked from test/ in some make targets and from / in others.)
Library             ../../libraries/s3/s3_auth_helper.py


*** Keywords ***
################## MINIO S3 CLIENT OPERATIONS ##################

Get S3 Client
    [Documentation]    Creates a boto3 S3 client supporting THREE auth modes:
    ...
    ...    1. MinIO / custom S3-compatible endpoint (Docker local testing)
    ...       S3_ENDPOINT=http://minio:9000
    ...       S3_ACCESS_KEY=minioadmin
    ...       S3_SECRET_KEY=minioadmin
    ...
    ...    2. AWS S3 with explicit access keys
    ...       S3_ENDPOINT= (empty)
    ...       S3_ACCESS_KEY=AKIA...
    ...       S3_SECRET_KEY=...
    ...
    ...    3. AWS S3 with SSO (for IAM role-based environments)
    ...       S3_ENDPOINT= (empty)
    ...       S3_ACCESS_KEY= (empty)
    ...       S3_SECRET_KEY= (empty)
    ...       AWS_PROFILE=<your-sso-profile-name>
    ...       Pre-req: User must run `aws sso login --profile <profile>` first.
    ...
    ...    PRIORITY when multiple are set:
    ...    1. S3_ACCESS_KEY + S3_SECRET_KEY (explicit keys win)
    ...    2. AWS_PROFILE (SSO via `aws sso login`)
    ...    3. boto3 default chain (env vars, ~/.aws, EC2 metadata)
    ...
    ...    This is the top-level orchestrator. It reads env vars, validates
    ...    configuration, then dispatches to one of three Build S3 Client With *
    ...    keywords for the actual client construction. See those for branch-
    ...    specific behavior and error handling.

    ${endpoint}=        Get Environment Variable    S3_ENDPOINT      ${EMPTY}
    ${access_key}=      Get Environment Variable    S3_ACCESS_KEY    ${EMPTY}
    ${secret_key}=      Get Environment Variable    S3_SECRET_KEY    ${EMPTY}
    ${region}=          Get Environment Variable    S3_REGION        us-east-1
    ${profile}=         Get Environment Variable    AWS_PROFILE      ${EMPTY}

    ${has_keys}=        Evaluate    bool($access_key) and bool($secret_key)
    ${has_profile}=     Evaluate    bool($profile)
    ${has_endpoint}=    Evaluate    bool($endpoint)

    # Pre-flight: clean up empty AWS_PROFILE and validate configuration
    Resolve Empty AWS Profile      ${has_endpoint}    ${has_keys}    ${profile}
    Validate S3 Configuration      ${has_endpoint}    ${has_keys}    ${has_profile}    ${profile}

    # Build common kwargs shared by all three modes
    ${kwargs}=    Create Dictionary    region_name=${region}
    IF    ${has_endpoint}
        Set To Dictionary    ${kwargs}    endpoint_url=${endpoint}
    END

    # Dispatch by mode (priority: explicit keys > AWS_PROFILE > default chain)
    IF    ${has_keys}
        ${s3_client}=    Build S3 Client With Access Keys
        ...    ${access_key}    ${secret_key}    ${has_endpoint}    ${endpoint}    ${region}    ${profile}    ${kwargs}
    ELSE IF    ${has_profile}
        ${s3_client}=    Build S3 Client With SSO    ${profile}    ${region}    ${kwargs}
    ELSE
        ${s3_client}=    Build S3 Client With Default Chain    ${region}    ${kwargs}
    END

    RETURN    ${s3_client}

Resolve Empty AWS Profile
    [Documentation]    Handles the edge case where AWS_PROFILE is present in
    ...    os.environ but set to an empty string.
    ...
    ...    Background: docker-compose.yml forwards AWS_PROFILE from the host
    ...    shell with default empty ("AWS_PROFILE: ${AWS_PROFILE:-}"), so
    ...    AWS_PROFILE almost always appears as set-but-empty in the container.
    ...    boto3 reads AWS_PROFILE implicitly during client creation and fails
    ...    with the cryptic "ProfileNotFound: The config profile () could not
    ...    be found" if it's the empty string.
    ...
    ...    Two outcomes:
    ...    - User intended SSO (no endpoint, no keys) → Fail with actionable msg
    ...    - User intended MinIO/keys (endpoint OR keys present) → silently
    ...      pop AWS_PROFILE from os.environ so boto3 won't see it
    ...
    ...    SIDE-EFFECT: when popping, mutates os.environ for the rest of the
    ...    test process. Safe today because env files are loaded once at suite
    ...    setup. A future test that switches mid-run from MinIO/keys to SSO
    ...    would need to re-set AWS_PROFILE explicitly.
    [Arguments]    ${has_endpoint}    ${has_keys}    ${profile}

    ${aws_profile_in_env}=    Evaluate    'AWS_PROFILE' in __import__('os').environ
    IF    not (${aws_profile_in_env} and '${profile}' == '${EMPTY}')
        RETURN
    END

    IF    not ${has_endpoint} and not ${has_keys}
        ${available}=    Get Available AWS Profiles
        Fail
        ...    AWS_PROFILE is set in the test environment but is EMPTY.${\n}Fix: set it to a valid profile name (e.g., AWS_PROFILE=<your-profile> in your root .env), OR remove any empty 'AWS_PROFILE=' line if one exists in .env / env_files/.${\n}Possible sources: root .env, env_files/*.env, host shell export, or docker-compose.yml (which passes AWS_PROFILE from host).${\n}Available profiles in ~/.aws/config: ${available}
    END

    Evaluate    __import__('os').environ.pop('AWS_PROFILE', None)

Validate S3 Configuration
    [Documentation]    Validates the user-provided env configuration.
    ...    - Fails if nothing is configured (no endpoint, no keys, no profile)
    ...    - Warns if endpoint and profile are both set (endpoint silently wins,
    ...      AWS_PROFILE is ignored — usually a user mistake worth flagging)
    [Arguments]    ${has_endpoint}    ${has_keys}    ${has_profile}    ${profile}

    IF    not ${has_keys} and not ${has_profile} and not ${has_endpoint}
        Fail
        ...    No S3 credentials configured. Choose one of:${\n}  (a) MinIO local testing  -> set S3_ENDPOINT=http://minio:9000 (and MinIO keys)${\n}  (b) AWS access keys      -> set S3_ACCESS_KEY + S3_SECRET_KEY${\n}  (c) AWS SSO              -> set AWS_PROFILE=<your-profile-name> and run 'aws sso login --profile <name>'${\n}See env_files/mock_service_accounts/.env.s3 for examples.
    END

    IF    ${has_endpoint} and ${has_profile} and not ${has_keys}
        Log
        ...    WARNING: S3_ENDPOINT is set (MinIO/custom mode) — AWS_PROFILE='${profile}' will be IGNORED. Clear S3_ENDPOINT in .env to use SSO instead.
        ...    level=WARN
    END

Build S3 Client With Access Keys
    [Documentation]    Builds a boto3 S3 client using explicit access keys.
    ...    Used for MinIO (when endpoint is set) and AWS access-key mode (when
    ...    endpoint is empty). Logs a WARN if AWS_PROFILE is also set (it gets
    ...    silently overridden by the explicit keys — user should know).
    [Arguments]    ${access_key}    ${secret_key}    ${has_endpoint}    ${endpoint}    ${region}    ${profile}    ${kwargs}

    IF    '${profile}' != '${EMPTY}'
        Log
        ...    WARNING: Both S3_ACCESS_KEY and AWS_PROFILE='${profile}' are set. Using explicit keys; AWS_PROFILE is IGNORED. Remove S3_ACCESS_KEY and S3_SECRET_KEY from .env to use SSO.
        ...    level=WARN
    END

    Set To Dictionary    ${kwargs}    aws_access_key_id=${access_key}
    Set To Dictionary    ${kwargs}    aws_secret_access_key=${secret_key}

    ${mode_label}=    Set Variable    AWS Access Keys
    IF    ${has_endpoint}
        ${mode_label}=    Set Variable    MinIO / custom endpoint
    END

    ${banner}=    Evaluate    "\\n========== S3 Client Configuration ==========\\n" + "Mode:".ljust(10) + $mode_label + "\\n" + "Endpoint:".ljust(10) + $endpoint + "\\n" + "Region:".ljust(10) + $region + "\\n============================================="
    Log S3 Configuration Banner Once    ${banner}

    ${s3_client}=    Evaluate    __import__('boto3').client('s3', **$kwargs)
    RETURN    ${s3_client}

Build S3 Client With SSO
    [Documentation]    Builds a boto3 S3 client using AWS SSO via the named
    ...    profile. Delegates validation (profile exists + token not expired)
    ...    to Validate SSO Session For Profile, which fails fast with
    ...    actionable messages if anything is wrong.
    [Arguments]    ${profile}    ${region}    ${kwargs}

    ${session}=    Validate SSO Session For Profile    ${profile}

    ${banner}=    Evaluate    "\\n========== S3 Client Configuration ==========\\n" + "Mode:".ljust(10) + "AWS SSO" + "\\n" + "Profile:".ljust(10) + $profile + "\\n" + "Region:".ljust(10) + $region + "\\n============================================="
    Log S3 Configuration Banner Once    ${banner}

    ${s3_client}=    Evaluate    $session.client('s3', **$kwargs)
    RETURN    ${s3_client}

Validate SSO Session For Profile
    [Documentation]    Returns a validated boto3.Session for the named SSO
    ...    profile, or fails with an actionable error message.
    ...
    ...    Delegates the actual validation (profile lookup, credential check,
    ...    token refresh) to the Python helper ``create_validated_sso_session``
    ...    in ``libraries/s3/s3_auth_helper.py``. That helper catches botocore
    ...    exceptions by TYPE (more robust than substring matching on error
    ...    messages, which would break if botocore renames exceptions or
    ...    changes wording) and returns a clean status code.
    ...
    ...    This keyword maps each status to the user-facing failure message.
    ...
    ...    Status contract (must stay in sync with the Python helper):
    ...    - ok                  → return the session
    ...    - profile_not_found   → fail with available-profiles list
    ...    - no_credentials      → fail suggesting aws sso login
    ...    - token_expired       → fail with refresh instructions
    ...    - cache_readonly      → fail explaining the read-only mount + how to refresh on host
    ...    - other_error / *     → fail with the raw error text
    [Arguments]    ${profile}

    ${status}    ${session}    ${err}=    Create Validated SSO Session    ${profile}

    IF    '${status}' == 'ok'
        RETURN    ${session}
    ELSE IF    '${status}' == 'profile_not_found'
        ${available}=    Get Available AWS Profiles
        Fail
        ...    Profile '${profile}' not found in ~/.aws/config. Check the AWS_PROFILE value in your .env for typos.${\n}Available profiles: ${available}${\n}If you haven't run AWS SSO setup yet, run on the host: aws configure sso
    ELSE IF    '${status}' == 'no_credentials'
        Fail
        ...    SSO session for profile '${profile}' has no credentials. The SSO token has likely expired (tokens last 8–12 hours).${\n}Fix: run on the host: aws sso login --profile ${profile}
    ELSE IF    '${status}' == 'token_expired'
        Fail
        ...    SSO token for profile '${profile}' has EXPIRED (SSO sessions typically last 8–12 hours).${\n}Fix: run on the host: aws sso login --profile ${profile}${\n}After login, no container restart is needed — the bind mount picks up the refreshed tokens automatically.
    ELSE IF    '${status}' == 'cache_readonly'
        Fail
        ...    SSO token for profile '${profile}' is in the refresh window, but the container's ~/.aws/sso/cache directory is mounted READ-ONLY — so boto3 can't save the refreshed token.${\n}Fix: run on your HOST (Mac/Linux, NOT inside the container): aws sso login --profile ${profile}${\n}This refreshes the token to your host's ~/.aws/sso/cache/, which the container reads via the bind mount. No container restart needed — re-run your test right after.
    ELSE
        # Catch-all for status='other_error' or any unexpected value
        Fail    SSO validation failed for profile '${profile}': ${err}
    END

Build S3 Client With Default Chain
    [Documentation]    Builds a boto3 S3 client relying on boto3's default
    ...    credential chain (env vars / ~/.aws/credentials / EC2 metadata).
    ...    Used when no explicit keys and no AWS_PROFILE were provided.
    ...    The endpoint may still be set (for custom S3-compatible services).
    [Arguments]    ${region}    ${kwargs}

    Log    No explicit keys or profile — boto3 will use default credential chain (env vars / ~/.aws / EC2 metadata)

    ${banner}=    Evaluate    "\\n========== S3 Client Configuration ==========\\n" + "Mode:".ljust(10) + "Default Credential Chain" + "\\n" + "Region:".ljust(10) + $region + "\\n============================================="
    Log S3 Configuration Banner Once    ${banner}

    ${s3_client}=    Evaluate    __import__('boto3').client('s3', **$kwargs)
    RETURN    ${s3_client}

Log S3 Configuration Banner Once
    [Documentation]    Logs the S3 Client Configuration banner.
    ...
    ...    Behavior:
    ...    - First call in a test session  -> banner printed to console AND HTML log
    ...    - All subsequent calls          -> banner only in HTML log (silent console)
    ...
    ...    Why: Get S3 Client runs on every S3 keyword call (often dozens of
    ...    times per suite). Without this gating the console fills up with
    ...    duplicate banners. The first-time print keeps the auth mode visible
    ...    at the top of the run; the HTML log still has the per-call record
    ...    if you ever need to verify which mode was used for a specific step.
    ...
    ...    State: tracked via the env var _S3_BANNER_LOGGED='1' in os.environ.
    ...    Lives for the lifetime of the test process. Re-running the suite
    ...    shows the banner again (fresh process, fresh env).
    [Arguments]    ${banner}

    # Always record in the HTML log so per-call evidence is preserved
    Log    ${banner}

    # Only echo to console on first call this session
    ${already_logged}=    Evaluate    __import__('os').environ.get('_S3_BANNER_LOGGED') == '1'
    IF    not ${already_logged}
        Log    ${banner}    console=yes
        Evaluate    __import__('os').environ.update({'_S3_BANNER_LOGGED': '1'})
    END

Get Available AWS Profiles
    [Documentation]    Returns a comma-separated string of profile names defined
    ...    in ~/.aws/config (resolved to /root/.aws/config inside the tools
    ...    container via the AWS credentials bind mount). Used to produce
    ...    helpful error messages when AWS_PROFILE doesn't resolve.
    ...
    ...    Returns a descriptive status string (rather than failing) when:
    ...    - ~/.aws/config doesn't exist
    ...    - The file exists but contains no profile sections
    ...
    ...    No secret values are read or exposed — only the bracketed section
    ...    names like [profile foo] and [default] are extracted.

    ${config_path}=    Evaluate    __import__('os').path.expanduser('~/.aws/config')
    ${exists}=    Evaluate    __import__('os').path.isfile($config_path)
    IF    not ${exists}
        RETURN    (~/.aws/config not found — run 'aws configure sso' on the host)
    END

    ${content}=    Get File    ${config_path}
    @{lines}=    Split To Lines    ${content}
    @{profiles}=    Create List
    FOR    ${line}    IN    @{lines}
        ${stripped}=    Strip String    ${line}
        ${is_named_profile}=    Evaluate    $stripped.startswith('[profile ') and $stripped.endswith(']')
        IF    ${is_named_profile}
            ${name}=    Evaluate    $stripped[9:-1]
            Append To List    ${profiles}    ${name}
        ELSE IF    '${stripped}' == '[default]'
            Append To List    ${profiles}    default
        END
    END
    ${count}=    Get Length    ${profiles}
    IF    ${count} == 0
        RETURN    (no profiles defined in ~/.aws/config)
    END
    ${result}=    Evaluate    ', '.join($profiles)
    RETURN    ${result}

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

        Log    📥 Downloaded ${object_key} from ${bucket_name} to ${local_path}    console=yes

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
    [Documentation]    Validates that MinIO/S3 connection is working properly.
    ...    Returns ${TRUE} on success. On failure, propagates the actual error
    ...    from Get S3 Client (rather than swallowing it and returning ${FALSE})
    ...    so callers see actionable messages like "AWS_PROFILE is set but EMPTY"
    ...    instead of a generic "connection failed" wrapper.
    ...    📋 ASSERTIONS:
    ...    • S3 client can be created successfully
    ...    • MinIO server is accessible at configured endpoint
    ...    • Authentication credentials are valid
    ...    • Basic connectivity test passes

    Log    🔍 Validating MinIO/S3 connection...

    TRY
        ${s3_client}=    Get MinIO S3 Client

        # Try to list buckets as a connectivity test
        ${result}=    Evaluate    $s3_client.list_buckets()
        Log    ✅ MinIO/S3 connection validated successfully    console=yes
        Log    📊 Available buckets: ${result}

        RETURN    ${TRUE}
    EXCEPT    AS    ${error}
        # Surface the original error (which already has actionable guidance from
        # Get S3 Client's trap messages) instead of swallowing it. Callers that
        # use this with `Should Be True ${ok}` will see the helpful message
        # directly in the console/report rather than a hardcoded generic msg.
        Log    ❌ MinIO/S3 connection failed: ${error}    level=ERROR
        Fail    ${error}
    END

Create Bucket
    [Documentation]    Creates an S3 / MinIO bucket. Idempotent by default —
    ...    if the bucket already exists (and you own it), the keyword logs
    ...    and returns ``${TRUE}`` without raising.
    ...
    ...    *Arguments:*
    ...    - ``bucket_name``: Name of the bucket to create. Must be S3-compliant
    ...    (lowercase, 3–63 chars, no underscores, no consecutive dots, etc.).
    ...    - ``region``: Optional AWS region. Required for real AWS S3 outside
    ...    ``us-east-1``. Ignored by MinIO. Default: ``${EMPTY}`` (no
    ...    ``CreateBucketConfiguration`` is sent — fine for MinIO and
    ...    us-east-1 AWS).
    ...    - ``fail_if_exists``: If ``${TRUE}``, fail the test when the bucket
    ...    already exists. Default ``${FALSE}`` (idempotent).
    ...
    ...    *Returns:*
    ...    - ``${TRUE}`` on success (created or already existed)
    ...
    ...    *Examples:*
    ...    | # Idempotent create (recommended for tests) |
    ...    | Create Bucket | tutorial-bucket |
    ...    |
    ...    | # Strict create — fail if it already exists |
    ...    | Create Bucket | exclusive-bucket | fail_if_exists=${TRUE} |
    ...    |
    ...    | # AWS S3 in eu-west-1 |
    ...    | Create Bucket | my-eu-bucket | region=eu-west-1 |
    [Arguments]    ${bucket_name}    ${region}=${EMPTY}    ${fail_if_exists}=${FALSE}

    Log    Creating bucket '${bucket_name}'...    console=yes
    ${s3_client}=    Get S3 Client

    TRY
        IF    '${region}' == '${EMPTY}'
            Evaluate    $s3_client.create_bucket(Bucket='${bucket_name}')
        ELSE
            ${cfg}=    Evaluate    {'LocationConstraint': '${region}'}
            Evaluate    $s3_client.create_bucket(Bucket='${bucket_name}', CreateBucketConfiguration=$cfg)
        END
        Log    ✅ Bucket '${bucket_name}' created    console=yes
        RETURN    ${TRUE}
    EXCEPT    AS    ${error}
        # Both error codes mean "already exists" — BucketAlreadyOwnedByYou (we own it)
        # vs BucketAlreadyExists (someone else owns the global name on AWS).
        ${already_exists}=    Evaluate
        ...    'BucketAlreadyOwnedByYou' in '''${error}''' or 'BucketAlreadyExists' in '''${error}'''
        IF    ${already_exists}
            IF    ${fail_if_exists}
                Fail    Bucket '${bucket_name}' already exists (fail_if_exists=TRUE): ${error}
            END
            Log    ℹ️ Bucket '${bucket_name}' already exists — skipping (idempotent).    console=yes
            RETURN    ${TRUE}
        END
        Fail    Failed to create bucket '${bucket_name}': ${error}
    END

Delete Bucket
    [Documentation]    Deletes an S3 / MinIO bucket. Idempotent by default —
    ...    if the bucket is missing, the keyword logs and returns ``${TRUE}``
    ...    without raising.
    ...
    ...    *Arguments:*
    ...    - ``bucket_name``: Name of the bucket to delete.
    ...    - ``force``: If ``${TRUE}``, empty the bucket first (delete every
    ...    object) and then delete the bucket. Default ``${FALSE}`` — the
    ...    keyword fails if the bucket is non-empty (S3 default behavior).
    ...    - ``fail_if_missing``: If ``${TRUE}``, fail the test when the
    ...    bucket does not exist. Default ``${FALSE}`` (idempotent).
    ...
    ...    *Returns:*
    ...    - ``${TRUE}`` on success (deleted or already missing)
    ...
    ...    *Examples:*
    ...    | # Idempotent delete — fails if non-empty |
    ...    | Delete Bucket | tutorial-bucket |
    ...    |
    ...    | # Force-delete — empties the bucket first |
    ...    | Delete Bucket | tutorial-bucket | force=${TRUE} |
    ...    |
    ...    | # Strict delete — fail if missing |
    ...    | Delete Bucket | must-exist-bucket | fail_if_missing=${TRUE} |
    [Arguments]    ${bucket_name}    ${force}=${FALSE}    ${fail_if_missing}=${FALSE}

    Log    Deleting bucket '${bucket_name}' (force=${force})...    console=yes
    ${s3_client}=    Get S3 Client

    # If forced, empty the bucket first — Clean Bucket already handles the iteration.
    # We wrap in Run Keyword And Ignore Error so a missing bucket here doesn't
    # mask the more specific NoSuchBucket handling below.
    IF    ${force}
        Run Keyword And Ignore Error    Clean Bucket    ${bucket_name}
    END

    TRY
        Evaluate    $s3_client.delete_bucket(Bucket='${bucket_name}')
        Log    ✅ Bucket '${bucket_name}' deleted    console=yes
        RETURN    ${TRUE}
    EXCEPT    AS    ${error}
        ${missing}=    Evaluate    'NoSuchBucket' in '''${error}''' or 'NotFound' in '''${error}'''
        IF    ${missing}
            IF    ${fail_if_missing}
                Fail    Bucket '${bucket_name}' does not exist (fail_if_missing=TRUE): ${error}
            END
            Log    ℹ️ Bucket '${bucket_name}' does not exist — skipping (idempotent).    console=yes
            RETURN    ${TRUE}
        END
        ${not_empty}=    Evaluate    'BucketNotEmpty' in '''${error}'''
        IF    ${not_empty}
            Fail    Bucket '${bucket_name}' is not empty. Pass force=${TRUE} to delete its contents first.
        END
        Fail    Failed to delete bucket '${bucket_name}': ${error}
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
    [Documentation]    Lists every object key in an S3/MinIO bucket, with
    ...    optional server-side prefix filtering and full pagination.
    ...
    ...    📋 ASSERTIONS:
    ...    • S3 client connection is successful
    ...    • Bucket exists and is accessible
    ...    • ALL pages of results are fetched (no 1000-key truncation)
    ...    • Returns full list of matching object keys
    ...
    ...    *Arguments:*
    ...    - ``bucket_name``: S3/MinIO bucket to list
    ...    - ``prefix``: Optional. If given, only keys starting with this string
    ...      are returned (server-side filter via S3's Prefix= parameter —
    ...      orders of magnitude faster than client-side filtering on large
    ...      buckets). Default: ``${EMPTY}`` (returns everything in the bucket).
    ...
    ...    *Returns:*
    ...    - List of object keys (strings). Empty list if the bucket has no
    ...      objects matching the prefix, or if the call fails.
    ...
    ...    *Performance notes:*
    ...    - Uses boto3's list_objects_v2 paginator internally — correct for
    ...      buckets of ANY size. The underlying S3 API caps each response at
    ...      1000 keys; without pagination, large buckets silently truncate.
    ...    - For very large buckets WITHOUT a prefix, this fetches metadata
    ...      for every key — pass a prefix to scope the query to the folder
    ...      you care about (much faster, much less data transferred).
    ...
    ...    *Examples:*
    ...    | # List everything in the bucket (paginates correctly for >1000 keys) |
    ...    | ${all}= | List Objects In Bucket | my-bucket |
    ...    |
    ...    | # List only objects under a "folder" — fast even on huge buckets |
    ...    | ${tutorials}= | List Objects In Bucket | my-bucket | tutorial/ |
    [Arguments]    ${bucket_name}    ${prefix}=${EMPTY}

    ${s3_client}=    Get MinIO S3 Client

    # Build the scope label up-front so the EXCEPT branch can reference it
    # in error messages even if the TRY body fails early.
    ${scope_label}=    Set Variable    bucket '${bucket_name}'
    IF    '${prefix}' != '${EMPTY}'
        ${scope_label}=    Set Variable    bucket '${bucket_name}' under prefix '${prefix}'
    END

    TRY
        # boto3's paginator transparently handles list_objects_v2's per-page
        # 1000-key cap by following NextContinuationToken automatically.
        # Without this, large buckets would silently truncate at page 1.
        ${paginator}=    Evaluate    $s3_client.get_paginator('list_objects_v2')

        # Build paginate() kwargs — only include Prefix when non-empty so the
        # S3 API call is clean (passing Prefix='' is technically valid but
        # noisy in CloudTrail logs).
        ${paginate_kwargs}=    Create Dictionary    Bucket=${bucket_name}
        IF    '${prefix}' != '${EMPTY}'
            Set To Dictionary    ${paginate_kwargs}    Prefix=${prefix}
        END

        # Heads-up before the (potentially slow) listing starts. For a bucket
        # with 1M objects this can take 60-100 seconds; without a log here
        # the test looks frozen.
        Log    📋 Listing objects in ${scope_label} (may take a while for large buckets)...    console=yes

        # Stream pages lazily — this list comprehension iterates the
        # PageIterator inside Python without materializing all pages at
        # once. Only the final list of keys is retained in memory.
        #
        # Critical for million-object buckets: the previous "list(...)"
        # approach held the metadata for every page in memory simultaneously
        # (~500MB for a 1M-key bucket); this version holds at most one page
        # of metadata at a time (~500KB).
        ${objects}=    Evaluate    [obj['Key'] for page in $paginator.paginate(**$paginate_kwargs) for obj in page.get('Contents', [])]

        ${count}=    Get Length    ${objects}
        Log    📋 Found ${count} object(s) in ${scope_label}    console=yes

        # Cap console output to avoid flooding when buckets have many objects.
        # The full list is always written to the HTML log via the final
        # un-console=yes Log call below.
        ${display_limit}=    Set Variable    ${20}
        ${shown}=    Evaluate    min($count, $display_limit)
        FOR    ${i}    IN RANGE    ${shown}
            Log    ${SPACE}${SPACE}- ${objects[${i}]}    console=yes
        END
        IF    ${count} > ${display_limit}
            ${remaining}=    Evaluate    $count - $display_limit
            Log    ${SPACE}${SPACE}... and ${remaining} more (full list in HTML log)    console=yes
        END
        # Full key list to HTML log only — useful when debugging but not
        # printed to console.
        Log    Full key list: ${objects}

        RETURN    ${objects}
    EXCEPT    AS    ${error}
        Log    ❌ Failed to list objects in ${scope_label}: ${error}
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
        Log    ✅ Object '${object_key}' exists in bucket '${bucket_name}'    console=yes
        RETURN    ${TRUE}
    EXCEPT
        Log    ❌ Object '${object_key}' does not exist in bucket '${bucket_name}'    console=yes
        RETURN    ${FALSE}
    END

Wait Until New S3 Files Appear
    [Documentation]    Polls an S3 bucket until the number of files with the given extension
    ...    INCREASES beyond the ``previous_count``. Use this after pipeline execution
    ...    to wait for the child pipeline to finish uploading NEW files — not just
    ...    detect files from a prior run.
    ...
    ...    *Arguments:*
    ...    - ``bucket_name``: S3 bucket to poll
    ...    - ``extension``: File extension to look for (e.g., ``.txt``)
    ...    - ``previous_count``: Number of files that existed BEFORE pipeline execution.
    ...    The keyword waits until the count exceeds this number.
    ...    - ``timeout``: Max seconds to wait (default: 60)
    ...    - ``interval``: Seconds between polls (default: 5)
    ...
    ...    *Returns:*
    ...    - The new file count after the wait completes
    ...
    ...    *Example:*
    ...    | # Before pipeline execution: snapshot the count |
    ...    | ${_}    ${count_before}=    Find Files In Bucket By Extension    test-bucket    .txt |
    ...    | # ... execute pipeline ... |
    ...    | # After: wait until count increases |
    ...    | ${new_count}=    Wait Until New S3 Files Appear    test-bucket    .txt    ${count_before} |
    [Arguments]    ${bucket_name}    ${extension}    ${previous_count}    ${timeout}=60    ${interval}=5

    ${deadline}=    Evaluate    __import__('time').time() + ${timeout}
    Log
    ...    Waiting for new '${extension}' files in bucket '${bucket_name}' (had ${previous_count} before execution)...
    ...    console=yes

    WHILE    ${TRUE}
        ${now}=    Evaluate    __import__('time').time()
        IF    ${now} >= ${deadline}
            ${files}    ${current}=    Find Files In Bucket By Extension    ${bucket_name}    ${extension}
            Fail
            ...    Timed out after ${timeout}s waiting for new '${extension}' files. Count before=${previous_count}, now=${current}. Files: ${files}
        END
        ${files}    ${current}=    Find Files In Bucket By Extension    ${bucket_name}    ${extension}
        IF    ${current} > ${previous_count}
            Log    New files detected: count went from ${previous_count} to ${current} — proceeding.    console=yes
            RETURN    ${current}
        ELSE
            Log
            ...    Still ${current} '${extension}' file(s) (need > ${previous_count}) — retrying in ${interval}s...
            ...    console=yes
            Sleep    ${interval}s
        END
    END

Download And Get File Content
    [Documentation]    Downloads a single file from an S3 bucket and returns its content.
    ...    Wrapper around ``Download Single File From MinIO`` for convenience.
    ...
    ...    *Arguments:*
    ...    - ``bucket_name``: S3 bucket to download from
    ...    - ``download_dir``: Local directory to save the file
    ...    - ``object_key``: S3 object key to download
    ...
    ...    *Returns:*
    ...    - File content as string (or binary for non-text files)
    ...
    ...    *Example:*
    ...    | ${content}= | Download And Get File Content | test-bucket | ${DOWNLOAD_DIR} | extract/EXTRACT_20260416_000079.txt |
    [Arguments]    ${bucket_name}    ${download_dir}    ${object_key}

    Log    📥 Downloaded file: ${object_key} (from bucket '${bucket_name}')    console=yes
    ${content}=    Download Single File From MinIO
    ...    ${download_dir}    ${bucket_name}    ${object_key}
    RETURN    ${content}

Verify All Files Are Non Empty In Bucket
    [Documentation]    Checks that all S3 objects in the given list have size > 0 bytes.
    ...
    ...    Per-file detail goes to the HTML log; console output is capped at
    ...    the first 20 files so the terminal doesn't flood when this is
    ...    called with a large list (e.g., output of a Find Files... call on
    ...    a big bucket).
    ...
    ...    Internally uses head_object directly rather than the
    ...    ``Get Object Metadata`` keyword. The reasons:
    ...    1. Avoid double-logging — ``Get Object Metadata`` emits a per-file
    ...       digest to console, which would defeat the cap.
    ...    2. Avoid re-creating the S3 client for every iteration; we cache
    ...       it once outside the loop.
    ...
    ...    *Arguments:*
    ...    - ``bucket_name``: S3 bucket containing the files
    ...    - ``file_list``: List of S3 object keys to check
    ...
    ...    *Example:*
    ...    | ${files}    ${_}=    Find Files In Bucket By Extension    test-bucket    .txt |
    ...    | Verify All Files Are Non Empty In Bucket    test-bucket    ${files} |
    [Arguments]    ${bucket_name}    ${file_list}

    ${count}=    Get Length    ${file_list}
    Log    🔍 Verifying ${count} object(s) are non-empty in bucket '${bucket_name}'...    console=yes

    # Get the S3 client ONCE — reuse for every head_object call in the loop.
    # (Calling Get Object Metadata per iteration would re-resolve the client
    # AND emit a per-file metadata-digest console log that defeats the cap.)
    ${s3_client}=    Get MinIO S3 Client

    # Cap per-file console output. Full per-file detail still goes to HTML log.
    ${display_limit}=    Set Variable    ${20}
    ${index}=    Set Variable    ${0}
    FOR    ${file_key}    IN    @{file_list}
        TRY
            ${metadata}=    Evaluate    $s3_client.head_object(Bucket='${bucket_name}', Key='${file_key}')
        EXCEPT    AS    ${error}
            Fail    Failed to check '${file_key}' in bucket '${bucket_name}': ${error}
        END
        ${size}=    Evaluate    $metadata.get('ContentLength', 0)
        # Always to HTML log — preserves the audit trail per file
        Log    File: ${file_key} — Size: ${size} bytes
        # To console only for the first ${display_limit} files
        IF    ${index} < ${display_limit}
            Log    ${SPACE}${SPACE}- ${file_key} (${size} bytes)    console=yes
        END
        Should Be True    ${size} > 0
        ...    msg=File '${file_key}' is empty (0 bytes) in bucket '${bucket_name}'
        ${index}=    Evaluate    $index + 1
    END

    IF    ${count} > ${display_limit}
        ${remaining}=    Evaluate    $count - $display_limit
        Log    ${SPACE}${SPACE}... and ${remaining} more checked (full list in HTML log)    console=yes
    END
    Log    ✅ All ${count} object(s) verified non-empty in bucket '${bucket_name}'    console=yes

Get Current And Previous File Content From Bucket
    [Documentation]    Downloads the two most recent files (by extension) from an S3 bucket
    ...    and returns their content. Use for current-vs-previous-run comparisons.
    ...
    ...    *Arguments:*
    ...    - ``bucket_name``: S3 bucket to search
    ...    - ``download_dir``: Local directory to save downloaded files
    ...    - ``extension``: File extension to filter (e.g., ``.txt``, ``.csv``)
    ...    - ``line_prefix``: Optional — if set, only lines starting with this prefix
    ...    are returned (e.g., ``CD`` to extract only detail records, skipping
    ...    headers/trailers with dynamic values). If empty, full content is returned.
    ...
    ...    *Returns:*
    ...    - ``${current_content}``: Content (or filtered lines) from the latest file
    ...    - ``${previous_content}``: Content (or filtered lines) from the second-latest file
    ...    - ``${current_file}``: S3 key of the latest file
    ...    - ``${previous_file}``: S3 key of the second-latest file
    ...    - ``${file_count}``: Total number of matching files in the bucket
    ...
    ...    *Fails if:*
    ...    - No files found with the given extension
    ...    - Fewer than 2 files found (no previous run to compare against)
    ...
    ...    *Examples:*
    ...    | # Compare full content |
    ...    | ${cur}    ${prev}    ${cur_f}    ${prev_f}    ${cnt}=    Get Current And Previous File Content From Bucket    test-bucket    ${DL_DIR}    .csv |
    ...    |
    ...    | # Compare only CD-prefixed lines (skip PA header / PT trailer) |
    ...    | ${cur}    ${prev}    ${cur_f}    ${prev_f}    ${cnt}=    Get Current And Previous File Content From Bucket    test-bucket    ${DL_DIR}    .txt    line_prefix=CD |
    [Arguments]    ${bucket_name}    ${download_dir}    ${extension}    ${line_prefix}=${EMPTY}

    ${files}    ${file_count}=    Find Files In Bucket By Extension    ${bucket_name}    ${extension}

    IF    ${file_count} == 0
        Fail    No '${extension}' files found in bucket '${bucket_name}'.
    END

    IF    ${file_count} < 2
        Fail
        ...    Only ${file_count} '${extension}' file(s) found in bucket '${bucket_name}'. Comparison requires at least 2 (current + previous). Run the pipeline a second time to generate a previous-run file.
    END

    ${current_file}=    Get From List    ${files}    0
    ${previous_file}=    Get From List    ${files}    1

    Log    Current file (latest): ${current_file}    console=yes
    Log    Previous file: ${previous_file}    console=yes

    ${current_raw}=    Download Single File From MinIO    ${download_dir}    ${bucket_name}    ${current_file}
    ${previous_raw}=    Download Single File From MinIO    ${download_dir}    ${bucket_name}    ${previous_file}

    IF    '${line_prefix}' != '${EMPTY}'
        ${current_content}=    Extract Lines By Prefix    ${current_raw}    ${line_prefix}
        ${previous_content}=    Extract Lines By Prefix    ${previous_raw}    ${line_prefix}
    ELSE
        ${current_content}=    Set Variable    ${current_raw}
        ${previous_content}=    Set Variable    ${previous_raw}
    END

    RETURN    ${current_content}    ${previous_content}    ${current_file}    ${previous_file}    ${file_count}

Find Files In Bucket By Extension
    [Documentation]    Lists all objects in an S3 bucket filtered by file extension and optional path prefixes.
    ...
    ...    Returns a list of matching object keys, sorted descending (latest/highest first).
    ...
    ...    *Arguments:*
    ...    - ``bucket_name``: S3 bucket to search in
    ...    - ``extension``: File extension to filter by (e.g., ``.txt``, ``.csv``, ``.html``)
    ...    - ``path_filters``: Optional list of path substrings to include. Only objects whose key
    ...    contains at least one of these substrings are returned. Default: ``['extract/', 'output/']``.
    ...    Pass an empty list to match ALL paths (no filtering).
    ...
    ...    *Returns:*
    ...    - ``${files}``: List of matching object keys, sorted descending
    ...    - ``${count}``: Number of matching files (integer)
    ...
    ...    *Examples:*
    ...    | ${files}    ${count}=    Find Files In Bucket By Extension    test-bucket    .txt |
    ...    | Should Be True    ${count} > 0    msg=No TXT files found |
    ...    |
    ...    | # Custom path filter |
    ...    | ${files}=    Find Files In Bucket By Extension    test-bucket    .csv    path_filters=['reports/'] |
    ...    |
    ...    | # No path filtering — match all .json files in bucket |
    ...    | ${files}=    Find Files In Bucket By Extension    test-bucket    .json    path_filters=[] |
    [Arguments]    ${bucket_name}    ${extension}    @{path_filters}

    # Default path filters if none provided
    ${filter_count}=    Get Length    ${path_filters}
    IF    ${filter_count} == 0
        @{path_filters}=    Create List    extract/    output/
    END

    # PERFORMANCE: when EXACTLY ONE path_filter is given, push it down to S3
    # as a server-side Prefix= argument so the API returns only matching
    # keys. This is orders of magnitude faster on large buckets (e.g., a
    # bucket with 10K+ keys where you want files under one folder).
    #
    # When MULTIPLE path_filters are given, S3 can't OR across prefixes in
    # one call — we fall back to a bucket-wide list and the original
    # client-side substring matching (correct, just slower). The default
    # path_filters list (['extract/', 'output/']) hits this fallback path.
    ${pf_count}=    Get Length    ${path_filters}
    IF    ${pf_count} == 1
        ${single_prefix}=    Get From List    ${path_filters}    0
        ${all_objects}=    List Objects In Bucket    ${bucket_name}    ${single_prefix}
    ELSE
        ${all_objects}=    List Objects In Bucket    ${bucket_name}
    END
    @{matching}=    Create List

    FOR    ${key}    IN    @{all_objects}
        ${ends_match}=    Evaluate    $key.endswith($extension)
        IF    ${ends_match}
            # If path_filters is empty after explicit pass, include all
            ${pf_count}=    Get Length    ${path_filters}
            IF    ${pf_count} == 0
                Append To List    ${matching}    ${key}
            ELSE
                FOR    ${prefix}    IN    @{path_filters}
                    ${contains}=    Evaluate    $prefix in $key
                    IF    ${contains}
                        Append To List    ${matching}    ${key}
                        BREAK
                    END
                END
            END
        END
    END

    Sort List    ${matching}
    Reverse List    ${matching}
    ${count}=    Get Length    ${matching}
    Log    Found ${count} files with extension '${extension}' in bucket '${bucket_name}': ${matching}    console=yes
    RETURN    ${matching}    ${count}

Find Specific File In Bucket
    [Documentation]    Searches for a specific file in an S3 bucket by listing all files
    ...    matching the given extension and checking if the expected filename is present.
    ...
    ...    Returns two values:
    ...    - ``${match_found}``: Boolean — True if the expected file was found
    ...    - ``${files}``: List of all files matching the extension (for debugging)
    ...
    ...    *Arguments:*
    ...    - ``bucket_name``: S3 bucket to search in
    ...    - ``expected_filename``: The exact object key to look for (e.g., ``output/baseline/EXTRACT_20260410_000001.txt``)
    ...    - ``extension``: File extension to filter by (e.g., ``.txt``, ``.csv``)
    ...    - ``path_filters``: Optional list of path substrings to include. Only objects whose key
    ...    contains at least one of these substrings are scanned. Default: ``['extract/', 'output/']``.
    ...    Pass an empty list to match ALL paths (no filtering).
    ...
    ...    *Examples:*
    ...    | ${found}    ${files}=    Find Specific File In Bucket    test-bucket    output/EXTRACT_20260410_000001.txt    .txt |
    ...    | Should Be True    ${found}    msg=Expected file not found. Found: ${files} |
    ...    |
    ...    | # Custom path filter |
    ...    | ${found}    ${files}=    Find Specific File In Bucket    test-bucket    tutorial/sample.txt    .txt    path_filters=['tutorial/'] |
    [Arguments]    ${bucket_name}    ${expected_filename}    ${extension}    @{path_filters}

    # Default path filters if none provided — keeps backward compatibility with callers
    # that didn't pass path_filters (extract/output were hardcoded historically).
    ${filter_count}=    Get Length    ${path_filters}
    IF    ${filter_count} == 0
        @{path_filters}=    Create List    extract/    output/
    END

    # PERFORMANCE: when EXACTLY ONE path_filter is given, push it down to S3
    # as a server-side Prefix= argument (see Find Files In Bucket By Extension
    # for the same pattern + rationale). Multiple path_filters fall back to
    # bucket-wide listing with client-side OR matching.
    ${pf_count}=    Get Length    ${path_filters}
    IF    ${pf_count} == 1
        ${single_prefix}=    Get From List    ${path_filters}    0
        ${all_objects}=    List Objects In Bucket    ${bucket_name}    ${single_prefix}
    ELSE
        ${all_objects}=    List Objects In Bucket    ${bucket_name}
    END
    @{matching}=    Create List

    FOR    ${key}    IN    @{all_objects}
        ${ends_match}=    Evaluate    $key.endswith($extension)
        IF    ${ends_match}
            FOR    ${prefix}    IN    @{path_filters}
                ${contains}=    Evaluate    $prefix in $key
                IF    ${contains}
                    Append To List    ${matching}    ${key}
                    BREAK
                END
            END
        END
    END

    Sort List    ${matching}
    Reverse List    ${matching}

    ${match_found}=    Evaluate    $expected_filename in $matching
    Log    Looking for: ${expected_filename}    console=yes
    Log    Found ${matching.__len__()} files with extension '${extension}': ${matching}    console=yes

    RETURN    ${match_found}    ${matching}

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
        # Console gets a short, scan-friendly digest. The full dict still appears in the HTML log.
        ${size}=    Evaluate    $metadata.get('ContentLength', 0)
        ${etag}=    Evaluate    $metadata.get('ETag', '')
        ${ctype}=    Evaluate    $metadata.get('ContentType', '')
        Log    📊 ${object_key} — size=${size} bytes, type=${ctype}, etag=${etag}    console=yes
        Log    Full metadata: ${metadata}
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

    Log    ✅ Downloaded ${downloaded_files.__len__()} files from bucket '${bucket_name}'    console=yes
    Log    📋 Downloaded files: ${downloaded_files}    console=yes

    RETURN    ${downloaded_files}

Download Files By Pattern
    [Documentation]    Downloads files matching a SUBSTRING pattern from an S3/MinIO bucket.
    ...
    ...    *Arguments:*
    ...    - ``download_location``: Local directory to save downloaded files
    ...    - ``bucket_name``: S3/MinIO bucket to scan
    ...    - ``pattern``: Substring to match anywhere in the object key
    ...      (uses ``Should Contain`` semantics — NOT a prefix or regex)
    ...    - ``preserve_files``: If ${TRUE}, keep files after reading. Default ${TRUE}.
    ...    - ``prefix``: Optional. If given, only objects under this prefix are
    ...      considered (server-side filter via S3's Prefix= argument). Orders
    ...      of magnitude faster on large buckets than scanning the whole bucket.
    ...      Default: ${EMPTY} (scans the entire bucket).
    ...
    ...    *Returns:*
    ...    - List of downloaded object keys
    ...
    ...    *Performance:*
    ...    Without a ``prefix``, this fetches every key in the bucket (paginated)
    ...    and filters in Python. For buckets with millions of objects, ALWAYS
    ...    pass a ``prefix`` to scope the listing — otherwise the call will be
    ...    slow AND will retrieve metadata for every object in the bucket.
    ...
    ...    *Examples:*
    ...    | # Old usage — still works, slow on large buckets |
    ...    | Download Files By Pattern | /downloads | my-bucket | tutorial/data/ |
    ...    |
    ...    | # Optimized — server narrows to tutorial/data/, client matches .csv |
    ...    | Download Files By Pattern | /downloads | my-bucket | .csv | prefix=tutorial/data/ |
    ...
    ...    📋 ASSERTIONS:
    ...    • S3 client connection is successful
    ...    • Bucket exists and is accessible
    ...    • Pattern matching works correctly
    ...    • Matching files are downloaded successfully
    ...    • Local directory structure is created properly
    [Arguments]    ${download_location}    ${bucket_name}    ${pattern}    ${preserve_files}=${TRUE}    ${prefix}=${EMPTY}

    Log    📥 Downloading files matching pattern '${pattern}' from bucket: ${bucket_name}

    # PERFORMANCE: when prefix is given, push it down to S3 as server-side
    # filter (Prefix=) so we don't pull the entire bucket. The client-side
    # pattern match below still runs on the (much smaller) returned set,
    # preserving the substring semantics callers expect from this keyword.
    IF    '${prefix}' != '${EMPTY}'
        ${all_objects}=    List Objects In Bucket    ${bucket_name}    ${prefix}
    ELSE
        ${all_objects}=    List Objects In Bucket    ${bucket_name}
    END

    # Filter objects by substring pattern (Should Contain semantics — matches
    # the pattern anywhere in the key, not just as a prefix).
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

    Log    ✅ Downloaded ${downloaded_files.__len__()} files matching pattern '${pattern}'    console=yes
    Log    📋 Downloaded files: ${downloaded_files}    console=yes

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
    [Documentation]    Deletes all objects in a bucket whose key starts with the given
    ...    folder/prefix. Use this to clean a specific folder without affecting other files.
    ...
    ...    Note: S3 has no real folders — keys are flat strings. A "folder" here means any
    ...    object key that starts with ``prefix`` (e.g., ``tutorial/`` matches ``tutorial/sample.txt``,
    ...    ``tutorial/data/sample.csv``, etc.).
    ...
    ...    *Arguments:*
    ...    - ``bucket_name``: Name of the bucket
    ...    - ``prefix``: Folder/path prefix to match (e.g., 'extract/', 'output/baseline/')
    ...
    ...    *Example:*
    ...    | Clean Bucket By Prefix | test-bucket | extract/ |
    [Arguments]    ${bucket_name}    ${prefix}

    Log    Cleaning objects with prefix '${prefix}' from bucket '${bucket_name}'...    console=yes
    ${s3_client}=    Get S3 Client

    # Server-side prefix filter: ask S3 to return only matching keys instead
    # of fetching the whole bucket and filtering client-side. This is
    # critical for correctness on large buckets — without it, List Objects
    # In Bucket previously truncated at 1000 keys and we could silently
    # leave files behind whose keys sorted after page 1.
    ${matching_objects}=    List Objects In Bucket    ${bucket_name}    ${prefix}
    ${deleted}=    Set Variable    ${0}

    FOR    ${key}    IN    @{matching_objects}
        Evaluate    $s3_client.delete_object(Bucket='${bucket_name}', Key=$key)
        Log    Deleted: ${key}    console=yes
        ${deleted}=    Evaluate    ${deleted} + 1
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
