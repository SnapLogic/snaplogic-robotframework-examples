"""
Admin & Health Views
====================
Port of: admin-routes.js

Django function-based views for the Salesforce mock server admin and
health-check endpoints. These are NOT part of the real Salesforce API --
they provide test introspection, database reset, and health monitoring.

Routes:
    GET  /__admin/db                  - View all records grouped by object
    GET  /__admin/db/:object          - View records for a single object
    POST /__admin/reset               - Reset all data (records, jobs, events)
    GET  /__admin/schemas             - View loaded schema definitions
    GET  /__admin/bulk-jobs           - View all bulk API jobs
    GET  /__admin/events              - View all platform events
    GET  /__admin/streaming-clients   - View CometD client sessions
    GET  /__admin/health              - Simple health check
    GET  /health                      - Detailed health status with counts
"""

from datetime import datetime, timezone

from django.http import JsonResponse
from django.views.decorators.csrf import csrf_exempt

from salesforce_mock.state.database import schemas, database, reset_all
from salesforce_mock.state.job_store import job_store
from salesforce_mock.state.event_bus import event_bus


# =====================================================================
# Admin: Database Inspection
# =====================================================================

def admin_db(request):
    """
    GET /__admin/db

    Return all records in the in-memory database, grouped by object type.
    Useful for test verification -- inspect what records exist after a
    pipeline run.

    Response format:
        {
            "Account": { "count": 3, "records": [...] },
            "Contact": { "count": 1, "records": [...] },
            ...
        }
    """
    result = {}
    for object_name, records in database.items():
        result[object_name] = {
            'count': len(records),
            'records': records,
        }

    return JsonResponse(result)


def admin_db_object(request, object_name):
    """
    GET /__admin/db/:object_name

    Return all records for a single object type. Returns 404 if the
    object type does not exist in the database.

    Response format:
        { "count": 3, "records": [...] }
    """
    if object_name not in database:
        return JsonResponse(
            {'error': f"Object '{object_name}' not found in database"},
            status=404,
        )

    records = database[object_name]

    return JsonResponse({
        'count': len(records),
        'records': records,
    })


# =====================================================================
# Admin: Reset
# =====================================================================

@csrf_exempt
def admin_reset(request):
    """
    POST /__admin/reset

    Reset all mock server state:
        - Clear all database records (preserving schema definitions)
        - Clear all bulk API jobs
        - Clear all platform events and CometD client sessions

    Used by test setup/teardown to ensure a clean state between test runs.

    Response format:
        {
            "status": "reset",
            "recordsCleared": <count>,
            "bulkJobsCleared": <count>,
            "eventsCleared": <count>,
            "clientsCleared": <count>
        }
    """
    records_cleared = reset_all()
    bulk_jobs_cleared = job_store.clear()
    events_result = event_bus.clear()

    return JsonResponse({
        'status': 'reset',
        'recordsCleared': records_cleared,
        'bulkJobsCleared': bulk_jobs_cleared,
        'eventsCleared': events_result.get('eventsCleared', 0),
        'clientsCleared': events_result.get('clientsCleared', 0),
    })


# =====================================================================
# Admin: Schema Inspection
# =====================================================================

def admin_schemas(request):
    """
    GET /__admin/schemas

    Return all loaded schema definitions. Useful for debugging which
    Salesforce object types are available and their field configurations.

    Response format:
        {
            "Account": { "name": "Account", "idPrefix": "001", "fields": {...} },
            "Contact": { ... },
            ...
        }
    """
    return JsonResponse(schemas)


# =====================================================================
# Admin: Bulk Jobs
# =====================================================================

def admin_bulk_jobs(request):
    """
    GET /__admin/bulk-jobs

    Return all bulk API jobs (both v1 and v2). Useful for verifying
    bulk operations completed correctly during tests.

    Response format:
        { "count": 2, "jobs": [...] }
    """
    return JsonResponse(job_store.list_all())


# =====================================================================
# Admin: Platform Events
# =====================================================================

def admin_events(request):
    """
    GET /__admin/events

    Return all published platform events grouped by channel.
    Useful for verifying events were published during pipeline tests.

    Response format:
        {
            "channels": {
                "/event/MyEvent__e": { "count": 5, "events": [...] }
            },
            "totalEvents": 5
        }
    """
    return JsonResponse(event_bus.get_all_events())


# =====================================================================
# Admin: Streaming Clients
# =====================================================================

def admin_streaming_clients(request):
    """
    GET /__admin/streaming-clients

    Return all connected CometD streaming clients and their subscriptions.
    Useful for verifying subscriber connections during tests.

    Response format:
        {
            "count": 1,
            "clients": [
                { "id": "mock-client-...", "subscriptions": [...], "connectedAt": "..." }
            ]
        }
    """
    return JsonResponse(event_bus.get_clients())


# =====================================================================
# Health: Detailed Status
# =====================================================================

def health(request):
    """
    GET /health

    Detailed health status endpoint. Returns server health along with
    counts for all major subsystems (database objects, records, bulk jobs,
    events, streaming clients).

    This is the primary health check endpoint for Docker health checks
    and monitoring.

    Response format:
        {
            "status": "UP",
            "timestamp": "2024-...",
            "objects": <count>,
            "totalRecords": <count>,
            "bulkJobs": <count>,
            "events": <count>,
            "streamingClients": <count>
        }
    """
    total_records = sum(len(records) for records in database.values())

    events_info = event_bus.get_all_events()
    clients_info = event_bus.get_clients()
    jobs_info = job_store.list_all()

    return JsonResponse({
        'status': 'UP',
        'timestamp': datetime.now(timezone.utc).isoformat().replace('+00:00', 'Z'),
        'objects': len(database),
        'totalRecords': total_records,
        'bulkJobs': jobs_info.get('count', 0),
        'events': events_info.get('totalEvents', 0),
        'streamingClients': clients_info.get('count', 0),
    })


# =====================================================================
# Admin: Simple Health Check
# =====================================================================

def admin_health(request):
    """
    GET /__admin/health

    Simple health check that returns a minimal response. Used for
    quick liveness probes that don't need detailed status.

    Response format:
        { "status": "healthy" }
    """
    return JsonResponse({'status': 'healthy'})


# =====================================================================
# Root Index — Landing page
# =====================================================================

def root_index(request):
    """
    GET /

    Returns available endpoints as JSON. Provides a quick reference
    when accessing the server root from a browser or curl.
    """
    protocol = 'https' if request.is_secure() else 'http'
    host = request.get_host()
    base = f'{protocol}://{host}'

    return JsonResponse({
        'service': 'Salesforce Django Mock API Server',
        'status': 'UP',
        'endpoints': {
            'health': f'{base}/health',
            'oauth_token': f'{base}/services/oauth2/token',
            'rest_api': f'{base}/services/data/v59.0/sobjects/{{Object}}',
            'soql_query': f'{base}/services/data/v59.0/query?q=SELECT+Id+FROM+Account',
            'bulk_v2_ingest': f'{base}/services/data/v59.0/jobs/ingest',
            'bulk_v2_query': f'{base}/services/data/v59.0/jobs/query',
            'bulk_v1': f'{base}/services/async/59.0/job',
            'admin_db': f'{base}/__admin/db',
            'admin_schemas': f'{base}/__admin/schemas',
            'admin_reset': f'{base}/__admin/reset',
            'admin_bulk_jobs': f'{base}/__admin/bulk-jobs',
        },
    })
