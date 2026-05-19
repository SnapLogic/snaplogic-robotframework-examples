*** Comments ***
# ──────────────────────────────────────────────────────────────────────────────
# S3 / MinIO — Operations Tutorial
#
# Demonstrates ONE example of each common S3 operation using
# `resources/minio/minio.resource`.
#
# All examples operate on a single shared bucket (test-bucket) under a
# tutorial-specific prefix so we don't conflict with other tests.
# Run with:    make robot-run-tests-no-gp TAGS="connect_to_s3_sample"
#
# Test cases run sequentially: Account → Connect → Bucket → Upload →
# Existence → Metadata → List → Search → Download → Validate → Cleanup.
#
# Each test case demonstrates ONE keyword. Keep it that way when adding more —
# the goal is a one-keyword-per-row reference customers can copy from.
#
# Notes on environment:
#    • Works with both MinIO (Docker) and real AWS S3 — the framework auto-
#    detects via S3_ENDPOINT in env_files/mock_service_accounts/.env.s3.
#    • All tutorial files live under the prefix `tutorial/` so cleanup is easy
#    and we don't collide with config/, extract/, output/ used elsewhere.
# ──────────────────────────────────────────────────────────────────────────────


*** Settings ***
Documentation       Tutorial — common S3/MinIO operations using minio.resource

Resource            snaplogic_common_robot/snaplogic_apis_keywords/snaplogic_keywords.resource
Resource            ../../../../../resources/common/general.resource
Resource            ../../../../../resources/minio/minio.resource

Suite Setup         Initialize Tutorial
# Suite Teardown    Cleanup Tutorial


*** Variables ***
${BUCKET_NAME}              test-bucket-swapna
${PREFIX}                   tutorial/

# Local files used by upload tests — checked into the repo under sample_files/
# next to this .robot file. Customers can edit them directly without running anything.
${LOCAL_SAMPLE_FILE}        ${CURDIR}/sample_files/sample.txt
${LOCAL_SAMPLE_FILE_2}      ${CURDIR}/sample_files/sample.csv
${LOCAL_SAMPLE_FILE_3}      ${CURDIR}/sample_files/sample.json
${LOCAL_SAMPLE_FILE_4}      ${CURDIR}/sample_files/sample_2.csv
${LOCAL_SAMPLE_FILE_5}      ${CURDIR}/sample_files/sample_2.json

# Object keys (path inside the bucket) used by all tests
${OBJECT_KEY_1}             ${PREFIX}sample.txt
${OBJECT_KEY_2}             ${PREFIX}data/sample.csv
${OBJECT_KEY_3}             ${PREFIX}data/sample.json
${OBJECT_KEY_4}             ${PREFIX}data/sample_2.csv
${OBJECT_KEY_5}             ${PREFIX}data/sample_2.json

# Local download directory — used by all download tests.
# ${CURDIR} = the folder this .robot file lives in. From there, four "../" jumps
# back to test/suite, then into test_data/actual_expected_data/actual_output:
#    <repo>/test/suite/test_data/actual_expected_data/actual_output/
# This folder is bind-mounted into the tools container, so downloaded files appear
# on your Mac at the path above immediately.
# An object with S3 key 'tutorial/sample.txt' lands at .../actual_output/tutorial/sample.txt.
${DOWNLOAD_DIR}             ${CURDIR}/../../../../test_data/actual_expected_data/actual_output


*** Test Cases ***
# ═══════════════════════════════════════════════════════════════
# 1. ACCOUNT
# ═══════════════════════════════════════════════════════════════

Create Account
    [Documentation]    Creates the S3/MinIO account in the project space.
    [Tags]    connect_to_s3_sample
    [Template]    Create Account From Template
    ${ACCOUNT_LOCATION_PATH}    ${S3_ACCOUNT_PAYLOAD_FILE_NAME}    ${S3_ACCOUNT_NAME}
    ${ACCOUNT_LOCATION_PATH}    ${S3_IAM_ACCOUNT_PAYLOAD_FILE_NAME}    ${S3_IAM_ACCOUNT_NAME}

