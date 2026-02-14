"""
Salesforce Bulk API 2.0 -- Ingest (Write) Views
=================================================
Port of: lib/routes/bulk-v2-ingest-routes.js

Django function-based views for bulk write operations: insert, update, upsert, delete.
Uses CSV format for data upload/download (not JSON like REST API).

Bulk API 2.0 Ingest Job Lifecycle:
  1. POST   .../jobs/ingest           -> Create job (state: Open)
  2. PUT    .../jobs/ingest/:id/batches -> Upload CSV data
  3. PATCH  .../jobs/ingest/:id       -> Close job (state: UploadComplete -> JobComplete)
  4. GET    .../jobs/ingest/:id       -> Poll status (state: JobComplete)
  5. GET    .../jobs/ingest/:id/successfulResults -> Download success CSV
  6. GET    .../jobs/ingest/:id/failedResults     -> Download failure CSV

Processing is SYNCHRONOUS in this mock server -- when the job state changes
to UploadComplete, records are processed immediately and the state goes
directly to JobComplete. SnapLogic's first poll will see the completed state.

Views:
  create_ingest_job       - POST   .../jobs/ingest
  upload_csv_data         - PUT    .../jobs/ingest/<jobId>/batches
  close_abort_job         - PATCH  .../jobs/ingest/<jobId>
  get_ingest_job          - GET    .../jobs/ingest/<jobId>
  get_successful_results  - GET    .../jobs/ingest/<jobId>/successfulResults
  get_failed_results      - GET    .../jobs/ingest/<jobId>/failedResults
  get_unprocessed_records - GET    .../jobs/ingest/<jobId>/unprocessedrecords
  delete_ingest_job       - DELETE .../jobs/ingest/<jobId>
  list_ingest_jobs        - GET    .../jobs/ingest
"""

import json

from django.http import JsonResponse, HttpResponse
from django.views.decorators.csrf import csrf_exempt

from salesforce_mock.state.database import schemas
from salesforce_mock.utils.error_formatter import format_error
from salesforce_mock.state.job_store import job_store
from salesforce_mock.services.bulk_processor import (
    process_ingest_job, to_csv, get_csv_headers,
)


# =====================================================================
# CREATE BULK INGEST JOB
# =====================================================================

@csrf_exempt
def create_ingest_job(request, version):
    """
    POST /services/data/<version>/jobs/ingest

    Creates a new bulk ingest job. The job starts in 'Open' state,
    ready to receive CSV data via PUT .../batches.

    Requires 'object' and a valid 'operation' (insert/update/upsert/delete).
    Upsert operations additionally require 'externalIdFieldName'.
    """
    try:
        body = json.loads(request.body) if request.body else {}
    except (json.JSONDecodeError, ValueError):
        return JsonResponse(
            format_error('INVALID_FIELD', 'Invalid JSON in request body'),
            status=400,
            safe=False,
        )

    obj = body.get('object')
    operation = body.get('operation')
    external_id_field_name = body.get('externalIdFieldName')
    content_type = body.get('contentType')
    line_ending = body.get('lineEnding')

    if not obj:
        return JsonResponse(
            format_error('INVALID_FIELD', 'object is required'),
            status=400,
            safe=False,
        )

    if obj not in schemas:
        return JsonResponse(
            format_error('INVALID_TYPE', f"sObject type '{obj}' is not supported."),
            status=400,
            safe=False,
        )

    valid_ops = ['insert', 'update', 'upsert', 'delete']
    if not operation or operation not in valid_ops:
        return JsonResponse(
            format_error('INVALID_FIELD',
                         f"operation must be one of: {', '.join(valid_ops)}"),
            status=400,
            safe=False,
        )

    if operation == 'upsert' and not external_id_field_name:
        return JsonResponse(
            format_error('INVALID_FIELD',
                         'externalIdFieldName is required for upsert operation'),
            status=400,
            safe=False,
        )

    job = job_store.create({
        'object': obj,
        'operation': operation,
        'externalIdFieldName': external_id_field_name,
        'contentType': content_type,
        'lineEnding': line_ending,
        'jobType': 'V2Ingest',
    })

    print(f'  Bulk ingest job created: {job["id"]} ({operation} {obj})')
    return JsonResponse(_format_job_response(job), status=201)


# =====================================================================
# UPLOAD CSV DATA (BATCHES)
# =====================================================================

