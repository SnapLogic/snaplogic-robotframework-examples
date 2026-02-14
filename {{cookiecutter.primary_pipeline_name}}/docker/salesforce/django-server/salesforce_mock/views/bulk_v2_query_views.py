"""
Salesforce Bulk API 2.0 - Query (Read) Views
=============================================
Port of: bulk-v2-query-routes.js

Handles bulk read operations via SOQL queries.
Results are returned as CSV (not JSON like REST API /query endpoint).

Bulk API 2.0 Query Job Lifecycle:
  1. POST   .../jobs/query             -> Create query job (processed immediately)
  2. GET    .../jobs/query/:id         -> Poll status (state: JobComplete)
  3. GET    .../jobs/query/:id/results -> Download results as CSV

Processing is SYNCHRONOUS - the query executes immediately on job creation.
SnapLogic's first poll will see the completed state.

Uses the SAME SOQL parser as the REST API query endpoint (core/soql_parser.py),
and queries the SAME in-memory database.

Routes:
    POST   /services/data/:version/jobs/query                - Create query job
    GET    /services/data/:version/jobs/query/:jobId         - Get job status
    GET    /services/data/:version/jobs/query/:jobId/results - Get CSV results
    PATCH  /services/data/:version/jobs/query/:jobId         - Abort job
    GET    /services/data/:version/jobs/query                - List all query jobs
"""
import json
import logging

from django.http import JsonResponse, HttpResponse
from django.views.decorators.csrf import csrf_exempt

from salesforce_mock.utils.error_formatter import format_error
from salesforce_mock.state.job_store import job_store
from salesforce_mock.services.bulk_processor import process_query_job

logger = logging.getLogger(__name__)


# =====================================================================
# View: Create Bulk Query Job
# =====================================================================

@csrf_exempt
def create_query_job(request, version):
    """
    POST /services/data/:version/jobs/query

    Creates a bulk query job. The SOQL query is executed immediately
    and results are available right away via GET .../results.

    Request Body:
        operation: 'query' or 'queryAll' (optional, defaults to 'query')
        query: SOQL query string (required)

    Returns 201 with formatted job response on success.
    """
    try:
        body = json.loads(request.body)
    except (json.JSONDecodeError, ValueError):
        return JsonResponse(
            format_error('MALFORMED_QUERY', 'Invalid JSON in request body'),
            status=400,
            safe=False,
        )

    operation = body.get('operation')
    query = body.get('query')

    if not query:
        return JsonResponse(
            format_error('MALFORMED_QUERY', 'query field is required'),
            status=400,
            safe=False,
        )

    valid_ops = ['query', 'queryAll']
    if operation and operation not in valid_ops:
        return JsonResponse(
            format_error('INVALID_FIELD',
                         f"operation must be one of: {', '.join(valid_ops)}"),
            status=400,
            safe=False,
        )

    job = job_store.create({
        'object': '',  # Will be extracted from SOQL by processor
        'operation': operation or 'query',
        'query': query,
        'jobType': 'V2Query',
    })

    # Process the query immediately (synchronous)
    process_query_job(job)
    job_store.update(job['id'], {
        'state': job['state'],
        'object': job.get('object', ''),
        'numberRecordsProcessed': job['numberRecordsProcessed'],
        'numberRecordsFailed': job.get('numberRecordsFailed', 0),
        'queryResults': job.get('queryResults', ''),
    })

    logger.info(
        "Bulk query job created and completed: %s (%d records)",
        job['id'],
        job['numberRecordsProcessed'],
    )
    return JsonResponse(_format_query_job_response(job), status=201)


# =====================================================================
# View: Get Query Job Status
# =====================================================================

def get_query_job(request, version, job_id):
    """
    GET /services/data/:version/jobs/query/:jobId

    Returns query job metadata. SnapLogic polls this to check completion.
    """
    job = job_store.get(job_id)
    if not job:
        return JsonResponse(
            format_error('NOT_FOUND', 'Job not found'),
            status=404,
            safe=False,
        )

    if job.get('jobType') != 'V2Query':
        return JsonResponse(
            format_error('INVALID_TYPE', 'This is not a query job'),
            status=400,
            safe=False,
        )

    return JsonResponse(_format_query_job_response(job))


# =====================================================================
# View: Get Query Results (CSV)
# =====================================================================

