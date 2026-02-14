"""
Salesforce Bulk API v1 Views
=============================
Port of: lib/routes/bulk-v1-routes.js

Django function-based views for the legacy Salesforce Bulk API v1 (XML-based).
This is the original Bulk API that uses XML format and lives under /services/async/.

It is DIFFERENT from Bulk API 2.0 (which uses JSON + CSV and lives under
/services/data/:version/jobs/...).

URL pattern: /services/async/{version}/job[/...]
XML Namespace: http://www.force.com/2009/06/asyncapi/dataload

Views:
  create_v1_job         - POST   /services/async/:version/job
  add_v1_batch          - POST   /services/async/:version/job/:jobId/batch
  close_abort_v1_job    - POST   /services/async/:version/job/:jobId
  get_v1_job            - GET    /services/async/:version/job/:jobId
  list_v1_batches       - GET    /services/async/:version/job/:jobId/batch
  get_v1_batch          - GET    /services/async/:version/job/:jobId/batch/:batchId
  get_v1_batch_results  - GET    /services/async/:version/job/:jobId/batch/:batchId/result

Job States: Open, Closed, Aborted, Failed
Batch States: Queued, InProgress, Completed, Failed, Not Processed

Processing is SYNCHRONOUS -- batches complete immediately when added.
"""

import json
import csv
import io
import re
import xml.etree.ElementTree as ET
from datetime import datetime, timezone

from django.http import HttpResponse, JsonResponse
from django.views.decorators.csrf import csrf_exempt

from salesforce_mock.state.database import schemas, database
from salesforce_mock.utils.id_generator import generate_id
from salesforce_mock.utils.validator import validate
from salesforce_mock.state.job_store import job_store


# XML namespace for Bulk API v1
NS = 'http://www.force.com/2009/06/asyncapi/dataload'


# =====================================================================
# XML / CSV HELPERS (zero-dependency)
# =====================================================================

def _xml_get(xml_str, tag):
    """
    Extract a value from an XML element using regex.
    Works with both <tag>value</tag> and <ns:tag>value</ns:tag>.

    Args:
        xml_str: XML string to search
        tag: Element name to extract

    Returns:
        Element text content (stripped), or None if not found
    """
    match = re.search(
        rf'<(?:[a-zA-Z0-9_]+:)?{tag}[^>]*>([^<]*)</(?:[a-zA-Z0-9_]+:)?{tag}>',
        xml_str,
        re.IGNORECASE,
    )
    return match.group(1).strip() if match else None


def _escape_xml(s):
    """Escape special XML characters."""
    return (
        str(s)
        .replace('&', '&amp;')
        .replace('<', '&lt;')
        .replace('>', '&gt;')
        .replace('"', '&quot;')
        .replace("'", '&apos;')
    )


def _escape_csv_field(s):
    """Escape a CSV field value (double quotes inside the value)."""
    return str(s).replace('"', '""')