@csrf_exempt
def upload_csv_data(request, version, job_id):
    """
    PUT /services/data/<version>/jobs/ingest/<job_id>/batches

    Uploads CSV data to an open bulk job. Can be called multiple times
    to upload data in chunks.

    On multi-batch uploads, duplicate header rows are automatically stripped.
    """
    job = job_store.get(job_id)
    if not job:
        return JsonResponse(
            format_error('NOT_FOUND', 'Job not found'),
            status=404,
            safe=False,
        )

    if job['state'] != 'Open':
        return JsonResponse(
            format_error('INVALID_STATE',
                         f"Job is in state '{job['state']}'. "
                         f"Data can only be uploaded when job is 'Open'."),
            status=400,
            safe=False,
        )

    csv_data = request.body.decode('utf-8') if request.body else ''
    if not csv_data:
        return JsonResponse(
            format_error('INVALID_FIELD', 'CSV data is required'),
            status=400,
            safe=False,
        )

    # Handle multi-batch uploads: strip duplicate header row
    if job.get('csvData'):
        existing_header = get_csv_headers(job['csvData'])
        new_header = get_csv_headers(csv_data)
        if existing_header == new_header:
            # Strip header from new chunk and append data rows only
            first_newline = csv_data.find('\n')
            if first_newline != -1:
                job['csvData'] += '\n' + csv_data[first_newline + 1:]
        else:
            job['csvData'] += '\n' + csv_data
    else:
        job['csvData'] = csv_data

    job_store.update(job_id, {'csvData': job['csvData']})
    row_count = len(csv_data.split('\n')) - 1
    print(f'  CSV data uploaded to job {job_id} ({row_count} rows)')
    return HttpResponse(status=201)


# =====================================================================
# CLOSE / ABORT JOB
# =====================================================================

@csrf_exempt
def close_abort_job(request, version, job_id):
    """
    PATCH /services/data/<version>/jobs/ingest/<job_id>

    Changes the job state. When state is set to 'UploadComplete',
    the server processes all uploaded CSV data synchronously.

    Valid state transitions:
      Open -> UploadComplete (triggers processing -> JobComplete)
      Open -> Aborted
      UploadComplete -> Aborted
    """
    job = job_store.get(job_id)
    if not job:
        return JsonResponse(
            format_error('NOT_FOUND', 'Job not found'),
            status=404,
            safe=False,
        )

    try:
        body = json.loads(request.body) if request.body else {}
    except (json.JSONDecodeError, ValueError):
        return JsonResponse(
            format_error('INVALID_FIELD', 'Invalid JSON in request body'),
            status=400,
            safe=False,
        )

    new_state = body.get('state')

    if new_state == 'UploadComplete':
        if job['state'] != 'Open':
            return JsonResponse(
                format_error('INVALID_STATE',
                             f"Cannot close job in state '{job['state']}'. Job must be 'Open'."),
                status=400,
                safe=False,
            )

        # Process the job synchronously (in a real Salesforce, this is async)
        job_store.update(job_id, {'state': 'UploadComplete'})
        process_ingest_job(job)
        job_store.update(job_id, {
            'state': job['state'],
            'numberRecordsProcessed': job['numberRecordsProcessed'],
            'numberRecordsFailed': job['numberRecordsFailed'],
            'totalProcessingTime': job.get('totalProcessingTime', 0),
            'successfulResults': job.get('successfulResults', []),
            'failedResults': job.get('failedResults', []),
        })

        print(f'  Bulk job {job_id} completed: '
              f'{job["numberRecordsProcessed"]} processed, '
              f'{job["numberRecordsFailed"]} failed')

    elif new_state == 'Aborted':
        job_store.update(job_id, {'state': 'Aborted'})
        print(f'  Bulk job {job_id} aborted')

    else:
        return JsonResponse(
            format_error('INVALID_FIELD',
                         f"Invalid state: '{new_state}'. "
                         f"Must be 'UploadComplete' or 'Aborted'."),
            status=400,
            safe=False,
        )

    updated_job = job_store.get(job_id)
    return JsonResponse(_format_job_response(updated_job))


# =====================================================================
# GET JOB INFO
# =====================================================================

def get_ingest_job(request, version, job_id):
    """
    GET /services/data/<version>/jobs/ingest/<job_id>

    Returns job metadata including current state, record counts, and timestamps.
    SnapLogic polls this endpoint to check if the job is complete.
    """
    job = job_store.get(job_id)
    if not job:
        return JsonResponse(
            format_error('NOT_FOUND', 'Job not found'),
            status=404,
            safe=False,
        )
    return JsonResponse(_format_job_response(job))


# =====================================================================
# GET RESULTS (CSV)
# =====================================================================

def get_successful_results(request, version, job_id):
    """
    GET /services/data/<version>/jobs/ingest/<job_id>/successfulResults

    Returns CSV of successfully processed records.
    Each row includes sf__Id (the created/updated record ID) and sf__Created.
    """
    job = job_store.get(job_id)
    if not job:
        return JsonResponse(
            format_error('NOT_FOUND', 'Job not found'),
            status=404,
            safe=False,
        )

    if job['state'] not in ('JobComplete', 'Failed'):
        return JsonResponse(
            format_error('INVALID_STATE',
                         'Results are only available after job processing is complete'),
            status=400,
            safe=False,
        )

    successful = job.get('successfulResults', [])
    if len(successful) == 0:
        return HttpResponse('', content_type='text/csv')

    headers = list(successful[0].keys())
    return HttpResponse(to_csv(headers, successful), content_type='text/csv')


