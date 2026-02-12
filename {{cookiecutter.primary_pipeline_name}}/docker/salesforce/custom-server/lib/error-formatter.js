'use strict';

/**
 * Salesforce Error Formatter
 * ==========================
 *
 * Formats errors to match the real Salesforce REST API error response format.
 * Salesforce REST API always returns errors as an ARRAY of error objects,
 * even for a single error. Each object has: message, errorCode, fields.
 *
 * Reference: https://developer.salesforce.com/docs/atlas.en-us.api_rest.meta/api_rest/errorcodes.htm
 *
 * Real Salesforce error response example:
 *   [
 *     {
 *       "message": "Required fields are missing: [Name]",
 *       "errorCode": "REQUIRED_FIELD_MISSING",
 *       "fields": ["Name"]
 *     }
 *   ]
 */

/**
 * Lookup table of standard Salesforce error codes and their default messages.
 * These match the error codes documented in the Salesforce REST API reference.
 * When formatError() is called without a custom message, it falls back to these.
 */
const ERROR_MESSAGES = {
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
  'METHOD_NOT_ALLOWED': 'HTTP method not allowed for this resource'
};

/**
 * Formats an error into the Salesforce REST API error response format.
 *
 * Returns an ARRAY containing one error object (matching real Salesforce behavior).
 * This is important because SnapLogic parses the response expecting an array.
 *
 * @param {string} errorCode - A Salesforce error code (e.g., 'NOT_FOUND', 'REQUIRED_FIELD_MISSING')
 * @param {string} [message] - Custom error message. If omitted, uses the default from ERROR_MESSAGES.
 * @param {string[]} [fields] - Array of field names related to the error. Defaults to empty array.
 * @returns {Object[]} Array containing one error object: [{ message, errorCode, fields }]
 *
 * @example
 *   // Record not found (custom message):
 *   formatError('NOT_FOUND', "sObject type 'Invoice' is not supported.");
 *   // Returns: [{ message: "sObject type 'Invoice' is not supported.", errorCode: "NOT_FOUND", fields: [] }]
 *
 * @example
 *   // Record not found (default message):
 *   formatError('NOT_FOUND');
 *   // Returns: [{ message: "The requested resource does not exist", errorCode: "NOT_FOUND", fields: [] }]
 *
 * @example
 *   // Required field missing (with field names):
 *   formatError('REQUIRED_FIELD_MISSING', 'Required fields are missing: [Name]', ['Name']);
 *   // Returns: [{ message: "Required fields are missing: [Name]", errorCode: "REQUIRED_FIELD_MISSING", fields: ["Name"] }]
 *
 * @example
 *   // Invalid picklist value:
 *   formatError('INVALID_OR_NULL_FOR_RESTRICTED_PICKLIST', 'Type: bad value for restricted picklist field: InvalidType', ['Type']);
 *   // Returns: [{ message: "Type: bad value...", errorCode: "INVALID_OR_NULL_FOR_RESTRICTED_PICKLIST", fields: ["Type"] }]
 *
 * @example
 *   // Malformed SOQL query:
 *   formatError('MALFORMED_QUERY', 'SOQL query is required. Use ?q=SELECT...');
 *   // Returns: [{ message: "SOQL query is required...", errorCode: "MALFORMED_QUERY", fields: [] }]
 */
function formatError(errorCode, message, fields) {
  return [{
    message: message || ERROR_MESSAGES[errorCode] || 'An error occurred',
    errorCode: errorCode,
    fields: fields || []
  }];
}

module.exports = { formatError };
