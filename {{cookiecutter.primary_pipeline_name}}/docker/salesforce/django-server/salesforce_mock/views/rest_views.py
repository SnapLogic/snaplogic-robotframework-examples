"""
Salesforce REST API Views
=========================
Port of: lib/routes/rest-routes.js

All Django function-based views for the Salesforce REST API (single-record operations).
No object-specific code -- the object_name URL parameter + schema files
handle everything dynamically.

Views:
  oauth_token          - POST   /services/oauth2/token
  describe_object      - GET    /services/data/<version>/sobjects/<object>/describe
  create_record        - POST   /services/data/<version>/sobjects/<object>
  get_record           - GET    /services/data/<version>/sobjects/<object>/<id>
  update_record        - PATCH  /services/data/<version>/sobjects/<object>/<id>
  delete_record        - DELETE /services/data/<version>/sobjects/<object>/<id>
  upsert_record        - PATCH  /services/data/<version>/sobjects/<object>/<ext>/<val>
  soql_query           - GET    /services/data/<version>/query
  api_limits           - GET    /services/data/<version>/limits

These are the standard Salesforce REST API endpoints that SnapLogic
Salesforce snaps (Create, Read, Update, Delete, SOQL) use when
configured with "REST API" (not "Bulk API").
"""

import json
import random
import string
import time
from datetime import datetime, timezone

from django.conf import settings
from django.http import JsonResponse, HttpResponse
from django.views.decorators.csrf import csrf_exempt

from salesforce_mock.state.database import schemas, database
from salesforce_mock.utils.id_generator import generate_id
from salesforce_mock.utils.error_formatter import format_error
from salesforce_mock.utils.validator import validate
from salesforce_mock.parsers.soql_parser import parse_soql, apply_where, apply_order_by


# =====================================================================
# OAUTH ENDPOINT (Mock)
# =====================================================================

@csrf_exempt
def oauth_token(request):
    """
    POST /services/oauth2/token

    Mock Salesforce OAuth2 token endpoint.
    Accepts ANY credentials and returns a valid-looking token.
    This is the first call every SnapLogic Salesforce snap makes.
    """
    timestamp = int(time.time() * 1000)
    random_suffix = ''.join(random.choices(string.ascii_lowercase + string.digits, k=13))
    token = f'00D000000000000!mock.token.{timestamp}.{random_suffix}'

    protocol = 'https' if request.is_secure() else 'http'
    container_name = 'salesforce-api-mock'
    port = settings.HTTPS_PORT if request.is_secure() else settings.HTTP_PORT

    signature = ''.join(random.choices(string.ascii_lowercase + string.digits, k=44))

    return JsonResponse({
        'access_token': token,
        'instance_url': f'{protocol}://{container_name}:{port}',
        'id': f'{protocol}://{container_name}:{port}/id/00D000000000000EAA/005000000000000AAA',
        'token_type': 'Bearer',
        'issued_at': str(timestamp),
        'signature': signature,
    })


# =====================================================================
# DESCRIBE ENDPOINT
# =====================================================================

