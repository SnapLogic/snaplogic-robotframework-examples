"""
SOSL Query Parser
=================
Port of: lib/sosl-parser.js

Parses Salesforce Object Search Language (SOSL) queries.

Syntax:
  FIND {searchTerm} [IN scope] RETURNING Object1(Field1, Field2 [WHERE cond] [LIMIT n])

Exports: parse_sosl(), search_records()
"""
import re


def parse_sosl(sosl):
    """
    Parse a SOSL query string into a structured dict.

    Returns:
        dict with keys: search_term, scope, returning
    """
    if not sosl or not isinstance(sosl, str):
        raise ValueError('SOSL query is required')

    normalized = re.sub(r'\s+', ' ', sosl.strip())
    result = {'search_term': None, 'scope': 'ALL', 'returning': []}

    # Parse FIND clause
    find_match = re.match(r'^FIND\s+\{([^}]+)\}', normalized, re.IGNORECASE)
    if not find_match:
        raise ValueError(f'Malformed SOSL: Cannot parse FIND clause: {sosl}')
    result['search_term'] = find_match.group(1).strip()

    # Parse optional IN clause
    in_match = re.search(r'\bIN\s+(ALL|NAME|EMAIL|PHONE|SIDEBAR)\s+FIELDS\b', normalized, re.IGNORECASE)
    if in_match:
        result['scope'] = in_match.group(1).upper()

    # Parse RETURNING clause
    returning_match = re.search(r'\bRETURNING\s+(.+)$', normalized, re.IGNORECASE)
    if not returning_match:
        raise ValueError(f'Malformed SOSL: Cannot parse RETURNING clause: {sosl}')

    result['returning'] = _parse_returning_clause(returning_match.group(1).strip())
    return result


def _parse_returning_clause(s):
    """Parse RETURNING clause into list of object specs."""
    objects = []
    parts = _split_top_level_commas(s)

    for part in parts:
        trimmed = part.strip()
        if not trimmed:
            continue

        obj_match = re.match(r'^(\w+)(?:\((.+)\))?$', trimmed)
        if not obj_match:
            continue

        spec = {
            'object': obj_match.group(1),
            'fields': [],
            'where': None,
            'limit': None
        }

        if obj_match.group(2):
            _parse_returning_fields(obj_match.group(2).strip(), spec)

        objects.append(spec)

    return objects


def _split_top_level_commas(s):
    """Split by commas not inside parentheses."""
    parts = []
    current = ''
    depth = 0

    for ch in s:
        if ch == '(':
            depth += 1
        elif ch == ')':
            depth -= 1
        elif ch == ',' and depth == 0:
            parts.append(current)
            current = ''
            continue
        current += ch

    if current.strip():
        parts.append(current)
    return parts


def _parse_returning_fields(inner, spec):
    """Parse inner content of RETURNING parentheses."""
    remaining = inner

    # Extract LIMIT
    limit_match = re.search(r'\bLIMIT\s+(\d+)\s*$', remaining, re.IGNORECASE)
    if limit_match:
        spec['limit'] = int(limit_match.group(1))
        remaining = remaining[:limit_match.start()].strip()

    # Extract WHERE
    where_match = re.search(r'\bWHERE\s+(.+)$', remaining, re.IGNORECASE)
    if where_match:
        spec['where'] = where_match.group(1).strip()
        remaining = remaining[:where_match.start()].strip()

    # Remaining is field list
    spec['fields'] = [f.strip() for f in remaining.split(',') if f.strip()]


def search_records(records, search_term, scope):
    """
    Search records for a term in string fields.

    Args:
        records: List of record dicts
        search_term: Text to search for
        scope: 'ALL', 'NAME', 'EMAIL', or 'PHONE'

    Returns:
        List of matching records
    """
    term = search_term.lower()

    scope_fields = {
        'NAME': ['Name', 'FirstName', 'LastName', 'Title', 'Subject'],
        'EMAIL': ['Email', 'PersonEmail'],
        'PHONE': ['Phone', 'MobilePhone', 'Fax', 'HomePhone'],
    }

    def matches(record):
        if scope == 'ALL':
            fields_to_search = record.keys()
        else:
            fields_to_search = scope_fields.get(scope, record.keys())

        for field in fields_to_search:
            value = record.get(field)
            if value is None:
                continue
            if not isinstance(value, (str, int, float)):
                continue
            if term in str(value).lower():
                return True
        return False

    return [r for r in records if matches(r)]
