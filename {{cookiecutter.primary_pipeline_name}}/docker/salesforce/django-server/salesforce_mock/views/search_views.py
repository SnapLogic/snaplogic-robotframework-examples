"""
Salesforce SOSL Search Views
=============================
Port of: search-routes.js

Implements the Salesforce SOSL (Salesforce Object Search Language) search endpoint.
SOSL performs cross-object text searches, unlike SOQL which queries a single object.

Routes:
    GET /services/data/:version/search  - Execute SOSL query via ?q= parameter

Used by the SnapLogic "Salesforce SOSL" snap.

SOSL syntax:
    FIND {searchTerm} [IN scope] RETURNING Object1(Field1, Field2), Object2(Field1)
"""
import logging
import re

from django.http import JsonResponse

from salesforce_mock.state.database import schemas, database
from salesforce_mock.parsers.sosl_parser import parse_sosl, search_records
from salesforce_mock.parsers.soql_parser import apply_where
from salesforce_mock.utils.error_formatter import format_error

logger = logging.getLogger(__name__)


# =====================================================================
# Helper: Simple WHERE parser for RETURNING clauses
# =====================================================================

def parse_simple_where(where_str):
    """
    Parse a simple WHERE string into condition objects compatible with apply_where().

    This is a simplified parser for RETURNING WHERE clauses.
    Supports: field = 'value', field != 'value', AND, OR

    Args:
        where_str: The WHERE clause content (without "WHERE" keyword).

    Returns:
        List of condition dicts with keys: field, operator, value, logical.
    """
    conditions = []
    parts = re.split(r'\b(AND|OR)\b', where_str, flags=re.IGNORECASE)
    logical = None

    for part in parts:
        trimmed = part.strip()
        if trimmed.upper() in ('AND', 'OR'):
            logical = trimmed.upper()
            continue

        # Parse: field operator value
        match = re.match(r'^(\w+)\s*(!=|<>|>=|<=|>|<|=)\s*(.+)$', trimmed)
        if match:
            value = match.group(3).strip()

            # Detect and convert value types
            if value.startswith("'") and value.endswith("'"):
                # String value — strip quotes
                value = value[1:-1]
            elif value.lower() == 'true':
                value = True
            elif value.lower() == 'false':
                value = False
            elif value.lower() == 'null':
                value = None
            else:
                # Attempt numeric conversion
                try:
                    value = float(value) if '.' in value else int(value)
                except ValueError:
                    pass

            operator = '!=' if match.group(2) == '<>' else match.group(2)
            conditions.append({
                'field': match.group(1),
                'operator': operator,
                'value': value,
                'logical': logical,
            })
            logical = None

    return conditions


# =====================================================================
# View: SOSL Search
# =====================================================================

def sosl_search(request, version):
    """
    GET /services/data/:version/search

    Execute a SOSL search query across multiple objects.

    Query Parameters:
        q: The SOSL query string.

    Examples:
        GET /services/data/v59.0/search?q=FIND+{Acme}+RETURNING+Account(Id,Name)
        Response: {"searchRecords": [{"attributes": {...}, "Id": "001...", "Name": "Acme Corp"}]}

        Multi-object search:
        GET /services/data/v59.0/search?q=FIND+{test}+RETURNING+Account(Id,Name),Contact(Id,Email)
        Response: {"searchRecords": [...accounts, ...contacts]}
    """
    sosl = request.GET.get('q')

    if not sosl:
        return JsonResponse(
            format_error('MALFORMED_QUERY',
                         'SOSL query is required. Use ?q=FIND+{term}+RETURNING+Object(fields)'),
            status=400,
            safe=False,
        )

    try:
        parsed = parse_sosl(sosl)
    except (ValueError, Exception) as exc:
        return JsonResponse(
            format_error('MALFORMED_QUERY', str(exc)),
            status=400,
            safe=False,
        )

    all_results = []

    # Process each RETURNING object
    for returning in parsed['returning']:
        object_name = returning['object']

        # Check if object exists in schemas
        if object_name not in schemas:
            # Skip unknown objects (Salesforce silently skips them in SOSL)
            logger.warning("SOSL: Skipping unknown object '%s'", object_name)
            continue

        # Get records for this object
        records = list(database.get(object_name, []))

        # Search: filter records by search term
        records = search_records(records, parsed['search_term'], parsed['scope'])

        # Apply WHERE filter if specified in RETURNING clause
        if returning.get('where'):
            conditions = parse_simple_where(returning['where'])
            if conditions:
                records = apply_where(records, conditions)

        # Apply LIMIT if specified
        if returning.get('limit'):
            records = records[:returning['limit']]

        # Project fields
        for record in records:
            row = {
                'attributes': {
                    'type': object_name,
                    'url': (
                        record.get('attributes', {}).get('url')
                        or f'/services/data/{version}/sobjects/{object_name}/{record.get("Id")}'
                    ),
                },
            }

            if not returning['fields'] or '*' in returning['fields']:
                # No fields specified or wildcard -- return all fields
                for key, val in record.items():
                    if key != 'attributes':
                        row[key] = val
            else:
                # Project only requested fields
                for field in returning['fields']:
                    if field in record:
                        row[field] = record[field]

            all_results.append(row)

    logger.info(
        "SOSL: FIND {%s} -> %d results",
        parsed['search_term'],
        len(all_results),
    )
    return JsonResponse({'searchRecords': all_results})