def _job_info_xml(job):
    """
    Build a <jobInfo> XML response string.

    Args:
        job: Job dict from the job store

    Returns:
        Complete XML string for the jobInfo response
    """
    return (
        '<?xml version="1.0" encoding="UTF-8"?>\n'
        f'<jobInfo xmlns="{NS}">\n'
        f'  <id>{job["id"]}</id>\n'
        f'  <operation>{job["operation"]}</operation>\n'
        f'  <object>{job["object"]}</object>\n'
        f'  <createdById>{job.get("createdById", "005000000000000AAA")}</createdById>\n'
        f'  <createdDate>{job["createdDate"]}</createdDate>\n'
        f'  <systemModstamp>{job["systemModstamp"]}</systemModstamp>\n'
        f'  <state>{job.get("v1State", "Open")}</state>\n'
        f'  <externalIdFieldName>{job.get("externalIdFieldName") or ""}</externalIdFieldName>\n'
        f'  <concurrencyMode>{job.get("concurrencyMode", "Parallel")}</concurrencyMode>\n'
        f'  <contentType>{job.get("contentType", "CSV")}</contentType>\n'
        f'  <numberBatchesQueued>{job.get("numberBatchesQueued", 0)}</numberBatchesQueued>\n'
        f'  <numberBatchesInProgress>{job.get("numberBatchesInProgress", 0)}</numberBatchesInProgress>\n'
        f'  <numberBatchesCompleted>{job.get("numberBatchesCompleted", 0)}</numberBatchesCompleted>\n'
        f'  <numberBatchesFailed>{job.get("numberBatchesFailed", 0)}</numberBatchesFailed>\n'
        f'  <numberBatchesTotal>{job.get("numberBatchesTotal", 0)}</numberBatchesTotal>\n'
        f'  <numberRecordsProcessed>{job.get("numberRecordsProcessed", 0)}</numberRecordsProcessed>\n'
        f'  <numberRetries>{job.get("retries", 0)}</numberRetries>\n'
        f'  <apiVersion>{job.get("apiVersion", 52.0)}</apiVersion>\n'
        f'  <numberRecordsFailed>{job.get("numberRecordsFailed", 0)}</numberRecordsFailed>\n'
        f'  <totalProcessingTime>{job.get("totalProcessingTime", 0)}</totalProcessingTime>\n'
        f'  <apiActiveProcessingTime>{job.get("apiActiveProcessingTime", 0)}</apiActiveProcessingTime>\n'
        f'  <apexProcessingTime>{job.get("apexProcessingTime", 0)}</apexProcessingTime>\n'
        '</jobInfo>'
    )


def _batch_info_xml(batch):
    """
    Build a <batchInfo> XML response string.

    Args:
        batch: Batch dict

    Returns:
        Complete XML string for the batchInfo response
    """
    return (
        '<?xml version="1.0" encoding="UTF-8"?>\n'
        f'<batchInfo xmlns="{NS}">\n'
        f'  <id>{batch["id"]}</id>\n'
        f'  <jobId>{batch["jobId"]}</jobId>\n'
        f'  <state>{batch["state"]}</state>\n'
        f'  <createdDate>{batch["createdDate"]}</createdDate>\n'
        f'  <systemModstamp>{batch["systemModstamp"]}</systemModstamp>\n'
        f'  <numberRecordsProcessed>{batch.get("numberRecordsProcessed", 0)}</numberRecordsProcessed>\n'
        f'  <numberRecordsFailed>{batch.get("numberRecordsFailed", 0)}</numberRecordsFailed>\n'
        f'  <totalProcessingTime>{batch.get("totalProcessingTime", 0)}</totalProcessingTime>\n'
        f'  <apiActiveProcessingTime>{batch.get("apiActiveProcessingTime", 0)}</apiActiveProcessingTime>\n'
        f'  <apexProcessingTime>{batch.get("apexProcessingTime", 0)}</apexProcessingTime>\n'
        '</batchInfo>'
    )


def _error_xml(code, message):
    """
    Build an XML error response.

    Args:
        code: Error code string
        message: Error message string

    Returns:
        Complete XML string for the error response
    """
    return (
        '<?xml version="1.0" encoding="UTF-8"?>\n'
        f'<error xmlns="{NS}">\n'
        f'  <exceptionCode>{code}</exceptionCode>\n'
        f'  <exceptionMessage>{_escape_xml(message)}</exceptionMessage>\n'
        '</error>'
    )