# ═══════════════════════════════════════════════════════════════
# 2. CONNECTION
# ═══════════════════════════════════════════════════════════════

CONNECT — Validate MinIO Connection
    [Documentation]    Confirms boto3 can reach the configured S3 endpoint and authenticate.
    ...    Use this as a sanity check at the start of any S3-touching test.
    [Tags]    connect_to_s3_sample    verify_sso_connect

    ${ok}=    Validate MinIO Connection
    Should Be True    ${ok}    msg=MinIO connection failed — check S3_ENDPOINT, S3_ACCESS_KEY, S3_SECRET_KEY in .env.s3

# ═══════════════════════════════════════════════════════════════
# 3. BUCKET-LEVEL CHECKS
# ═══════════════════════════════════════════════════════════════

BUCKET — Create Bucket (idempotent)
    [Documentation]    Creates a bucket if it doesn't exist. Idempotent — running
    ...    a second time logs "already exists" and returns TRUE without failing.
    ...    Use this in Suite Setup for any bucket your test owns.
    [Tags]    connect_to_s3_sample

    Create Bucket    ${BUCKET_NAME}

    # Verify it landed
    ${exists}=    Check Bucket Exists    ${BUCKET_NAME}
    Should Be True    ${exists}    msg=Create Bucket should have produced '${BUCKET_NAME}'

    # Call it again to prove idempotency — should NOT fail
    Create Bucket    ${BUCKET_NAME}

BUCKET — Check Bucket Exists
    [Documentation]    Returns TRUE/FALSE for whether a bucket exists.
    ...    Does NOT raise — safe to call on missing buckets.
    [Tags]    connect_to_s3_sample

    ${exists}=    Check Bucket Exists    ${BUCKET_NAME}
    Should Be True    ${exists}    msg=Expected bucket '${BUCKET_NAME}' to exist (created by Suite Setup)

    ${missing}=    Check Bucket Exists    nonexistent-bucket-xyz-999
    Should Not Be True    ${missing}    msg=Expected missing bucket to return FALSE

# ═══════════════════════════════════════════════════════════════
# 4. UPLOAD
# ═══════════════════════════════════════════════════════════════

UPLOAD — Upload File To MinIO
    [Documentation]    Uploads a local file to s3://<bucket>/<object_key>.
    ...    Read as: "Upload <local file> to <bucket> at <key>".
    [Tags]    connect_to_s3_sample

    Upload File To MinIO    ${LOCAL_SAMPLE_FILE}    ${BUCKET_NAME}    ${OBJECT_KEY_1}

# ═══════════════════════════════════════════════════════════════
# 5. EXISTENCE CHECKS
# ═══════════════════════════════════════════════════════════════

EXISTENCE — Check Object Exists
    [Documentation]    Returns TRUE/FALSE for whether an object exists at a given key.
    ...    Use after upload to confirm the file landed.
    [Tags]    connect_to_s3_sample

    ${exists}=    Check Object Exists    ${BUCKET_NAME}    ${OBJECT_KEY_1}
    Should Be True    ${exists}    msg=Expected uploaded object '${OBJECT_KEY_1}' to exist

    ${missing}=    Check Object Exists    ${BUCKET_NAME}    ${PREFIX}does_not_exist.txt
    Should Not Be True    ${missing}    msg=Expected missing object to return FALSE

# ═══════════════════════════════════════════════════════════════
# 6. METADATA
# ═══════════════════════════════════════════════════════════════

METADATA — Get Object Metadata
    [Documentation]    Returns the boto3 head_object dict — includes ContentLength,
    ...    ETag, LastModified, ContentType, etc.
    [Tags]    connect_to_s3_sample

    ${metadata}=    Get Object Metadata    ${BUCKET_NAME}    ${OBJECT_KEY_1}

    ${size}=    Evaluate    $metadata.get('ContentLength', 0)
    Should Be True    ${size} > 0    msg=Uploaded object should have non-zero size, got ${size}