def get_query_results(request, version, job_id):
    """
    GET /services/data/:version/jobs/query/:jobId/results

    Returns query results as CSV. Includes Sforce-Locator and
    Sforce-NumberOfRecords headers (matching real Salesforce).
    """
    job = job_store.get(job_id)
    if not job:
        return JsonResponse(
            format_error('NOT_FOUND', 'Job not found'),
            status=404,
            safe=False,
        )

    if job.get('jobType') != 'V2Query':
        return JsonResponse(
            format_error('INVALID_TYPE', 'This is not a query job'),
            status=400,
            safe=False,
        )

    if job.get('state') != 'JobComplete':
        return JsonResponse(
            format_error('INVALID_STATE',
                         'Results are only available when job state is JobComplete'),
            status=400,
            safe=False,
        )

    # Set Salesforce-specific headers
    response = HttpResponse(
        job.get('queryResults', ''),
        content_type='text/csv',
    )
    response['Sforce-Locator'] = 'null'  # No pagination in mock
    response['Sforce-NumberOfRecords'] = str(job.get('numberRecordsProcessed', 0))
    return response


# =====================================================================
# View: Abort Query Job
# =====================================================================

@csrf_exempt
def abort_query_job(request, version, job_id):
    """
    PATCH /services/data/:version/jobs/query/:jobId

    Aborts a query job. In practice, since our mock processes queries
    synchronously, the job is already complete before this is called.

    Request Body:
        state: Must be 'Aborted'
    """
    job = job_store.get(job_id)
    if not job:
        return JsonResponse(
            format_error('NOT_FOUND', 'Job not found'),
            status=404,
            safe=False,
        )

    if job.get('jobType') != 'V2Query':
        return JsonResponse(
            format_error('INVALID_TYPE', 'This is not a query job'),
            status=400,
            safe=False,
        )

    try:
        body = json.loads(request.body)
    except (json.JSONDecodeError, ValueError):
        return JsonResponse(
            format_error('INVALID_FIELD', 'Invalid JSON in request body'),
            status=400,
            safe=False,
        )

    state = body.get('state')
    if state == 'Aborted':
        job_store.update(job['id'], {'state': 'Aborted'})
        logger.info("Bulk query job %s aborted", job['id'])
    else:
        return JsonResponse(
            format_error('INVALID_FIELD',
                         f"Invalid state: '{state}'. Only 'Aborted' is allowed."),
            status=400,
            safe=False,
        )

    return JsonResponse(_format_query_job_response(job_store.get(job['id'])))


# =====================================================================
# View: List All Query Jobs
# =====================================================================

def list_query_jobs(request, version):
    """
    GET /services/data/:version/jobs/query

    Lists all bulk query jobs filtered by jobType 'V2Query'.
    """
    result = job_store.list_jobs(job_type='V2Query')
    records = [_format_query_job_response(j) for j in result['records']]
    return JsonResponse({
        'done': True,
        'records': records,
        'nextRecordsUrl': None,
    })


# =====================================================================
# METHOD DISPATCHERS (for Django URL routing)
# =====================================================================

@csrf_exempt
def query_job_detail(request, version, job_id):
    """Dispatch GET/PATCH for /jobs/query/<job_id>."""
    if request.method == 'GET':
        return get_query_job(request, version, job_id)
    elif request.method == 'PATCH':
        return abort_query_job(request, version, job_id)
    else:
        return JsonResponse(
            format_error('METHOD_NOT_ALLOWED', f'{request.method} not allowed'),
            status=405, safe=False,
        )


@csrf_exempt
def query_job_list(request, version):
    """Dispatch GET/POST for /jobs/query."""
    if request.method == 'GET':
        return list_query_jobs(request, version)
    elif request.method == 'POST':
        return create_query_job(request, version)
    else:
        return JsonResponse(
            format_error('METHOD_NOT_ALLOWED', f'{request.method} not allowed'),
            status=405, safe=False,
        )


# =====================================================================
# Helper: Format query job response
# =====================================================================

def _format_query_job_response(job):
    """
    Formats a query job dict for API response, stripping internal fields.

    Returns only the fields that the real Salesforce Bulk API 2.0 returns
    for query job responses.
    """
    return {
        'id': job.get('id'),
        'operation': job.get('operation'),
        'object': job.get('object'),
        'createdById': job.get('createdById'),
        'createdDate': job.get('createdDate'),
        'systemModstamp': job.get('systemModstamp'),
        'state': job.get('state'),
        'concurrencyMode': job.get('concurrencyMode'),
        'contentType': job.get('contentType'),
        'apiVersion': job.get('apiVersion'),
        'jobType': job.get('jobType'),
        'lineEnding': job.get('lineEnding'),
        'numberRecordsProcessed': job.get('numberRecordsProcessed', 0),
        'retries': job.get('retries'),
        'totalProcessingTime': job.get('totalProcessingTime'),
    }