def _results_xml(results):
    """
    Build batch results XML for insert/update/upsert/delete operations.

    Each result has id, success, created, and optional errors.

    Args:
        results: List of dicts with id, success, created, errorCode, errorMessage

    Returns:
        Complete XML string for the results response
    """
    items = []
    for r in results:
        if r.get('success'):
            items.append(
                '  <result>\n'
                f'    <id>{r.get("id", "")}</id>\n'
                '    <success>true</success>\n'
                f'    <created>{"true" if r.get("created") else "false"}</created>\n'
                '  </result>'
            )
        else:
            items.append(
                '  <result>\n'
                '    <id xsi:nil="true" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"/>\n'
                '    <success>false</success>\n'
                '    <created>false</created>\n'
                '    <errors>\n'
                f'      <message>{_escape_xml(r.get("errorMessage", "Unknown error"))}</message>\n'
                f'      <statusCode>{r.get("errorCode", "UNKNOWN_EXCEPTION")}</statusCode>\n'
                '    </errors>\n'
                '  </result>'
            )

    joined = '\n'.join(items)
    return (
        '<?xml version="1.0" encoding="UTF-8"?>\n'
        f'<results xmlns="{NS}">\n'
        f'{joined}\n'
        '</results>'
    )


def _results_csv(results):
    """
    Build batch results as CSV.
    Real Salesforce returns: "Id","Success","Created","Error"

    Args:
        results: List of dicts with id, success, created, errorMessage

    Returns:
        CSV string
    """
    rows = ['"Id","Success","Created","Error"']
    for r in results:
        rid = r.get('id') or ''
        success = 'true' if r.get('success') else 'false'
        created = 'true' if r.get('created') else 'false'
        error = r.get('errorMessage') or ''
        rows.append(f'"{rid}","{success}","{created}","{_escape_csv_field(error)}"')
    return '\n'.join(rows)


def _parse_xml_sobjects(xml_str):
    """
    Parse <sObjects><sObject>...</sObject></sObjects> XML into a list of dicts.
    Simple regex-based parser (no external XML library needed).

    Args:
        xml_str: XML string with <sObjects> wrapper

    Returns:
        List of record dicts
    """
    records = []
    # Match each <sObject>...</sObject> block
    sobject_regex = re.compile(r'<sObject[^>]*>([\s\S]*?)</sObject>', re.IGNORECASE)

    for match in sobject_regex.finditer(xml_str):
        block = match.group(1)
        record = {}
        # Match each field: <FieldName>value</FieldName>
        field_regex = re.compile(r'<([a-zA-Z_][a-zA-Z0-9_]*)>([^<]*)</\1>')
        for field_match in field_regex.finditer(block):
            record[field_match.group(1)] = field_match.group(2).strip()
        if record:
            records.append(record)

    return records


def _parse_csv_records(csv_str):
    """
    Parse CSV string into a list of dicts using Python csv.DictReader.

    Args:
        csv_str: CSV string with header row

    Returns:
        List of record dicts
    """
    reader = csv.DictReader(io.StringIO(csv_str))
    return [dict(row) for row in reader]


# =====================================================================
# VIEW FUNCTIONS
# =====================================================================

@csrf_exempt
def create_v1_job(request, version):
    """
    POST /services/async/:version/job

    Creates a new Bulk API v1 job. Accepts XML body with operation, object, contentType.
    """
    xml = request.body.decode('utf-8') if request.body else ''
    operation = _xml_get(xml, 'operation')
    obj = _xml_get(xml, 'object')
    content_type = _xml_get(xml, 'contentType') or 'CSV'
    external_id_field = _xml_get(xml, 'externalIdFieldName')

    if not operation:
        return HttpResponse(
            _error_xml('InvalidJob', 'operation is required'),
            status=400,
            content_type='application/xml',
        )

    if not obj:
        return HttpResponse(
            _error_xml('InvalidJob', 'object is required'),
            status=400,
            content_type='application/xml',
        )

    if obj not in schemas:
        return HttpResponse(
            _error_xml('InvalidJob', f"sObject type '{obj}' is not supported."),
            status=400,
            content_type='application/xml',
        )

    job = job_store.create({
        'object': obj,
        'operation': operation,
        'jobType': 'V1Bulk',
        'contentType': content_type,
        'externalIdFieldName': external_id_field or '',
    })

    # Add v1-specific fields
    try:
        api_version = float(version)
    except (ValueError, TypeError):
        api_version = 52.0

    job_store.update(job['id'], {
        'v1State': 'Open',
        'apiVersion': api_version,
        'batches': [],
        'numberBatchesQueued': 0,
        'numberBatchesInProgress': 0,
        'numberBatchesCompleted': 0,
        'numberBatchesFailed': 0,
        'numberBatchesTotal': 0,
        'apiActiveProcessingTime': 0,
        'apexProcessingTime': 0,
    })

    print(f'  Bulk v1: Created {operation} job {job["id"]} for {obj} ({content_type})')

    return HttpResponse(
        _job_info_xml(job_store.get(job['id'])),
        status=201,
        content_type='application/xml',
    )