# ═══════════════════════════════════════════════════════════════
# 7. LIST OBJECTS
# ═══════════════════════════════════════════════════════════════

LIST — List Objects In Bucket
    [Documentation]    Returns a list of every object key in the bucket.
    ...    Note: lists the WHOLE bucket — not just our tutorial prefix.
    [Tags]    connect_to_s3_sample

    @{all_keys}=    List Objects In Bucket    ${BUCKET_NAME}

    Should Contain    ${all_keys}    ${OBJECT_KEY_1}
    ...    msg=List Objects In Bucket should include our uploaded file '${OBJECT_KEY_1}'

# ═══════════════════════════════════════════════════════════════
# 8. SEARCH BY EXTENSION
# ═══════════════════════════════════════════════════════════════

SEARCH — Find Files In Bucket By Extension
    [Documentation]    Returns all object keys with a given extension, sorted descending.
    ...    Useful for "give me the latest CSV in this bucket" patterns.
    ...    NOTE: default path_filters=[extract/, output/] — pass our prefix explicitly.
    [Tags]    connect_to_s3_sample

    ${files}    ${count}=    Find Files In Bucket By Extension
    ...    ${BUCKET_NAME}    .txt    ${PREFIX}

    Should Be True    ${count} >= 1
    ...    msg=Expected at least one .txt file under '${PREFIX}', got ${count}: ${files}
    Should Contain    ${files}    ${OBJECT_KEY_1}

# ═══════════════════════════════════════════════════════════════
# 9. SEARCH FOR A SPECIFIC FILE
# ═══════════════════════════════════════════════════════════════

SEARCH — Find Specific File In Bucket
    [Documentation]    Looks for a specific object key among files matching an extension.
    ...    Returns (found_bool, list_of_matching_files) — useful for assertion + debug context.
    ...    NOTE: default path_filters=[extract/, output/] — pass our prefix explicitly.
    [Tags]    connect_to_s3_sample

    ${found}    ${candidates}=    Find Specific File In Bucket
    ...    ${BUCKET_NAME}    ${OBJECT_KEY_1}    .txt    ${PREFIX}

    Should Be True    ${found}
    ...    msg=Expected to find '${OBJECT_KEY_1}'. Candidates were: ${candidates}

# ═══════════════════════════════════════════════════════════════
# 10. DOWNLOAD A SINGLE FILE
# ═══════════════════════════════════════════════════════════════

DOWNLOAD — Download Single File From MinIO
    [Documentation]    Downloads one object from a bucket to a local directory.
    ...    The local path becomes ``<download_location>/<object_key>``.
    [Tags]    connect_to_s3_sample

    Download Single File From MinIO    ${DOWNLOAD_DIR}    ${BUCKET_NAME}    ${OBJECT_KEY_1}

    File Should Exist    ${DOWNLOAD_DIR}/${OBJECT_KEY_1}
    ${size}=    Get File Size    ${DOWNLOAD_DIR}/${OBJECT_KEY_1}
    Should Be True    ${size} > 0    msg=Downloaded file should be non-empty

# ═══════════════════════════════════════════════════════════════
# 11. DOWNLOAD AND READ CONTENT IN ONE CALL
# ═══════════════════════════════════════════════════════════════

DOWNLOAD — Download And Get File Content
    [Documentation]    Same as Download Single File From MinIO but also returns
    ...    the file content as a string — convenient for assertions.
    [Tags]    connect_to_s3_sample

    ${content}=    Download And Get File Content
    ...    ${BUCKET_NAME}    ${DOWNLOAD_DIR}    ${OBJECT_KEY_1}

    Should Contain    ${content}    s3 tutorial sample
    ...    msg=Downloaded content should contain the marker string we wrote in setup

# ═══════════════════════════════════════════════════════════════
# 12. UPLOAD MORE FILES (setup for batch download tests below)
# ═══════════════════════════════════════════════════════════════

