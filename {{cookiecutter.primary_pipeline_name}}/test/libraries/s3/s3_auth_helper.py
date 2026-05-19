"""
Python helpers for S3 / AWS SSO authentication validation.

Why this module exists
----------------------
botocore raises distinct exception classes for each failure mode:
  - ProfileNotFound      → AWS_PROFILE doesn't exist in ~/.aws/config
  - TokenRetrievalError  → cached SSO token has expired and refresh failed
  - (others)             → unexpected boto3 failures

Robot Framework's TRY/EXCEPT can only pattern-match on the exception
MESSAGE string, not on the exception TYPE. To get robust, type-based
matching that survives botocore version bumps and error-message wording
changes, the actual try/except has to live in Python.

This module is that thin Python layer. The Robot side calls
``Create Validated SSO Session`` and reads a clean status code back —
no substring matching anywhere in the Robot code.

Status contract (the API between Python and Robot)
--------------------------------------------------
``create_validated_sso_session(profile_name)`` returns a 3-tuple:

    (status, session_or_none, error_message_or_none)

Status values:
    ok                  — Session is valid and ready for client('s3', ...)
    profile_not_found   — Profile name not present in ~/.aws/config
    no_credentials      — Profile exists but get_credentials() returned None
    token_expired       — SSO token expired and refresh failed
    cache_readonly      — Token is in refresh window but ~/.aws/sso/cache is
                          mounted read-only — user must aws sso login on host
    other_error         — Any unexpected boto3 failure during validation

If you change these strings, update the matching IF chain in
``Validate SSO Session For Profile`` in resources/minio/minio.resource.
"""

import errno
from typing import Optional, Tuple

import boto3
import botocore.exceptions


# Public API — keep this in sync with what the Robot side actually calls.
__all__ = ["create_validated_sso_session"]


# Status constants — single source of truth for the Python <-> Robot contract.
# (Robot can't import these directly, so the matching IFs use the same strings.)
STATUS_OK = "ok"
STATUS_PROFILE_NOT_FOUND = "profile_not_found"
STATUS_NO_CREDENTIALS = "no_credentials"
STATUS_TOKEN_EXPIRED = "token_expired"
STATUS_CACHE_READONLY = "cache_readonly"
STATUS_OTHER_ERROR = "other_error"


def create_validated_sso_session(
    profile_name: str,
) -> Tuple[str, Optional[boto3.Session], Optional[str]]:
    """Create and validate a boto3.Session for an AWS SSO profile.

    Validates three things up-front so the caller gets actionable feedback
    BEFORE making any actual S3 API call:

    1. The profile exists in ~/.aws/config (catches AWS_PROFILE typos).
    2. The session resolves to a Credentials object (catches "never logged in").
    3. The SSO token is not expired (forces a refresh via
       ``get_frozen_credentials()`` so expired tokens fail HERE instead of
       at the first real S3 call where the stack trace is harder to read).

    Args:
        profile_name: The AWS SSO profile name from ~/.aws/config
            (typically passed through from the AWS_PROFILE env var).
            Must be a non-empty string.

    Returns:
        A 3-tuple ``(status, session, error_message)``:
            - On success: ``("ok", <boto3.Session>, None)``
            - On failure: ``(<status>, None, "<error text>")``
        See the module docstring for status values.
    """
    # Defensive guard: callers should pre-validate, but the Python boundary
    # is the right place to bail out cleanly on a bad input rather than
    # letting boto3 emit a confusing error.
    if not profile_name:
        return (
            STATUS_OTHER_ERROR,
            None,
            "profile_name is required (got empty or None)",
        )

    # Step 1 — create the Session and load credentials.
    try:
        session = boto3.Session(profile_name=profile_name)
        creds = session.get_credentials()
    except botocore.exceptions.ProfileNotFound as e:
        return (STATUS_PROFILE_NOT_FOUND, None, str(e))
    except Exception as e:
        # Anything else during session creation is bucketed as 'other_error'
        # rather than misclassified.
        return (STATUS_OTHER_ERROR, None, f"Session creation failed: {e}")

    # Step 2 — must have a Credentials object to proceed.
    if creds is None:
        return (
            STATUS_NO_CREDENTIALS,
            None,
            f"Profile '{profile_name}' resolved to no credentials",
        )

    # Step 3 — force token refresh to detect expired SSO sessions up-front.
    # get_credentials() returns a lazy object even when the cached token has
    # expired; only get_frozen_credentials() actually attempts the refresh.
    try:
        creds.get_frozen_credentials()
    except botocore.exceptions.TokenRetrievalError as e:
        # Cached token is fully expired and the refresh call (to AWS SSO
        # endpoint) failed. User must re-login on the host.
        return (STATUS_TOKEN_EXPIRED, None, str(e))
    except OSError as e:
        # Detect the read-only filesystem case specifically. The framework's
        # docker-compose.yml mounts ~/.aws/ as :ro (read-only) by default, so
        # when boto3 tries to save a refreshed token to ~/.aws/sso/cache/,
        # the write fails with errno.EROFS. The cached token is still valid;
        # we just can't persist a refreshed version from inside the container.
        # The user needs to refresh on the host where the cache is writable.
        if e.errno == errno.EROFS:
            return (STATUS_CACHE_READONLY, None, str(e))
        return (STATUS_OTHER_ERROR, None, f"Token refresh failed: {e}")
    except Exception as e:
        return (STATUS_OTHER_ERROR, None, f"Token refresh failed: {e}")

    return (STATUS_OK, session, None)
