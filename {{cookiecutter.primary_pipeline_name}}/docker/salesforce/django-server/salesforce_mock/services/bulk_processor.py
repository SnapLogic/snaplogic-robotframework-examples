"""
Bulk Processor
==============
Port of: lib/bulk/bulk-processor.js

Processes bulk ingest and query jobs against the in-memory database.

Ingest operations (insert/update/upsert/delete):
  - Parses CSV data into records
  - Processes each record independently
  - Tracks successful/failed results per record
  - Updates the in-memory database

Query operations:
  - Executes SOQL query via the shared soql_parser
  - Serializes results as CSV
  - Stores CSV in job['queryResults']

Both processors are SYNCHRONOUS -- they complete immediately when called.
SnapLogic's first poll sees the completed state.
"""
import csv
import io
import logging
from datetime import datetime, timezone

from salesforce_mock.state.database import schemas, database
from salesforce_mock.utils.id_generator import generate_id
from salesforce_mock.utils.validator import validate
from salesforce_mock.parsers.soql_parser import parse_soql, apply_where, apply_order_by

logger = logging.getLogger('salesforce_mock')


# =====================================================================
# INGEST PROCESSOR
# =====================================================================

def process_ingest_job(job):
    """
    Processes a bulk ingest job (insert, update, upsert, or delete).

    Parses the job's CSV data into records, then processes each record
    according to the job's operation type. Results are stored in
    job['successfulResults'] and job['failedResults'] lists.

    Each record is processed independently -- a failure in one record
    does not affect others (matching real Salesforce behavior).

    Args:
        job: The bulk job dict from job_store.

    Returns:
        The updated job dict with state, results, and counts.
    """
    schema = schemas.get(job['object'])
    if not schema:
        job['state'] = 'Failed'
        job['failedResults'] = []
        job['numberRecordsFailed'] = 0
        return job

    # Initialize database list if it doesn't exist for this object
    if job['object'] not in database:
        database[job['object']] = []

    collection = database[job['object']]

    # Parse CSV data using Python csv module
    csv_data = job.get('csvData', '')
    records = parse_csv(csv_data)

    job['state'] = 'InProgress'
    job['successfulResults'] = []
    job['failedResults'] = []
    job['numberRecordsProcessed'] = 0
    job['numberRecordsFailed'] = 0

    start_time = datetime.now(timezone.utc)

    for record in records:
        try:
            operation = job['operation']
            if operation == 'insert':
                _process_insert(record, schema, collection, job)
            elif operation == 'update':
                _process_update(record, schema, collection, job)
            elif operation == 'upsert':
                _process_upsert(record, schema, collection, job)
            elif operation == 'delete':
                _process_delete(record, collection, job)
            else:
                job['failedResults'].append({
                    'sf__Id': '',
                    'sf__Error': f'INVALID_OPERATION:Unsupported operation: {operation}',
                    **record,
                })
                job['numberRecordsFailed'] += 1
        except Exception as err:
            job['failedResults'].append({
                'sf__Id': record.get('Id', ''),
                'sf__Error': f'UNKNOWN_EXCEPTION:{str(err)}',
                **record,
            })
            job['numberRecordsFailed'] += 1

    elapsed = (datetime.now(timezone.utc) - start_time).total_seconds() * 1000
    job['totalProcessingTime'] = int(elapsed)

    if job['numberRecordsFailed'] > 0 and job['numberRecordsProcessed'] == 0:
        job['state'] = 'Failed'
    else:
        job['state'] = 'JobComplete'

    logger.info(
        "Bulk %s: %d success, %d failed for %s",
        job['operation'],
        job['numberRecordsProcessed'],
        job['numberRecordsFailed'],
        job['object'],
    )

    return job


# =====================================================================
# QUERY PROCESSOR
# =====================================================================