UPLOAD — Upload Four More Files (for batch tests)
    [Documentation]    Uploads four additional files (2 CSVs + 2 JSONs under tutorial/data/)
    ...    so the next tests can demonstrate pattern-based and bulk download keywords.
    ...    Multiple Upload calls here are intentional setup — each test below still
    ...    demonstrates ONE keyword.
    [Tags]    connect_to_s3_sample

    Upload File To MinIO    ${LOCAL_SAMPLE_FILE_2}    ${BUCKET_NAME}    ${OBJECT_KEY_2}
    Upload File To MinIO    ${LOCAL_SAMPLE_FILE_3}    ${BUCKET_NAME}    ${OBJECT_KEY_3}
    Upload File To MinIO    ${LOCAL_SAMPLE_FILE_4}    ${BUCKET_NAME}    ${OBJECT_KEY_4}
    Upload File To MinIO    ${LOCAL_SAMPLE_FILE_5}    ${BUCKET_NAME}    ${OBJECT_KEY_5}

# ═══════════════════════════════════════════════════════════════
# 13. DOWNLOAD BY PATTERN
# ═══════════════════════════════════════════════════════════════

DOWNLOAD — Download Files By Pattern
    [Documentation]    Downloads every object whose key contains the given substring.
    ...    Pattern matches against the full object key, not glob-style wildcards.
    [Tags]    connect_to_s3_sample

    @{downloaded}=    Download Files By Pattern
    ...    ${DOWNLOAD_DIR}    ${BUCKET_NAME}    ${PREFIX}data/

    ${count}=    Get Length    ${downloaded}
    Should Be Equal As Integers    ${count}    4
    ...    msg=Expected 4 files under 'tutorial/data/', got ${count}: ${downloaded}

# ═══════════════════════════════════════════════════════════════
# 14. DOWNLOAD ALL FILES IN BUCKET
# ═══════════════════════════════════════════════════════════════

DOWNLOAD — Download All Files From Bucket
    [Documentation]    Downloads EVERY object in the bucket to a local directory.
    ...    NOTE: this includes files written by other tests if they exist —
    ...    use Clean Bucket / Clean Bucket By Prefix first if you need isolation.
    [Tags]    connect_to_s3_sample

    @{downloaded}=    Download All Files From Bucket    ${DOWNLOAD_DIR}    ${BUCKET_NAME}

    ${count}=    Get Length    ${downloaded}
    Should Be True    ${count} >= 5
    ...    msg=Expected at least 5 files (the 5 we uploaded), got ${count}

# ═══════════════════════════════════════════════════════════════
# 15. VERIFY ALL FILES NON-EMPTY
# ═══════════════════════════════════════════════════════════════

VALIDATE — Verify All Files Are Non Empty In Bucket
    [Documentation]    Iterates a list of object keys and asserts each has size > 0.
    ...    Pair with Find Files In Bucket By Extension to validate a result set.
    [Tags]    connect_to_s3_sample

    @{tutorial_keys}=    Create List
    ...    ${OBJECT_KEY_1}    ${OBJECT_KEY_2}    ${OBJECT_KEY_3}    ${OBJECT_KEY_4}    ${OBJECT_KEY_5}

    Verify All Files Are Non Empty In Bucket    ${BUCKET_NAME}    ${tutorial_keys}

# ═══════════════════════════════════════════════════════════════
# 16. VALIDATE A DOWNLOADED FILE
# ═══════════════════════════════════════════════════════════════

VALIDATE — Validate Downloaded File Template
    [Documentation]    Comprehensive local-file check — exists, meets min size,
    ...    has expected extension, content is readable.
    [Tags]    connect_to_s3_sample

    Validate Downloaded File Template
    ...    ${DOWNLOAD_DIR}/${OBJECT_KEY_1}
    ...    min_size_bytes=10
    ...    expected_extension=.txt

# ═══════════════════════════════════════════════════════════════
# 17. CLEAN UP TUTORIAL FILES (Suite Teardown also runs this)
# ═══════════════════════════════════════════════════════════════