def describe_object(request, version, object_name):
    """
    GET /services/data/<version>/sobjects/<object_name>/describe

    Returns Salesforce object metadata (field definitions, types, picklist values).
    SnapLogic calls this BEFORE every operation to discover available fields.
    """
    schema = schemas.get(object_name)

    if not schema:
        return JsonResponse(
            format_error('NOT_FOUND', f"sObject type '{object_name}' is not supported."),
            status=404,
            safe=False,
        )

    fields = [
        {
            'name': 'Id',
            'type': 'id',
            'label': f"{schema['label']} ID",
            'length': 18,
            'updateable': False,
            'createable': False,
            'nillable': False,
            'queryable': True,
            'filterable': True,
            'picklistValues': [],
        }
    ]

    for name, field_def in schema.get('fields', {}).items():
        picklist_values = []
        for i, v in enumerate(field_def.get('values', [])):
            picklist_values.append({
                'value': v,
                'label': v,
                'active': True,
                'defaultValue': i == 0 and field_def.get('required', False),
            })

        fields.append({
            'name': name,
            'type': field_def.get('type', 'string'),
            'label': field_def.get('label', name),
            'length': field_def.get('maxLength', 18 if field_def.get('type') == 'id' else 0),
            'precision': field_def.get('precision', 0),
            'scale': field_def.get('scale', 0),
            'digits': field_def.get('digits', 0),
            'updateable': field_def.get('updateable', True) is not False,
            'createable': field_def.get('createable', True) is not False,
            'nillable': not field_def.get('required', False),
            'queryable': True,
            'filterable': True,
            'referenceTo': field_def.get('referenceTo', []),
            'picklistValues': picklist_values,
        })

    return JsonResponse({
        'name': schema['name'],
        'label': schema['label'],
        'labelPlural': schema.get('labelPlural', schema['label'] + 's'),
        'keyPrefix': schema.get('keyPrefix', schema.get('idPrefix', '')),
        'fields': fields,
        'createable': True,
        'updateable': True,
        'deletable': True,
        'queryable': True,
        'searchable': True,
        'urls': {
            'sobject': f'/services/data/{version}/sobjects/{object_name}',
            'describe': f'/services/data/{version}/sobjects/{object_name}/describe',
            'rowTemplate': f'/services/data/{version}/sobjects/{object_name}/{{ID}}',
        },
    })


# =====================================================================
# CREATE ENDPOINT
# =====================================================================

@csrf_exempt
def create_record(request, version, object_name):
    """
    POST /services/data/<version>/sobjects/<object_name>

    Creates a new record. Validates against schema, generates SF-style ID.
    """
    schema = schemas.get(object_name)

    if not schema:
        return JsonResponse(
            format_error('NOT_FOUND', f"sObject type '{object_name}' is not supported."),
            status=404,
            safe=False,
        )

    body = json.loads(request.body) if request.body else {}

    errors = validate(body, schema, 'create')
    if len(errors) > 0:
        return JsonResponse(errors, status=400, safe=False)

    record_id = generate_id(schema['idPrefix'])
    now = datetime.now(timezone.utc).isoformat()

    record = {
        'Id': record_id,
        **body,
        'CreatedDate': now,
        'LastModifiedDate': now,
        'SystemModstamp': now,
        'attributes': {
            'type': object_name,
            'url': f'/services/data/{version}/sobjects/{object_name}/{record_id}',
        },
    }

    database[object_name].append(record)
    print(f'  \u2705 Created {object_name}: {record_id}')

    return JsonResponse({'id': record_id, 'success': True, 'errors': []}, status=201)


# =====================================================================
# UPSERT ENDPOINT
# =====================================================================

@csrf_exempt
def upsert_record(request, version, object_name, ext_id_field, ext_id_value):
    """
    PATCH /services/data/<version>/sobjects/<object_name>/<ext_id_field>/<ext_id_value>

    Upserts a record by external ID field. Update if exists, Insert if not.
    """
    schema = schemas.get(object_name)

    if not schema:
        return JsonResponse(
            format_error('NOT_FOUND', f"sObject type '{object_name}' is not supported."),
            status=404,
            safe=False,
        )

    body = json.loads(request.body) if request.body else {}

    records = database[object_name]
    existing_index = None
    for i, r in enumerate(records):
        if str(r.get(ext_id_field, '')) == str(ext_id_value):
            existing_index = i
            break

    if existing_index is not None:
        # Update existing record
        now = datetime.now(timezone.utc).isoformat()
        records[existing_index].update(body)
        records[existing_index]['LastModifiedDate'] = now
        records[existing_index]['SystemModstamp'] = now
        print(f'  \u2705 Upserted (updated) {object_name}: {records[existing_index]["Id"]}')
        return HttpResponse(status=204)
    else:
        # Create new record
        errors = validate(body, schema, 'create')
        if len(errors) > 0:
            return JsonResponse(errors, status=400, safe=False)

        record_id = generate_id(schema['idPrefix'])
        now = datetime.now(timezone.utc).isoformat()

        record = {
            'Id': record_id,
            ext_id_field: ext_id_value,
            **body,
            'CreatedDate': now,
            'LastModifiedDate': now,
            'SystemModstamp': now,
            'attributes': {
                'type': object_name,
                'url': f'/services/data/{version}/sobjects/{object_name}/{record_id}',
            },
        }

        records.append(record)
        print(f'  \u2705 Upserted (created) {object_name}: {record_id}')
        return JsonResponse(
            {'id': record_id, 'success': True, 'errors': [], 'created': True},
            status=201,
        )


