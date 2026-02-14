"""
SOQL Query Parser
=================
Port of: lib/soql-parser.js

Parses Salesforce Object Query Language (SOQL) queries.

Supported:
  SELECT fields FROM Object
  SELECT COUNT() FROM Object
  WHERE field = 'value' / != / > / >= / < / <= / LIKE / IN / NOT IN
  WHERE cond AND cond / OR cond
  ORDER BY field ASC/DESC [NULLS FIRST|LAST]
  LIMIT n / OFFSET n

Exports: parse_soql(), apply_where(), apply_order_by()
"""
import re


def parse_soql(soql):
    """
    Parse a SOQL query string into a structured dict.

    Returns:
        dict with keys: fields, object, where, order_by, limit, offset, is_count
    """
    if not soql or not isinstance(soql, str):
        raise ValueError('SOQL query is required')

    normalized = re.sub(r'\s+', ' ', soql.strip())
    result = {
        'fields': [], 'object': None, 'where': None,
        'order_by': None, 'limit': None, 'offset': None, 'is_count': False
    }

    # Check for COUNT()
    count_match = re.match(r'^SELECT\s+COUNT\(\)\s+FROM\s+(\w+)', normalized, re.IGNORECASE)
    if count_match:
        result['is_count'] = True
        result['object'] = count_match.group(1)
        _parse_where_clause(normalized, result)
        return result

    # Parse SELECT fields
    select_match = re.match(r'^SELECT\s+(.+?)\s+FROM\s+(\w+)', normalized, re.IGNORECASE)
    if not select_match:
        raise ValueError(f'Malformed SOQL: Cannot parse SELECT...FROM: {soql}')

    result['fields'] = [f.strip() for f in select_match.group(1).split(',') if f.strip()]
    result['object'] = select_match.group(2)

    _parse_where_clause(normalized, result)
    _parse_order_by(normalized, result)
    _parse_limit(normalized, result)
    _parse_offset(normalized, result)

    return result


# ═══════════════════════════════════════════════════════════════
# WHERE CLAUSE PARSING
# ═══════════════════════════════════════════════════════════════

def _parse_where_clause(soql, result):
    """Extract and parse WHERE clause from SOQL string."""
    where_match = re.search(
        r'\bWHERE\s+(.+?)(?:\s+ORDER\s+BY|\s+LIMIT|\s+OFFSET|$)',
        soql, re.IGNORECASE
    )
    if not where_match:
        return
    result['where'] = _parse_conditions(where_match.group(1).strip())


def _parse_conditions(cond_str):
    """Parse WHERE clause string into array of condition objects."""
    conditions = []
    parts = _split_by_logical_operators(cond_str)

    for part in parts:
        condition = _parse_single_condition(part['condition'])
        if condition:
            condition['logical'] = part['logical']
            conditions.append(condition)
    return conditions


def _split_by_logical_operators(s):
    """Split WHERE clause by AND/OR, respecting quoted strings."""
    parts = []
    current = ''
    in_quote = False
    tokens = s.split()
    logical = None

    for token in tokens:
        quote_count = token.count("'")
        if quote_count % 2 != 0:
            in_quote = not in_quote

        if not in_quote and token.upper() in ('AND', 'OR'):
            if current.strip():
                parts.append({'condition': current.strip(), 'logical': logical})
            logical = token.upper()
            current = ''
        else:
            current += (' ' if current else '') + token

    if current.strip():
        parts.append({'condition': current.strip(), 'logical': logical})
    return parts


def _parse_single_condition(cond_str):
    """Parse a single WHERE condition into {field, operator, value}."""
    # IN operator
    in_match = re.match(r'^(\w+)\s+IN\s*\((.+)\)$', cond_str, re.IGNORECASE)
    if in_match:
        values = [v.strip().strip("'") for v in in_match.group(2).split(',')]
        return {'field': in_match.group(1), 'operator': 'IN', 'value': values}

    # NOT IN operator
    not_in_match = re.match(r'^(\w+)\s+NOT\s+IN\s*\((.+)\)$', cond_str, re.IGNORECASE)
    if not_in_match:
        values = [v.strip().strip("'") for v in not_in_match.group(2).split(',')]
        return {'field': not_in_match.group(1), 'operator': 'NOT IN', 'value': values}

    # LIKE operator
    like_match = re.match(r"^(\w+)\s+LIKE\s+'(.+)'$", cond_str, re.IGNORECASE)
    if like_match:
        return {'field': like_match.group(1), 'operator': 'LIKE', 'value': like_match.group(2)}

    # Comparison operators: =, !=, <>, >=, <=, >, <
    comp_match = re.match(r'^(\w+)\s*(!=|<>|>=|<=|>|<|=)\s*(.+)$', cond_str)
    if comp_match:
        value = comp_match.group(3).strip()
        # Auto-detect and convert value types
        if value.startswith("'") and value.endswith("'"):
            value = value[1:-1]  # String
        elif value.lower() == 'true':
            value = True
        elif value.lower() == 'false':
            value = False
        elif value.lower() == 'null':
            value = None
        else:
            try:
                value = float(value) if '.' in value else int(value)
            except ValueError:
                pass

        operator = '!=' if comp_match.group(2) == '<>' else comp_match.group(2)
        return {'field': comp_match.group(1), 'operator': operator, 'value': value}

    return None