CLEAN — Clean Bucket By Prefix
    [Documentation]    Deletes every object whose key starts with the given prefix.
    ...    Useful when many tests share a bucket but each owns a folder.
    [Tags]    connect_to_s3_sample2

    Clean Bucket By Prefix    ${BUCKET_NAME}    ${PREFIX}

    # Confirm our 3 tutorial files are gone
    ${still_exists}=    Check Object Exists    ${BUCKET_NAME}    ${OBJECT_KEY_1}
    Should Not Be True    ${still_exists}
    ...    msg=Tutorial file ${OBJECT_KEY_1} should be gone after Clean Bucket By Prefix

# ═══════════════════════════════════════════════════════════════
# 18. DELETE BUCKET (idempotent + force)
# ═══════════════════════════════════════════════════════════════

CLEAN — Delete Bucket (idempotent)
    [Documentation]    Deletes the tutorial bucket.
    ...    • First call: empties (force=TRUE) and deletes the bucket.
    ...    • Second call: bucket is already gone — idempotent skip, no failure.
    ...
    ...    The next run's Suite Setup will recreate the bucket via Create Bucket.
    [Tags]    connect_to_s3_sample2

    # First delete — bucket exists, should succeed.
    # force=TRUE empties it first (in case test 18's prefix-clean missed anything).
    Delete Bucket    ${BUCKET_NAME}    force=${TRUE}

    # Confirm it's gone
    ${exists}=    Check Bucket Exists    ${BUCKET_NAME}
    Should Not Be True    ${exists}
    ...    msg=Bucket '${BUCKET_NAME}' should be deleted

    # Second delete — bucket is already gone; idempotent skip should NOT fail
    Delete Bucket    ${BUCKET_NAME}

# ═══════════════════════════════════════════════════════════════
# 20. END TO END — Full S3 Workflow
# ═══════════════════════════════════════════════════════════════

