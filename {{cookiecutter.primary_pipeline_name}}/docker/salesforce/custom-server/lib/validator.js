'use strict';

/**
 * Salesforce Field Validator
 * ==========================
 *
 * Validates request body against a Salesforce object schema.
 * Matches real Salesforce REST API validation behavior:
 *   1. Required fields: Returns REQUIRED_FIELD_MISSING if missing on Create
 *   2. Picklist values: Returns INVALID_OR_NULL_FOR_RESTRICTED_PICKLIST
 *   3. Max length: Returns STRING_TOO_LONG if string exceeds maxLength
 *   4. Createable/Updateable: Returns INVALID_FIELD_FOR_INSERT_UPDATE if field is read-only
 *   5. Unknown fields: Silently accepted (matches real Salesforce)
 *
 * Validation rules are defined in the schema JSON files (schemas/*.json).
 * Each field definition can have: required, type, values (picklist), maxLength,
 * createable, updateable.
 */

/**
 * Validates a request body against a Salesforce object schema.
 *
 * On CREATE: checks that all required fields are present, then validates
 * each provided field against its schema definition.
 *
 * On UPDATE: skips required field checks (partial updates are allowed),
 * but still validates provided field values.
 *
 * Returns an array of error objects. Empty array = validation passed.
 * Each error object matches the Salesforce REST API error format:
 *   { message, errorCode, fields }
 *
 * @param {Object} body - The request body containing field values to validate
 * @param {Object} schema - The Salesforce object schema (loaded from schemas/*.json)
 * @param {Object} schema.fields - Map of field names to field definitions
 * @param {string} operation - Either 'create' or 'update'
 * @returns {Object[]} Array of error objects. Empty array means validation passed.
 *
 * @example
 *   // ✅ Valid create — all required fields present:
 *   validate(
 *     { Name: 'Acme Corp', Type: 'Customer' },
 *     accountSchema,   // Account.json — Name is required
 *     'create'
 *   );
 *   // Returns: [] (empty array = no errors, validation passed)
 *
 * @example
 *   // ❌ Missing required field on create:
 *   validate(
 *     { Type: 'Customer' },   // Missing "Name" which is required
 *     accountSchema,
 *     'create'
 *   );
 *   // Returns: [{
 *   //   message: "Required fields are missing: [Name]",
 *   //   errorCode: "REQUIRED_FIELD_MISSING",
 *   //   fields: ["Name"]
 *   // }]
 *
 * @example
 *   // ✅ Valid update — required fields NOT checked (partial update is OK):
 *   validate(
 *     { Type: 'Partner' },    // Only updating Type, Name not required here
 *     accountSchema,
 *     'update'
 *   );
 *   // Returns: [] (no errors)
 *
 * @example
 *   // ❌ Invalid picklist value:
 *   validate(
 *     { Name: 'Acme Corp', Type: 'InvalidType' },   // Type picklist doesn't include "InvalidType"
 *     accountSchema,
 *     'create'
 *   );
 *   // Returns: [{
 *   //   message: "Type: bad value for restricted picklist field: InvalidType",
 *   //   errorCode: "INVALID_OR_NULL_FOR_RESTRICTED_PICKLIST",
 *   //   fields: ["Type"]
 *   // }]
 *
 * @example
 *   // ❌ String exceeds max length:
 *   validate(
 *     { Name: 'A'.repeat(300) },   // Name has maxLength: 255
 *     accountSchema,
 *     'create'
 *   );
 *   // Returns: [{
 *   //   message: "Name: data value too large: AAAAAAA... (max length=255)",
 *   //   errorCode: "STRING_TOO_LONG",
 *   //   fields: ["Name"]
 *   // }]
 *
 * @example
 *   // ❌ Writing to a read-only field on create:
 *   validate(
 *     { Name: 'Acme', CreatedDate: '2024-01-01' },   // CreatedDate has createable: false
 *     accountSchema,
 *     'create'
 *   );
 *   // Returns: [{
 *   //   message: "Unable to create/update fields: CreatedDate...",
 *   //   errorCode: "INVALID_FIELD_FOR_INSERT_UPDATE",
 *   //   fields: ["CreatedDate"]
 *   // }]
 *
 * @example
 *   // Unknown fields are silently accepted (matches real Salesforce):
 *   validate(
 *     { Name: 'Acme', CustomField__c: 'hello' },   // CustomField__c not in schema
 *     accountSchema,
 *     'create'
 *   );
 *   // Returns: [] (no errors — unknown fields are ignored)
 */
function validate(body, schema, operation) {
  const errors = [];
  const fields = schema.fields || {};

  // ─────────────────────────────────────────────────────────────────────
  // Check required fields (only on create, not update)
  // On update (PATCH), Salesforce allows partial updates — you only send
  // the fields you want to change. So required field checks are skipped.
  // ─────────────────────────────────────────────────────────────────────
  if (operation === 'create') {
    for (const [fieldName, fieldDef] of Object.entries(fields)) {
      if (fieldDef.required && (body[fieldName] === undefined || body[fieldName] === null || body[fieldName] === '')) {
        errors.push({
          message: `Required fields are missing: [${fieldName}]`,
          errorCode: 'REQUIRED_FIELD_MISSING',
          fields: [fieldName]
        });
      }
    }
  }

  // ─────────────────────────────────────────────────────────────────────
  // Validate each provided field against its schema definition
  // Fields not in the schema are silently accepted (real Salesforce does this too)
  // ─────────────────────────────────────────────────────────────────────
  for (const [fieldName, value] of Object.entries(body)) {
    const fieldDef = fields[fieldName];

    // Unknown fields are silently accepted (matches real Salesforce)
    if (!fieldDef) continue;

    // Skip null values for non-required fields
    if (value === null && !fieldDef.required) continue;

    // Check createable/updateable — some fields are read-only
    // Example: Id, CreatedDate, SystemModstamp are not createable/updateable
    if (operation === 'create' && fieldDef.createable === false) {
      errors.push({
        message: `Unable to create/update fields: ${fieldName}. Please check the security settings of this field.`,
        errorCode: 'INVALID_FIELD_FOR_INSERT_UPDATE',
        fields: [fieldName]
      });
      continue;
    }

    if (operation === 'update' && fieldDef.updateable === false) {
      errors.push({
        message: `Unable to create/update fields: ${fieldName}. Please check the security settings of this field.`,
        errorCode: 'INVALID_FIELD_FOR_INSERT_UPDATE',
        fields: [fieldName]
      });
      continue;
    }

    // Picklist validation — check value is in the allowed list
    // Example: Account.Type must be one of ["Customer", "Partner", "Prospect"]
    if (fieldDef.type === 'picklist' && fieldDef.values && value !== null) {
      if (!fieldDef.values.includes(value)) {
        errors.push({
          message: `${fieldName}: bad value for restricted picklist field: ${value}`,
          errorCode: 'INVALID_OR_NULL_FOR_RESTRICTED_PICKLIST',
          fields: [fieldName]
        });
      }
    }

    // Max length validation for string types
    // Example: Account.Name has maxLength: 255
    if (fieldDef.maxLength && typeof value === 'string' && value.length > fieldDef.maxLength) {
      errors.push({
        message: `${fieldName}: data value too large: ${value.substring(0, 50)}... (max length=${fieldDef.maxLength})`,
        errorCode: 'STRING_TOO_LONG',
        fields: [fieldName]
      });
    }
  }

  return errors;
}

module.exports = { validate };
