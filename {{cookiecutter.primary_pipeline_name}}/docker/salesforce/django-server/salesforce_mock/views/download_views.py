"""
Salesforce Download Views
=========================
Port of: download-routes.js

Implements file/attachment binary content download endpoints.
Used by the SnapLogic "Salesforce Download" snap.

Routes:
    GET /services/data/:version/sobjects/Attachment/:id/Body          - Download Attachment body
    GET /services/data/:version/sobjects/ContentVersion/:id/VersionData - Download ContentVersion body
    GET /services/data/:version/sobjects/Document/:id/Body            - Download Document body

IMPORTANT: These URL patterns MUST be registered BEFORE the generic
sobjects/:object/:id pattern, otherwise the generic route would match first
(treating "Body"/"VersionData" as the :id parameter).

How it works:
    1. Create a record with a base64-encoded Body/VersionData field (via REST Create)
    2. Download the binary content via these endpoints
    3. The mock decodes base64 and returns raw bytes with correct Content-Type
"""
import base64
import logging

from django.http import JsonResponse, HttpResponse

from salesforce_mock.state.database import database
from salesforce_mock.utils.error_formatter import format_error

logger = logging.getLogger(__name__)


# =====================================================================
# Helper: shared download logic
# =====================================================================

def _handle_download(db, object_name, record_id, body_field):
    """
    Handle the download logic for any object/field combination.

    Steps:
        1. Look up the record by ID in the database
        2. Extract the binary field (Body or VersionData)
        3. Decode from base64 to bytes
        4. Set Content-Type from the record's ContentType field
        5. Return the raw binary content

    Args:
        db: In-memory database dict (object_name -> list of records).
        object_name: Salesforce object name (Attachment, ContentVersion, Document).
        record_id: The record ID to download from.
        body_field: The field containing base64 data (Body or VersionData).

    Returns:
        HttpResponse with binary content or JsonResponse with error.
    """
    records = db.get(object_name, [])
    record = next((r for r in records if r.get('Id') == record_id), None)

    if not record:
        return JsonResponse(
            format_error('NOT_FOUND',
                         f'{object_name} record not found: {record_id}'),
            status=404,
            safe=False,
        )

    body_data = record.get(body_field)
    if not body_data:
        return JsonResponse(
            format_error('NOT_FOUND',
                         f'{object_name} record {record_id} has no {body_field} data'),
            status=404,
            safe=False,
        )

    # Decode base64 to binary
    binary_content = base64.b64decode(body_data)

    # Determine content type from the record's ContentType field
    content_type = record.get('ContentType', 'application/octet-stream')

    # Determine filename for Content-Disposition header
    filename = (
        record.get('Name')
        or record.get('Title')
        or record.get('PathOnClient')
        or 'download'
    )

    logger.info(
        "Download: %s/%s/%s (%d bytes, %s)",
        object_name, record_id, body_field, len(binary_content), content_type,
    )

    response = HttpResponse(binary_content, content_type=content_type)
    response['Content-Disposition'] = f'attachment; filename="{filename}"'
    response['Content-Length'] = len(binary_content)
    return response


# =====================================================================
# Views
# =====================================================================

def download_attachment_body(request, version, record_id):
    """
    GET /services/data/:version/sobjects/Attachment/:id/Body

    Download the binary body of an Attachment record.
    The Body field is stored as a base64-encoded string when created via REST API.

    Example:
        1. Create Attachment with base64 body:
           POST /services/data/v59.0/sobjects/Attachment
           {"Name": "test.txt", "ParentId": "001xxx", "Body": "SGVsbG8=", "ContentType": "text/plain"}

        2. Download body:
           GET /services/data/v59.0/sobjects/Attachment/00PXXX/Body
           Response: raw bytes (decoded from base64), Content-Type: text/plain
    """
    return _handle_download(database, 'Attachment', record_id, 'Body')


def download_content_version(request, version, record_id):
    """
    GET /services/data/:version/sobjects/ContentVersion/:id/VersionData

    Download the binary content of a ContentVersion record.
    The VersionData field is stored as a base64-encoded string.

    Example:
        GET /services/data/v59.0/sobjects/ContentVersion/068XXX/VersionData
        Response: raw bytes, Content-Type from record's ContentType field
    """
    return _handle_download(database, 'ContentVersion', record_id, 'VersionData')


def download_document_body(request, version, record_id):
    """
    GET /services/data/:version/sobjects/Document/:id/Body

    Download the binary body of a Document record.

    Example:
        GET /services/data/v59.0/sobjects/Document/015XXX/Body
        Response: raw bytes, Content-Type from record's ContentType field
    """
    return _handle_download(database, 'Document', record_id, 'Body')