# =====================================================================
# READ SINGLE RECORD ENDPOINT
# =====================================================================

def get_record(request, version, object_name, record_id):
    """
    GET /services/data/<version>/sobjects/<object_name>/<record_id>

    Reads a single record by ID from the in-memory database.
    """
    if object_name not in schemas:
        return JsonResponse(
            format_error('NOT_FOUND', f"sObject type '{object_name}' is not supported."),
            status=404,
            safe=False,
        )

    records = database.get(object_name, [])
    record = None
    for r in records:
        if r.get('Id') == record_id:
            record = r
            break

    if not record:
        return JsonResponse(
            format_error(
                'NOT_FOUND',
                f'Provided external ID field does not exist or is not accessible: {record_id}',
            ),
            status=404,
            safe=False,
        )

    response = {**record}
    if 'attributes' not in response:
        response['attributes'] = {
            'type': object_name,
            'url': f'/services/data/{version}/sobjects/{object_name}/{record_id}',
        }

    return JsonResponse(response)


# =====================================================================
# UPDATE ENDPOINT
# =====================================================================

@csrf_exempt
def update_record(request, version, object_name, record_id):
    """
    PATCH /services/data/<version>/sobjects/<object_name>/<record_id>

    Updates an existing record. Returns 204 No Content on success.
    """
    schema = schemas.get(object_name)

    if not schema:
        return JsonResponse(
            format_error('NOT_FOUND', f"sObject type '{object_name}' is not supported."),
            status=404,
            safe=False,
        )

    records = database.get(object_name, [])
    index = None
    for i, r in enumerate(records):
        if r.get('Id') == record_id:
            index = i
            break

    if index is None:
        return JsonResponse(
            format_error(
                'NOT_FOUND',
                f'Provided external ID field does not exist or is not accessible: {record_id}',
            ),
            status=404,
            safe=False,
        )

    body = json.loads(request.body) if request.body else {}

    errors = validate(body, schema, 'update')
    if len(errors) > 0:
        return JsonResponse(errors, status=400, safe=False)

    now = datetime.now(timezone.utc).isoformat()
    records[index].update(body)
    records[index]['LastModifiedDate'] = now
    records[index]['SystemModstamp'] = now

    print(f'  \u2705 Updated {object_name}: {record_id}')
    return HttpResponse(status=204)


# =====================================================================
# DELETE ENDPOINT
# =====================================================================

@csrf_exempt
def delete_record(request, version, object_name, record_id):
    """
    DELETE /services/data/<version>/sobjects/<object_name>/<record_id>

    Deletes a record. Returns 204 No Content on success.
    """
    if object_name not in schemas:
        return JsonResponse(
            format_error('NOT_FOUND', f"sObject type '{object_name}' is not supported."),
            status=404,
            safe=False,
        )

    records = database.get(object_name, [])
    index = None
    for i, r in enumerate(records):
        if r.get('Id') == record_id:
            index = i
            break

    if index is None:
        return JsonResponse(
            format_error(
                'ENTITY_IS_DELETED',
                f'Entity is deleted or does not exist: {record_id}',
            ),
            status=404,
            safe=False,
        )

    records.pop(index)
    print(f'  \u2705 Deleted {object_name}: {record_id}')
    return HttpResponse(status=204)