@csrf_exempt
def add_v1_batch(request, version, job_id):
    """
    POST /services/async/:version/job/:jobId/batch

    Adds a batch of data to an open job. Data format depends on job's contentType.
    For CSV: raw CSV text. For XML: <sObjects> wrapper. For JSON: array or object.
    Processing is synchronous -- batch completes immediately.
    """
    job = job_store.get(job_id)

    if not job:
        return HttpResponse(
            _error_xml('InvalidJob', f'Job not found: {job_id}'),
            status=404,
            content_type='application/xml',
        )

    if job.get('v1State') != 'Open':
        return HttpResponse(
            _error_xml(
                'InvalidJobState',
                f'Job {job["id"]} is not open. Current state: {job.get("v1State")}',
            ),
            status=400,
            content_type='application/xml',
        )

    raw_data = request.body.decode('utf-8') if request.body else ''
    schema = schemas.get(job['object'])
    batch_id = generate_id('751')
    now = datetime.now(timezone.utc).isoformat().replace('+00:00', 'Z')

    # Parse the batch data
    records = []
    try:
        ct = job.get('contentType', 'CSV')
        if ct in ('CSV', 'ZIP_CSV'):
            records = _parse_csv_records(raw_data)
        elif ct in ('XML', 'ZIP_XML'):
            records = _parse_xml_sobjects(raw_data)
        elif ct in ('JSON', 'ZIP_JSON'):
            parsed = json.loads(raw_data)
            records = parsed if isinstance(parsed, list) else [parsed]
    except Exception as err:
        # Batch failed to parse
        batch = {
            'id': batch_id,
            'jobId': job['id'],
            'state': 'Failed',
            'stateMessage': f'Failed to parse batch data: {err}',
            'createdDate': now,
            'systemModstamp': now,
            'numberRecordsProcessed': 0,
            'numberRecordsFailed': 0,
            'totalProcessingTime': 0,
            'apiActiveProcessingTime': 0,
            'apexProcessingTime': 0,
            'results': [],
        }

        job['batches'].append(batch)
        job_store.update(job['id'], {
            'numberBatchesFailed': (job.get('numberBatchesFailed') or 0) + 1,
            'numberBatchesTotal': (job.get('numberBatchesTotal') or 0) + 1,
        })

        print(f'  Bulk v1: Batch {batch_id} failed to parse: {err}')
        return HttpResponse(
            _batch_info_xml(batch),
            status=201,
            content_type='application/xml',
        )

    # Process the records synchronously
    results = []
    processed = 0
    failed = 0

    for record in records:
        try:
            if job['operation'] == 'insert':
                errors = validate(record, schema, 'create')
                if errors:
                    results.append({
                        'success': False,
                        'created': False,
                        'errorCode': errors[0].get('errorCode', 'VALIDATION_ERROR'),
                        'errorMessage': errors[0].get('message', 'Validation failed'),
                    })
                    failed += 1
                else:
                    rec_id = generate_id(schema['idPrefix'])
                    new_record = {
                        'Id': rec_id,
                        **record,
                        'CreatedDate': now,
                        'LastModifiedDate': now,
                        'SystemModstamp': now,
                        'attributes': {
                            'type': job['object'],
                            'url': f'/services/data/v{job.get("apiVersion", 52.0)}/sobjects/{job["object"]}/{rec_id}',
                        },
                    }
                    database[job['object']].append(new_record)
                    results.append({'id': rec_id, 'success': True, 'created': True})

            elif job['operation'] == 'update':
                record_id = record.get('Id') or record.get('id')
                if not record_id:
                    results.append({
                        'success': False,
                        'created': False,
                        'errorCode': 'MISSING_ARGUMENT',
                        'errorMessage': 'Id field is required for update',
                    })
                    failed += 1
                    processed += 1
                    continue

                existing = None
                for r in database.get(job['object'], []):
                    if r.get('Id') == record_id:
                        existing = r
                        break

                if not existing:
                    results.append({
                        'success': False,
                        'created': False,
                        'errorCode': 'ENTITY_IS_DELETED',
                        'errorMessage': f'Record not found: {record_id}',
                    })
                    failed += 1
                else:
                    update_data = {k: v for k, v in record.items() if k not in ('Id', 'id')}
                    existing.update(update_data)
                    existing['LastModifiedDate'] = now
                    existing['SystemModstamp'] = now
                    results.append({'id': record_id, 'success': True, 'created': False})

            elif job['operation'] == 'upsert':
                ext_field = job.get('externalIdFieldName') or 'Id'
                ext_value = record.get(ext_field)
                existing = None
                for r in database.get(job['object'], []):
                    if str(r.get(ext_field, '')) == str(ext_value):
                        existing = r
                        break

                if existing:
                    update_data = {k: v for k, v in record.items() if k != ext_field}
                    existing.update(update_data)
                    existing['LastModifiedDate'] = now
                    existing['SystemModstamp'] = now
                    results.append({'id': existing['Id'], 'success': True, 'created': False})
                else:
                    errors = validate(record, schema, 'create')
                    if errors:
                        results.append({
                            'success': False,
                            'created': False,
                            'errorCode': errors[0].get('errorCode', 'VALIDATION_ERROR'),
                            'errorMessage': errors[0].get('message', 'Validation failed'),
                        })
                        failed += 1
                    else:
                        rec_id = generate_id(schema['idPrefix'])
                        new_record = {
                            'Id': rec_id,
                            **record,
                            'CreatedDate': now,
                            'LastModifiedDate': now,
                            'SystemModstamp': now,
                            'attributes': {
                                'type': job['object'],
                                'url': f'/services/data/v{job.get("apiVersion", 52.0)}/sobjects/{job["object"]}/{rec_id}',
                            },
                        }
                        database[job['object']].append(new_record)
                        results.append({'id': rec_id, 'success': True, 'created': True})

            elif job['operation'] == 'delete':
                record_id = record.get('Id') or record.get('id')
                if not record_id:
                    results.append({
                        'success': False,
                        'created': False,
                        'errorCode': 'MISSING_ARGUMENT',
                        'errorMessage': 'Id field is required for delete',
                    })
                    failed += 1
                    processed += 1
                    continue

                db_records = database.get(job['object'], [])
                idx = None
                for i, r in enumerate(db_records):
                    if r.get('Id') == record_id:
                        idx = i
                        break

                if idx is None:
                    results.append({
                        'success': False,
                        'created': False,
                        'errorCode': 'ENTITY_IS_DELETED',
                        'errorMessage': f'Record not found: {record_id}',
                    })
                    failed += 1
                else:
                    db_records.pop(idx)
                    results.append({'id': record_id, 'success': True, 'created': False})

            processed += 1

        except Exception as err:
            results.append({
                'success': False,
                'created': False,
                'errorCode': 'UNKNOWN_EXCEPTION',
                'errorMessage': str(err),
            })
            failed += 1
            processed += 1

    # Build batch result
    batch = {
        'id': batch_id,
        'jobId': job['id'],
        'state': 'Failed' if failed == len(records) else 'Completed',
        'createdDate': now,
        'systemModstamp': now,
        'numberRecordsProcessed': processed,
        'numberRecordsFailed': failed,
        'totalProcessingTime': 10,
        'apiActiveProcessingTime': 5,
        'apexProcessingTime': 2,
        'results': results,
    }

    job['batches'].append(batch)
    job_store.update(job['id'], {
        'numberBatchesCompleted': (job.get('numberBatchesCompleted') or 0) + (1 if batch['state'] == 'Completed' else 0),
        'numberBatchesFailed': (job.get('numberBatchesFailed') or 0) + (1 if batch['state'] == 'Failed' else 0),
        'numberBatchesTotal': (job.get('numberBatchesTotal') or 0) + 1,
        'numberRecordsProcessed': (job.get('numberRecordsProcessed') or 0) + processed,
        'numberRecordsFailed': (job.get('numberRecordsFailed') or 0) + failed,
    })

    print(f'  Bulk v1: Batch {batch_id} -- {processed} processed, {failed} failed ({job["operation"]} {job["object"]})')

    return HttpResponse(
        _batch_info_xml(batch),
        status=201,
        content_type='application/xml',
    )


