"""
Salesforce Field Validator
==========================
Port of: lib/validator.js

Validates request body against a Salesforce object schema.
Matches real Salesforce REST API validation behavior:
  1. Required fields: REQUIRED_FIELD_MISSING if missing on Create
  2. Picklist values: INVALID_OR_NULL_FOR_RESTRICTED_PICKLIST
  3. Max length: STRING_TOO_LONG if string exceeds maxLength
  4. Createable/Updateable: INVALID_FIELD_FOR_INSERT_UPDATE if read-only
  5. Unknown fields: Silently accepted (matches real Salesforce)
"""


def validate(body, schema, operation):
    """
    Validate a request body against a Salesforce object schema.

    On CREATE: checks required fields are present, validates all provided fields.
    On UPDATE: skips required field checks (partial updates allowed).

    Args:
        body: Dict of field values to validate
        schema: Schema dict loaded from schemas/*.json
        operation: 'create' or 'update'

    Returns:
        List of error dicts. Empty list = validation passed.
    """
    errors = []
    fields = schema.get('fields', {})

    # Check required fields (only on create)
    if operation == 'create':
        for field_name, field_def in fields.items():
            if field_def.get('required') and (
                field_name not in body
                or body[field_name] is None
                or body[field_name] == ''
            ):
                errors.append({
                    'message': f'Required fields are missing: [{field_name}]',
                    'errorCode': 'REQUIRED_FIELD_MISSING',
                    'fields': [field_name]
                })

    # Validate each provided field
    for field_name, value in body.items():
        field_def = fields.get(field_name)

        # Unknown fields silently accepted (matches real Salesforce)
        if not field_def:
            continue

        # Skip null values for non-required fields
        if value is None and not field_def.get('required'):
            continue

        # Check createable/updateable
        if operation == 'create' and field_def.get('createable') is False:
            errors.append({
                'message': f'Unable to create/update fields: {field_name}. Please check the security settings of this field.',
                'errorCode': 'INVALID_FIELD_FOR_INSERT_UPDATE',
                'fields': [field_name]
            })
            continue

        if operation == 'update' and field_def.get('updateable') is False:
            errors.append({
                'message': f'Unable to create/update fields: {field_name}. Please check the security settings of this field.',
                'errorCode': 'INVALID_FIELD_FOR_INSERT_UPDATE',
                'fields': [field_name]
            })
            continue

        # Picklist validation
        if field_def.get('type') == 'picklist' and field_def.get('values') and value is not None:
            if value not in field_def['values']:
                errors.append({
                    'message': f'{field_name}: bad value for restricted picklist field: {value}',
                    'errorCode': 'INVALID_OR_NULL_FOR_RESTRICTED_PICKLIST',
                    'fields': [field_name]
                })

        # Max length validation
        if field_def.get('maxLength') and isinstance(value, str) and len(value) > field_def['maxLength']:
            errors.append({
                'message': f'{field_name}: data value too large: {value[:50]}... (max length={field_def["maxLength"]})',
                'errorCode': 'STRING_TOO_LONG',
                'fields': [field_name]
            })

    return errors