# =====================================================================
# SOQL QUERY ENDPOINT
# =====================================================================

def soql_query(request, version):
    """
    GET /services/data/<version>/query

    Parses and executes SOQL queries against the in-memory database.
    """
    soql = request.GET.get('q')

    if not soql:
        return JsonResponse(
            format_error('MALFORMED_QUERY', 'SOQL query is required. Use ?q=SELECT...'),
            status=400,
            safe=False,
        )

    try:
        parsed = parse_soql(soql)
    except (ValueError, Exception) as err:
        return JsonResponse(
            format_error('MALFORMED_QUERY', str(err)),
            status=400,
            safe=False,
        )

    if not parsed.get('object') or parsed['object'] not in schemas:
        return JsonResponse(
            format_error(
                'INVALID_TYPE',
                f"sObject type '{parsed.get('object')}' is not supported. "
                f"Check the spelling or your schema files.",
            ),
            status=400,
            safe=False,
        )

    records = list(database.get(parsed['object'], []))

    # Apply WHERE clause
    if parsed.get('where') and len(parsed['where']) > 0:
        records = apply_where(records, parsed['where'])

    # Apply ORDER BY
    if parsed.get('order_by'):
        records = apply_order_by(records, parsed['order_by'])

    # Apply OFFSET
    if parsed.get('offset'):
        records = records[parsed['offset']:]

    # Apply LIMIT
    if parsed.get('limit'):
        records = records[:parsed['limit']]

    # Handle COUNT() queries
    if parsed.get('is_count'):
        return JsonResponse({'totalSize': len(records), 'done': True, 'records': []})

    # Project fields
    projected = []
    for record in records:
        row = {
            'attributes': {
                'type': parsed['object'],
                'url': (
                    record.get('attributes', {}).get('url')
                    or f"/services/data/{version}/sobjects/{parsed['object']}/{record.get('Id')}"
                ),
            }
        }

        if '*' in parsed.get('fields', []):
            # Wildcard: include all fields except attributes
            for key in record:
                if key != 'attributes':
                    row[key] = record[key]
        else:
            for field in parsed.get('fields', []):
                if field in record and record[field] is not None:
                    row[field] = record[field]
                elif field in record:
                    row[field] = record[field]

        projected.append(row)

    return JsonResponse({
        'totalSize': len(projected),
        'done': True,
        'records': projected,
    })


# =====================================================================
# API LIMITS
# =====================================================================

@csrf_exempt
def record_detail(request, version, object_name, record_id):
    """
    Dispatcher for /services/data/<version>/sobjects/<object_name>/<record_id>
    Routes to get_record, update_record, or delete_record based on HTTP method.
    """
    if request.method == 'GET':
        return get_record(request, version, object_name, record_id)
    elif request.method == 'PATCH':
        return update_record(request, version, object_name, record_id)
    elif request.method == 'DELETE':
        return delete_record(request, version, object_name, record_id)
    else:
        return JsonResponse(
            format_error('METHOD_NOT_ALLOWED', f'{request.method} not allowed'),
            status=405, safe=False,
        )


def api_limits(request, version):
    """
    GET /services/data/<version>/limits

    Returns mock API limits. SnapLogic checks this during connection validation.
    """
    return JsonResponse({
        'DailyApiRequests': {'Max': 1000000, 'Remaining': 999000},
        'DailyBulkApiRequests': {'Max': 10000, 'Remaining': 9900},
        'ConcurrentAsyncGetReportInstances': {'Max': 200, 'Remaining': 200},
        'ConcurrentSyncReportRuns': {'Max': 20, 'Remaining': 20},
        'DailyAsyncApexExecutions': {'Max': 250000, 'Remaining': 250000},
        'HourlyDashboardRefreshes': {'Max': 200, 'Remaining': 200},
    })