@csrf_exempt
def close_abort_v1_job(request, version, job_id):
    """
    POST /services/async/:version/job/:jobId

    Closes or aborts a job. Accepts XML body with <state>Closed</state>
    or <state>Aborted</state>.
    """
    job = job_store.get(job_id)

    if not job:
        return HttpResponse(
            _error_xml('InvalidJob', f'Job not found: {job_id}'),
            status=404,
            content_type='application/xml',
        )

    xml = request.body.decode('utf-8') if request.body else ''
    new_state = _xml_get(xml, 'state')

    if new_state == 'Closed':
        job_store.update(job['id'], {'v1State': 'Closed'})
        print(f'  Bulk v1: Job {job["id"]} closed')
    elif new_state == 'Aborted':
        job_store.update(job['id'], {'v1State': 'Aborted'})
        # Mark queued/in-progress batches as "Not Processed"
        for batch in (job.get('batches') or []):
            if batch['state'] in ('Queued', 'InProgress'):
                batch['state'] = 'Not Processed'
        print(f'  Bulk v1: Job {job["id"]} aborted')
    else:
        return HttpResponse(
            _error_xml(
                'InvalidJobState',
                f"Invalid state: {new_state}. Use 'Closed' or 'Aborted'.",
            ),
            status=400,
            content_type='application/xml',
        )

    return HttpResponse(
        _job_info_xml(job_store.get(job['id'])),
        content_type='application/xml',
    )