# ═══════════════════════════════════════════════════════════════
# ORDER BY, LIMIT, OFFSET PARSERS
# ═══════════════════════════════════════════════════════════════

def _parse_order_by(soql, result):
    """Extract ORDER BY clause."""
    order_match = re.search(
        r'\bORDER\s+BY\s+(\w+)(?:\s+(ASC|DESC))?(?:\s+NULLS\s+(FIRST|LAST))?',
        soql, re.IGNORECASE
    )
    if order_match:
        result['order_by'] = {
            'field': order_match.group(1),
            'direction': (order_match.group(2) or 'ASC').upper(),
            'nulls': order_match.group(3).upper() if order_match.group(3) else None
        }


def _parse_limit(soql, result):
    """Extract LIMIT clause."""
    limit_match = re.search(r'\bLIMIT\s+(\d+)', soql, re.IGNORECASE)
    if limit_match:
        result['limit'] = int(limit_match.group(1))


def _parse_offset(soql, result):
    """Extract OFFSET clause."""
    offset_match = re.search(r'\bOFFSET\s+(\d+)', soql, re.IGNORECASE)
    if offset_match:
        result['offset'] = int(offset_match.group(1))


# ═══════════════════════════════════════════════════════════════
# QUERY EXECUTION HELPERS
# ═══════════════════════════════════════════════════════════════

def apply_where(records, conditions):
    """
    Filter records based on parsed WHERE conditions.
    Left-to-right evaluation (no operator precedence).
    """
    if not conditions:
        return records

    def matches(record):
        result = _evaluate_condition(record, conditions[0])
        for cond in conditions[1:]:
            cond_result = _evaluate_condition(record, cond)
            if cond.get('logical') == 'AND':
                result = result and cond_result
            elif cond.get('logical') == 'OR':
                result = result or cond_result
        return result

    return [r for r in records if matches(r)]


def _evaluate_condition(record, condition):
    """Evaluate a single condition against a record."""
    record_value = record.get(condition['field'])
    cond_value = condition['value']
    op = condition['operator']

    if op == '=':
        return str(record_value) == str(cond_value)
    elif op == '!=':
        return str(record_value) != str(cond_value)
    elif op == '>':
        try:
            return float(record_value) > float(cond_value)
        except (TypeError, ValueError):
            return False
    elif op == '>=':
        try:
            return float(record_value) >= float(cond_value)
        except (TypeError, ValueError):
            return False
    elif op == '<':
        try:
            return float(record_value) < float(cond_value)
        except (TypeError, ValueError):
            return False
    elif op == '<=':
        try:
            return float(record_value) <= float(cond_value)
        except (TypeError, ValueError):
            return False
    elif op == 'LIKE':
        if record_value is None:
            return False
        # Convert SOQL LIKE to regex: % -> .*, _ -> .
        # Step 1: Replace SOQL wildcards with unique placeholders
        # Step 2: re.escape the rest (makes literal chars safe for regex)
        # Step 3: Replace placeholders with regex equivalents
        value_str = str(cond_value)
        value_str = value_str.replace('%', '\x00WILDMULTI\x00').replace('_', '\x00WILDSINGLE\x00')
        pattern = re.escape(value_str)
        pattern = pattern.replace('\x00WILDMULTI\x00', '.*').replace('\x00WILDSINGLE\x00', '.')
        return bool(re.match(f'^{pattern}$', str(record_value), re.IGNORECASE))
    elif op == 'IN':
        return str(record_value) in cond_value
    elif op == 'NOT IN':
        return str(record_value) not in cond_value
    else:
        return True


def apply_order_by(records, order_by):
    """
    Sort records based on ORDER BY clause.
    Returns a new sorted list (does not mutate original).
    """
    if not order_by:
        return records

    field = order_by['field']
    descending = order_by['direction'] == 'DESC'
    nulls_first = order_by.get('nulls') == 'FIRST'

    def sort_key(record):
        val = record.get(field)
        if val is None:
            # Nulls: use a tuple to control position
            return (0 if nulls_first else 2, '')
        return (1, val)

    return sorted(records, key=sort_key, reverse=descending)