def process_query_job(job):
    """
    Process a bulk query job by executing its SOQL query against
    the in-memory database and storing results as CSV.

    Parses the job's SOQL query using the existing soql_parser module,
    executes it against the in-memory database, and serializes the results
    as CSV stored in job['queryResults'].

    Args:
        job: The bulk job dict from job_store.

    Returns:
        The updated job dict with state, queryResults, and counts.
    """
    try:
        parsed = parse_soql(job['query'])

        if not parsed['object'] or parsed['object'] not in schemas:
            job['state'] = 'Failed'
            job['numberRecordsFailed'] = 1
            return job

        # Set the object name on the job (extracted from SOQL)
        job['object'] = parsed['object']

        records = list(database.get(parsed['object'], []))

        # Apply WHERE filters
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

        # Determine which fields to include
        if '*' in parsed['fields']:
            # All fields - get from first record or schema
            if records:
                headers = [k for k in records[0].keys() if k != 'attributes']
            else:
                headers = ['Id'] + list(schemas[parsed['object']].get('fields', {}).keys())
        else:
            headers = parsed['fields']

        # Project only the selected fields
        projected = []
        for record in records:
            row = {}
            for field in headers:
                val = record.get(field)
                row[field] = val if val is not None else ''
            projected.append(row)

        # Serialize to CSV
        job['queryResults'] = to_csv(headers, projected)
        job['numberRecordsProcessed'] = len(projected)
        job['state'] = 'JobComplete'

        logger.info(
            "Bulk query: %d records from %s",
            len(projected),
            parsed['object'],
        )

    except Exception as exc:
        job['state'] = 'Failed'
        job['numberRecordsFailed'] = 1
        logger.error("Bulk query failed: %s", str(exc))

    return job


# =====================================================================
# Individual record operations (used by ingest processor)
# =====================================================================

def _process_insert(record, schema, collection, job):
    """
    Processes a single INSERT record from bulk CSV data.
    Validates, generates ID, and adds to the database.
    """
    errors = validate(record, schema, 'create')
    if len(errors) > 0:
        job['failedResults'].append({
            'sf__Id': '',
            'sf__Error': '; '.join(
                f"{e['errorCode']}:{e['message']}" for e in errors
            ),
            **record,
        })
        job['numberRecordsFailed'] += 1
        return

    record_id = generate_id(schema['idPrefix'])
    now = datetime.now(timezone.utc).isoformat()

    new_record = {
        'Id': record_id,
        **record,
        'CreatedDate': now,
        'LastModifiedDate': now,
        'SystemModstamp': now,
        'attributes': {'type': schema['name']},
    }

    collection.append(new_record)
    job['successfulResults'].append({'sf__Id': record_id, 'sf__Created': 'true', **record})
    job['numberRecordsProcessed'] += 1


def _process_update(record, schema, collection, job):
    """
    Processes a single UPDATE record from bulk CSV data.
    Finds existing record by Id, validates, and merges changes.
    """
    record_id = record.get('Id', '')
    if not record_id:
        job['failedResults'].append({
            'sf__Id': '',
            'sf__Error': 'MISSING_ARGUMENT:Id is required for update operation',
            **record,
        })
        job['numberRecordsFailed'] += 1
        return

    index = None
    for i, r in enumerate(collection):
        if r.get('Id') == record_id:
            index = i
            break

    if index is None:
        job['failedResults'].append({
            'sf__Id': record_id,
            'sf__Error': f'INVALID_CROSS_REFERENCE_KEY:Record not found: {record_id}',
            **record,
        })
        job['numberRecordsFailed'] += 1
        return

    # Validate fields (without required check -- it's an update)
    update_fields = {k: v for k, v in record.items() if k != 'Id'}
    errors = validate(update_fields, schema, 'update')
    if len(errors) > 0:
        job['failedResults'].append({
            'sf__Id': record_id,
            'sf__Error': '; '.join(
                f"{e['errorCode']}:{e['message']}" for e in errors
            ),
            **record,
        })
        job['numberRecordsFailed'] += 1
        return

    now = datetime.now(timezone.utc).isoformat()
    collection[index].update(update_fields)
    collection[index]['LastModifiedDate'] = now
    collection[index]['SystemModstamp'] = now

    job['successfulResults'].append({'sf__Id': record_id, 'sf__Created': 'false', **record})
    job['numberRecordsProcessed'] += 1