def get_v1_job(request, version, job_id):
    """
    GET /services/async/:version/job/:jobId

    Returns job status and metadata as XML.
    """
    job = job_store.get(job_id)

    if not job:
        return HttpResponse(
            _error_xml('InvalidJob', f'Job not found: {job_id}'),
            status=404,
            content_type='application/xml',
        )

    return HttpResponse(
        _job_info_xml(job),
        content_type='application/xml',
    )


def list_v1_batches(request, version, job_id):
    """
    GET /services/async/:version/job/:jobId/batch

    Returns all batches for a job as XML batchInfoList.
    """
    job = job_store.get(job_id)

    if not job:
        return HttpResponse(
            _error_xml('InvalidJob', f'Job not found: {job_id}'),
            status=404,
            content_type='application/xml',
        )

    batch_items = []
    for b in (job.get('batches') or []):
        batch_items.append(
            '  <batchInfo>\n'
            f'    <id>{b["id"]}</id>\n'
            f'    <jobId>{b["jobId"]}</jobId>\n'
            f'    <state>{b["state"]}</state>\n'
            f'    <createdDate>{b["createdDate"]}</createdDate>\n'
            f'    <systemModstamp>{b["systemModstamp"]}</systemModstamp>\n'
            f'    <numberRecordsProcessed>{b.get("numberRecordsProcessed", 0)}</numberRecordsProcessed>\n'
            f'    <numberRecordsFailed>{b.get("numberRecordsFailed", 0)}</numberRecordsFailed>\n'
            f'    <totalProcessingTime>{b.get("totalProcessingTime", 0)}</totalProcessingTime>\n'
            f'    <apiActiveProcessingTime>{b.get("apiActiveProcessingTime", 0)}</apiActiveProcessingTime>\n'
            f'    <apexProcessingTime>{b.get("apexProcessingTime", 0)}</apexProcessingTime>\n'
            '  </batchInfo>'
        )

    batches_xml = '\n'.join(batch_items)
    body = (
        '<?xml version="1.0" encoding="UTF-8"?>\n'
        f'<batchInfoList xmlns="{NS}">\n'
        f'{batches_xml}\n'
        '</batchInfoList>'
    )

    return HttpResponse(body, content_type='application/xml')