def get_failed_results(request, version, job_id):
    """
    GET /services/data/<version>/jobs/ingest/<job_id>/failedResults

    Returns CSV of failed records with error details.
    Each row includes sf__Id and sf__Error with the failure reason.
    """
    job = job_store.get(job_id)
    if not job:
        return JsonResponse(
            format_error('NOT_FOUND', 'Job not found'),
            status=404,
            safe=False,
        )

    if job['state'] not in ('JobComplete', 'Failed'):
        return JsonResponse(
            format_error('INVALID_STATE',
                         'Results are only available after job processing is complete'),
            status=400,
            safe=False,
        )

    failed = job.get('failedResults', [])
    if len(failed) == 0:
        return HttpResponse('', content_type='text/csv')

    headers = list(failed[0].keys())
    return HttpResponse(to_csv(headers, failed), content_type='text/csv')


def get_unprocessed_records(request, version, job_id):
    """
    GET /services/data/<version>/jobs/ingest/<job_id>/unprocessedrecords

    Returns CSV of unprocessed records.
    In this mock server, all records are processed synchronously,
    so this always returns empty (matching behavior when processing succeeds).
    """
    job = job_store.get(job_id)
    if not job:
        return JsonResponse(
            format_error('NOT_FOUND', 'Job not found'),
            status=404,
            safe=False,
        )

    return HttpResponse('', content_type='text/csv')


# =====================================================================
# DELETE JOB
# =====================================================================

@csrf_exempt
def delete_ingest_job(request, version, job_id):
    """
    DELETE /services/data/<version>/jobs/ingest/<job_id>

    Deletes a bulk job and all its associated data.
    """
    job = job_store.get(job_id)
    if not job:
        return JsonResponse(
            format_error('NOT_FOUND', 'Job not found'),
            status=404,
            safe=False,
        )

    job_store.remove(job_id)
    print(f'  Bulk job {job_id} deleted')
    return HttpResponse(status=204)


# =====================================================================
# LIST ALL INGEST JOBS
# =====================================================================

def list_ingest_jobs(request, version):
    """
    GET /services/data/<version>/jobs/ingest

    Lists all bulk ingest jobs, sorted by creation date (newest first).
    """
    result = job_store.list_jobs('V2Ingest')
    jobs = [_format_job_response(j) for j in result.get('records', [])]
    return JsonResponse({
        'done': True,
        'records': jobs,
        'nextRecordsUrl': None,
    })


# =====================================================================
# METHOD DISPATCHERS (for Django URL routing)
# =====================================================================

@csrf_exempt
def ingest_job_detail(request, version, job_id):
    """Dispatch GET/PATCH/DELETE for /jobs/ingest/<job_id>."""
    if request.method == 'GET':
        return get_ingest_job(request, version, job_id)
    elif request.method == 'PATCH':
        return close_abort_job(request, version, job_id)
    elif request.method == 'DELETE':
        return delete_ingest_job(request, version, job_id)
    else:
        return JsonResponse(
            format_error('METHOD_NOT_ALLOWED', f'{request.method} not allowed'),
            status=405, safe=False,
        )


@csrf_exempt
def ingest_job_list(request, version):
    """Dispatch GET/POST for /jobs/ingest."""
    if request.method == 'GET':
        return list_ingest_jobs(request, version)
    elif request.method == 'POST':
        return create_ingest_job(request, version)
    else:
        return JsonResponse(
            format_error('METHOD_NOT_ALLOWED', f'{request.method} not allowed'),
            status=405, safe=False,
        )


# =====================================================================
# HELPER -- Format job response (strip internal fields)
# =====================================================================

def _format_job_response(job):
    """
    Formats a job object for API response, stripping internal fields
    (csvData, result arrays) that are not part of the Salesforce API response.
    """
    return {
        'id': job.get('id', ''),
        'operation': job.get('operation', ''),
        'object': job.get('object', ''),
        'createdById': job.get('createdById', '005000000000000AAA'),
        'createdDate': job.get('createdDate', ''),
        'systemModstamp': job.get('systemModstamp', ''),
        'state': job.get('state', ''),
        'externalIdFieldName': job.get('externalIdFieldName', ''),
        'concurrencyMode': job.get('concurrencyMode', 'Parallel'),
        'contentType': job.get('contentType', 'CSV'),
        'apiVersion': job.get('apiVersion', '59.0'),
        'jobType': job.get('jobType', ''),
        'lineEnding': job.get('lineEnding', 'LF'),
        'numberRecordsProcessed': job.get('numberRecordsProcessed', 0),
        'numberRecordsFailed': job.get('numberRecordsFailed', 0),
        'retries': job.get('retries', 0),
        'totalProcessingTime': job.get('totalProcessingTime', 0),
    }