def _process_upsert(record, schema, collection, job):
    """
    Processes a single UPSERT record from bulk CSV data.
    Finds by external ID field -- updates if found, inserts if not.
    """
    ext_id_field = job.get('externalIdFieldName') or 'Id'
    ext_id_value = record.get(ext_id_field, '')

    if not ext_id_value:
        # No external ID value -- treat as insert
        _process_insert(record, schema, collection, job)
        return

    existing_index = None
    for i, r in enumerate(collection):
        if str(r.get(ext_id_field, '')) == str(ext_id_value):
            existing_index = i
            break

    if existing_index is not None:
        # Found -- update existing record
        update_fields = {k: v for k, v in record.items() if k != ext_id_field}
        now = datetime.now(timezone.utc).isoformat()
        collection[existing_index].update(update_fields)
        collection[existing_index]['LastModifiedDate'] = now
        collection[existing_index]['SystemModstamp'] = now

        job['successfulResults'].append({
            'sf__Id': collection[existing_index]['Id'],
            'sf__Created': 'false',
            **record,
        })
        job['numberRecordsProcessed'] += 1
    else:
        # Not found -- insert new record
        _process_insert(record, schema, collection, job)


def _process_delete(record, collection, job):
    """
    Processes a single DELETE record from bulk CSV data.
    Finds by Id and removes from the database.
    """
    record_id = record.get('Id', '')
    if not record_id:
        job['failedResults'].append({
            'sf__Id': '',
            'sf__Error': 'MISSING_ARGUMENT:Id is required for delete operation',
            **record,
        })
        job['numberRecordsFailed'] += 1
        return

    index = None
    for i, r in enumerate(collection):
        if r.get('Id') == record_id:
            index = i
            break

    if index is None:
        job['failedResults'].append({
            'sf__Id': record_id,
            'sf__Error': f'ENTITY_IS_DELETED:Entity is deleted or does not exist: {record_id}',
            **record,
        })
        job['numberRecordsFailed'] += 1
        return

    collection.pop(index)
    job['successfulResults'].append({'sf__Id': record_id, 'sf__Created': 'false'})
    job['numberRecordsProcessed'] += 1


# =====================================================================
# CSV Utilities (port of lib/bulk/csv-parser.js)
# =====================================================================

def parse_csv(csv_string):
    """
    Parse a CSV string into a list of dicts using Python's csv.DictReader.

    The first row is treated as headers (field names).
    Each subsequent row becomes a dict with header names as keys.
    Empty rows are skipped.

    Args:
        csv_string: Raw CSV text with header row.

    Returns:
        List of dicts, one per data row.
    """
    if not csv_string or not csv_string.strip():
        return []

    reader = csv.DictReader(io.StringIO(csv_string.strip()))
    records = []
    for row in reader:
        # Skip completely empty rows
        if any(v for v in row.values()):
            records.append(dict(row))
    return records


def to_csv(headers, records):
    """
    Serialize a list of dicts to a CSV string using Python's csv module.

    The first row will be the headers, followed by one row per record.
    Values containing commas, quotes, or newlines are automatically quoted.

    Args:
        headers: List of column header strings.
        records: List of dicts, each representing a row.

    Returns:
        CSV string with header row and data rows.
    """
    output = io.StringIO()
    writer = csv.writer(output)
    writer.writerow(headers)
    for record in records:
        writer.writerow([record.get(h, '') for h in headers])
    return output.getvalue()


def get_csv_headers(csv_string):
    """
    Get the first line (header row) of a CSV string without parsing
    the entire file. Useful for validating multi-batch uploads have
    matching headers.

    Args:
        csv_string: Raw CSV text.

    Returns:
        The first line (header row) as a string.
    """
    if not csv_string:
        return ''
    first_newline = csv_string.find('\n')
    if first_newline == -1:
        return csv_string.strip()
    return csv_string[:first_newline].strip()