def get_v1_batch(request, version, job_id, batch_id):
    """
    GET /services/async/:version/job/:jobId/batch/:batchId

    Returns status of a specific batch as XML.
    """
    job = job_store.get(job_id)

    if not job:
        return HttpResponse(
            _error_xml('InvalidJob', f'Job not found: {job_id}'),
            status=404,
            content_type='application/xml',
        )

    batch = None
    for b in (job.get('batches') or []):
        if b['id'] == batch_id:
            batch = b
            break

    if not batch:
        return HttpResponse(
            _error_xml('InvalidBatch', f'Batch not found: {batch_id}'),
            status=404,
            content_type='application/xml',
        )

    return HttpResponse(
        _batch_info_xml(batch),
        content_type='application/xml',
    )


def get_v1_batch_results(request, version, job_id, batch_id):
    """
    GET /services/async/:version/job/:jobId/batch/:batchId/result

    Returns results for a completed or failed batch.
    Format matches the job's contentType (CSV or XML).
    """
    job = job_store.get(job_id)

    if not job:
        return HttpResponse(
            _error_xml('InvalidJob', f'Job not found: {job_id}'),
            status=404,
            content_type='application/xml',
        )

    batch = None
    for b in (job.get('batches') or []):
        if b['id'] == batch_id:
            batch = b
            break

    if not batch:
        return HttpResponse(
            _error_xml('InvalidBatch', f'Batch not found: {batch_id}'),
            status=404,
            content_type='application/xml',
        )

    if batch['state'] not in ('Completed', 'Failed'):
        return HttpResponse(
            _error_xml(
                'InvalidBatchState',
                f'Batch {batch["id"]} is not complete. State: {batch["state"]}',
            ),
            status=400,
            content_type='application/xml',
        )

    # Return results in the format matching the job's contentType
    ct = job.get('contentType', 'XML')
    if ct in ('CSV', 'ZIP_CSV'):
        return HttpResponse(
            _results_csv(batch.get('results') or []),
            content_type='text/csv',
        )
    else:
        return HttpResponse(
            _results_xml(batch.get('results') or []),
            content_type='application/xml',
        )


# =====================================================================
# METHOD DISPATCHERS (for Django URL routing)
# =====================================================================

@csrf_exempt
def v1_job_handler(request, version, job_id):
    """Dispatch GET/POST for /services/async/:version/job/:jobId."""
    if request.method == 'GET':
        return get_v1_job(request, version, job_id)
    elif request.method == 'POST':
        return close_abort_v1_job(request, version, job_id)
    else:
        return HttpResponse(
            _error_xml('MethodNotAllowed', f'{request.method} not allowed'),
            status=405, content_type='application/xml',
        )


@csrf_exempt
def v1_batch_handler(request, version, job_id):
    """Dispatch GET/POST for /services/async/:version/job/:jobId/batch."""
    if request.method == 'GET':
        return list_v1_batches(request, version, job_id)
    elif request.method == 'POST':
        return add_v1_batch(request, version, job_id)
    else:
        return HttpResponse(
            _error_xml('MethodNotAllowed', f'{request.method} not allowed'),
            status=405, content_type='application/xml',
        )