END TO END — Full S3 Workflow
    [Documentation]    Combined flow exercising every keyword demonstrated above —
    ...    connect, create bucket, upload, inspect, search, download, validate, clean.
    [Tags]    connect_to_s3_sample_end_to_end

    Log    \n<===================▶CONNECT ==================    console=yes
    Validate MinIO Connection

    Log    \n<===================▶BUCKET CREATION AND CHECK ==================    console=yes
    Create Bucket    ${BUCKET_NAME}
    Check Bucket Exists    ${BUCKET_NAME}

    Log    \n<===================▶UPLOAD ==================    console=yes
    Upload File To MinIO    ${LOCAL_SAMPLE_FILE}    ${BUCKET_NAME}    ${OBJECT_KEY_1}
    Upload File To MinIO    ${LOCAL_SAMPLE_FILE_2}    ${BUCKET_NAME}    ${OBJECT_KEY_2}
    Upload File To MinIO    ${LOCAL_SAMPLE_FILE_3}    ${BUCKET_NAME}    ${OBJECT_KEY_3}
    Upload File To MinIO    ${LOCAL_SAMPLE_FILE_4}    ${BUCKET_NAME}    ${OBJECT_KEY_4}
    Upload File To MinIO    ${LOCAL_SAMPLE_FILE_5}    ${BUCKET_NAME}    ${OBJECT_KEY_5}

    Log    \n<===================▶CHECK OBJECT EXISTS ==================\n    console=yes
    Check Object Exists    ${BUCKET_NAME}    ${OBJECT_KEY_1}

    Log    \n<===================▶GET OBJECT METADATA ==================\n    console=yes
    Get Object Metadata    ${BUCKET_NAME}    ${OBJECT_KEY_1}

    Log    \n<===================▶LIST OBJECTS IN BUCKET ==================\n    console=yes
    List Objects In Bucket    ${BUCKET_NAME}

    Log    \n<===================▶FIND FILES BY EXTENSION ════════\n    console=yes
    Find Files In Bucket By Extension    ${BUCKET_NAME}    .txt    ${PREFIX}

    Log    \n<===================▶FIND SPECIFIC FILE ==================\n    console=yes
    Find Specific File In Bucket    ${BUCKET_NAME}    ${OBJECT_KEY_1}    .txt    ${PREFIX}

    Log    \n<===================▶DOWNLOAD SINGLE FILE ==================\n    console=yes
    Download Single File From MinIO    ${DOWNLOAD_DIR}    ${BUCKET_NAME}    ${OBJECT_KEY_1}

    Log    \n<===================▶DOWNLOAD SINGLE FILE AND GET CONTENT ==================\n    console=yes
    Download And Get File Content    ${BUCKET_NAME}    ${DOWNLOAD_DIR}    ${OBJECT_KEY_1}

    Log    \n<===================▶DOWNLOAD BY PATTERN ==================\n    console=yes
    Download Files By Pattern    ${DOWNLOAD_DIR}    ${BUCKET_NAME}    ${PREFIX}data/

    Log    \n<===================▶DOWNLOAD ALL FILES IN BUCKET ==================\n    console=yes
    Download All Files From Bucket    ${DOWNLOAD_DIR}    ${BUCKET_NAME}

    Log    \n<===================▶VALIDATE ALL FILES ARE NON EMPTY IN BUCKET ==================\n    console=yes
    @{all_keys}=    Create List
    ...    ${OBJECT_KEY_1}    ${OBJECT_KEY_2}    ${OBJECT_KEY_3}    ${OBJECT_KEY_4}    ${OBJECT_KEY_5}
    Verify All Files Are Non Empty In Bucket    ${BUCKET_NAME}    ${all_keys}

    Log    \n<===================▶VALIDATE DOWNLOADED FILE ==================\n    console=yes
    Validate Downloaded File Template
    ...    ${DOWNLOAD_DIR}/${OBJECT_KEY_1}
    ...    min_size_bytes=10
    ...    expected_extension=.txt

    Log    \n<===================▶CLEANUP ==================    console=yes
    Clean Bucket By Prefix    ${BUCKET_NAME}    ${PREFIX}
    Delete Bucket    ${BUCKET_NAME}    force=${TRUE}


*** Keywords ***
Initialize Tutorial
    [Documentation]    Generates ${unique_id}, ensures ${BUCKET_NAME} exists,
    ...    and pre-cleans the tutorial prefix so the test starts fresh.
    ...    Sample files live under ./sample_files/ and are checked into the repo —
    ...    they're not created here.

    ${unique_id}=    Get Unique Id
    Set Suite Variable    ${unique_id}    ${unique_id}
    Log    Generated unique_id: ${unique_id}    console=yes

    # Make sure the local download directory is empty/clean
    Remove Directory If Exists    ${DOWNLOAD_DIR}
    Create Directory    ${DOWNLOAD_DIR}

    # Make sure the bucket the tutorial uses actually exists. Idempotent —
    # safe to call whether or not minio-setup pre-created it.
    # Section    CREATE BUCKET BEFORE SUITE
    # Create Bucket    ${BUCKET_NAME}

    # Pre-clean any leftover tutorial files from a previous run so tests are deterministic.
    # Run Keyword And Ignore Error    Clean Bucket By Prefix    ${BUCKET_NAME}    ${PREFIX}

Cleanup Tutorial
    [Documentation]    Removes downloaded files and tutorial-prefixed objects from the bucket.
    ...    Runs even if a test failed mid-suite so we don't leak files.
    ...    Note: sample_files/ is checked into the repo — we never delete those.

    Run Keyword And Ignore Error    Remove Directory If Exists    ${DOWNLOAD_DIR}
    Run Keyword And Ignore Error    Clean Bucket By Prefix    ${BUCKET_NAME}    ${PREFIX}
    # Delete the bucket too — covers the case where a test failed before
    # test 19 (Delete Bucket) had a chance to run.
    Run Keyword And Ignore Error    Delete Bucket    ${BUCKET_NAME}    force=${TRUE}
