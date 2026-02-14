"""
Salesforce Error Formatter
==========================
Port of: lib/error-formatter.js

Formats errors to match the real Salesforce REST API error response format.
Salesforce always returns errors as an ARRAY of error objects.
"""

ERROR_MESSAGES = {
    'NOT_FOUND': 'The requested resource does not exist',
    'REQUIRED_FIELD_MISSING': 'Required fields are missing',
    'INVALID_FIELD': 'Invalid field',
    'INVALID_TYPE': 'Invalid type',
    'INVALID_OR_NULL_FOR_RESTRICTED_PICKLIST': 'Invalid value for restricted picklist field',
    'MALFORMED_QUERY': 'SOQL query is malformed',
    'ENTITY_IS_DELETED': 'Entity is deleted',
    'DUPLICATE_VALUE': 'Duplicate value found',
    'INVALID_CROSS_REFERENCE_KEY': 'Invalid cross reference key',
    'INVALID_SESSION_ID': 'Session expired or invalid',
    'METHOD_NOT_ALLOWED': 'HTTP method not allowed for this resource',
}


def format_error(error_code, message=None, fields=None):
    """
    Format an error into Salesforce REST API format.

    Returns an ARRAY containing one error object (matching real Salesforce).

    Args:
        error_code: Salesforce error code (e.g., 'NOT_FOUND')
        message: Custom error message (optional, uses default if omitted)
        fields: Array of field names related to the error (optional)

    Returns:
        List containing one error dict: [{"message", "errorCode", "fields"}]
    """
    return [{
        'message': message or ERROR_MESSAGES.get(error_code, 'An error occurred'),
        'errorCode': error_code,
        'fields': fields or []
    }]
