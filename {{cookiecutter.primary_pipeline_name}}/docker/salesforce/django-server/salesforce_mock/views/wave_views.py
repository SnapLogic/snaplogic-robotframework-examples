"""
Wave Analytics (Einstein Analytics) Views
==========================================
Port of: wave-routes.js

Django function-based views for the Salesforce Wave Analytics REST API.
Provides dataset listing, dataset detail, dataset versions, and SAQL query
execution against pre-seeded sample datasets.

Routes:
    GET  /services/data/:version/wave/datasets           - List all datasets
    GET  /services/data/:version/wave/datasets/:id        - Get dataset by ID
    GET  /services/data/:version/wave/datasets/:id/versions - List dataset versions
    POST /services/data/:version/wave/query               - Execute SAQL query

Used by: SnapLogic "Salesforce Analytics" snaps (Wave/Einstein Analytics).

SAQL (Salesforce Analytics Query Language) is a pipeline-style query language:
    q = load "datasetRef";
    q = foreach q generate 'Field1', 'Field2';
    q = filter q by 'Field' == "value";
    q = order q by 'Field' asc;
    q = limit q 10;
"""

import json
import re

from django.http import JsonResponse
from django.views.decorators.csrf import csrf_exempt

from salesforce_mock.utils.id_generator import generate_id
from salesforce_mock.utils.error_formatter import format_error


# =====================================================================
# Module-Level Storage
# =====================================================================

# In-memory dataset store: dataset_id -> dataset dict
_wave_datasets = {}

# In-memory version store: dataset_id -> [version_list]
_wave_versions = {}


# =====================================================================
# Seed Sample Datasets
# =====================================================================

def _seed_sample_datasets():
    """
    Pre-seed two sample Wave datasets with versions and sample data.

    This runs at module load time so the Wave API always has data
    available for testing without requiring any setup.

    Datasets:
        1. SalesPipeline - 5 records with Name, Amount, Stage, Region
        2. CustomerMetrics - 3 records with Customer, Score, Segment, Revenue
    """
    # --- Dataset 1: SalesPipeline ---
    sales_id = '0FbSALES00000001'
    sales_version_id = '0FcSALESV0000001'

    _wave_datasets[sales_id] = {
        'id': sales_id,
        'name': 'SalesPipeline',
        'label': 'Sales Pipeline',
        'description': 'Sales pipeline data for testing Wave Analytics queries',
        'datasetType': 'default',
        'currentVersionId': sales_version_id,
        'createdDate': '2024-01-15T10:00:00.000Z',
        'lastModifiedDate': '2024-06-01T14:30:00.000Z',
        'folderId': '00lFOLDER0000001',
        'folderName': 'SharedApp',
        '_sampleData': [
            {'Name': 'Acme Deal', 'Amount': 50000, 'Stage': 'Closed Won', 'Region': 'West'},
            {'Name': 'Beta Opportunity', 'Amount': 75000, 'Stage': 'Negotiation', 'Region': 'East'},
            {'Name': 'Gamma Contract', 'Amount': 120000, 'Stage': 'Closed Won', 'Region': 'West'},
            {'Name': 'Delta Prospect', 'Amount': 30000, 'Stage': 'Prospecting', 'Region': 'Central'},
            {'Name': 'Epsilon Renewal', 'Amount': 95000, 'Stage': 'Negotiation', 'Region': 'East'},
        ],
    }

    _wave_versions[sales_id] = [
        {
            'id': sales_version_id,
            'datasetId': sales_id,
            'createdDate': '2024-06-01T14:30:00.000Z',
            'totalRowCount': 5,
        },
    ]

    # --- Dataset 2: CustomerMetrics ---
    metrics_id = '0FbMETRICS000001'
    metrics_version_id = '0FcMETRICSV00001'

    _wave_datasets[metrics_id] = {
        'id': metrics_id,
        'name': 'CustomerMetrics',
        'label': 'Customer Metrics',
        'description': 'Customer satisfaction and segmentation metrics',
        'datasetType': 'default',
        'currentVersionId': metrics_version_id,
        'createdDate': '2024-02-20T09:00:00.000Z',
        'lastModifiedDate': '2024-06-10T11:00:00.000Z',
        'folderId': '00lFOLDER0000001',
        'folderName': 'SharedApp',
        '_sampleData': [
            {'Customer': 'Acme Corp', 'Score': 92, 'Segment': 'Enterprise', 'Revenue': 500000},
            {'Customer': 'Beta Inc', 'Score': 78, 'Segment': 'Mid-Market', 'Revenue': 150000},
            {'Customer': 'Gamma LLC', 'Score': 85, 'Segment': 'Enterprise', 'Revenue': 320000},
        ],
    }

    _wave_versions[metrics_id] = [
        {
            'id': metrics_version_id,
            'datasetId': metrics_id,
            'createdDate': '2024-06-10T11:00:00.000Z',
            'totalRowCount': 3,
        },
    ]


# Seed on module load
_seed_sample_datasets()


# =====================================================================
# View: List Datasets
# =====================================================================

def list_datasets(request, version):
    """
    GET /services/data/:version/wave/datasets

    List all Wave Analytics datasets. Strips internal _sampleData from
    each dataset in the response.

    Response format matches Salesforce Wave REST API:
        {
            "datasets": [...],
            "totalSize": <count>,
            "url": "/services/data/<version>/wave/datasets"
        }
    """
    datasets = []
    for dataset in _wave_datasets.values():
        # Copy without internal _sampleData field
        ds_copy = {k: v for k, v in dataset.items() if k != '_sampleData'}
        datasets.append(ds_copy)

    return JsonResponse({
        'datasets': datasets,
        'totalSize': len(datasets),
        'url': f'/services/data/{version}/wave/datasets',
    })


# =====================================================================
# View: Get Single Dataset
# =====================================================================

def get_dataset(request, version, dataset_id):
    """
    GET /services/data/:version/wave/datasets/:dataset_id

    Get a single Wave dataset by ID. Returns 404 if not found.
    Adds url and versionsUrl to the response.

    Response format:
        {
            "id": "...",
            "name": "...",
            ...
            "url": "/services/data/<version>/wave/datasets/<id>",
            "versionsUrl": "/services/data/<version>/wave/datasets/<id>/versions"
        }
    """
    dataset = _wave_datasets.get(dataset_id)

    if not dataset:
        return JsonResponse(
            format_error('NOT_FOUND', f'Wave dataset not found: {dataset_id}'),
            status=404,
            safe=False,
        )

    # Copy without internal _sampleData field, add URLs
    ds_copy = {k: v for k, v in dataset.items() if k != '_sampleData'}
    ds_copy['url'] = f'/services/data/{version}/wave/datasets/{dataset_id}'
    ds_copy['versionsUrl'] = f'/services/data/{version}/wave/datasets/{dataset_id}/versions'

    return JsonResponse(ds_copy)


# =====================================================================
# View: List Dataset Versions
# =====================================================================

def list_dataset_versions(request, version, dataset_id):
    """
    GET /services/data/:version/wave/datasets/:dataset_id/versions

    List all versions for a given dataset. Returns 404 if the dataset
    does not exist.

    Response format:
        {
            "versions": [...],
            "url": "/services/data/<version>/wave/datasets/<id>/versions"
        }
    """
    if dataset_id not in _wave_datasets:
        return JsonResponse(
            format_error('NOT_FOUND', f'Wave dataset not found: {dataset_id}'),
            status=404,
            safe=False,
        )

    versions = _wave_versions.get(dataset_id, [])

    return JsonResponse({
        'versions': versions,
        'url': f'/services/data/{version}/wave/datasets/{dataset_id}/versions',
    })


# =====================================================================
# View: SAQL Query
# =====================================================================

@csrf_exempt
def wave_query(request, version):
    """
    POST /services/data/:version/wave/query

    Execute a SAQL (Salesforce Analytics Query Language) query against
    the in-memory Wave datasets.

    Request body:
        { "query": "q = load \"0FbSALES00000001\"; q = foreach q generate ..." }

    Response format matches Salesforce Wave REST API:
        {
            "action": "query",
            "responseId": "<generated_id>",
            "results": {
                "metadata": [...],
                "records": [...]
            },
            "query": "<original_saql>",
            "responseTime": <ms>,
            "warnings": []
        }
    """
    try:
        body = json.loads(request.body) if request.body else {}
    except (json.JSONDecodeError, ValueError):
        return JsonResponse(
            format_error('MALFORMED_QUERY', 'Invalid JSON in request body'),
            status=400,
            safe=False,
        )

    saql = body.get('query')
    if not saql:
        return JsonResponse(
            format_error('MALFORMED_QUERY', 'SAQL query is required. Provide a "query" field.'),
            status=400,
            safe=False,
        )

    try:
        result = _execute_saql(saql)
    except Exception as exc:
        return JsonResponse(
            format_error('MALFORMED_QUERY', f'SAQL execution error: {exc}'),
            status=400,
            safe=False,
        )

    response_id = generate_id('0Aq')

    return JsonResponse({
        'action': 'query',
        'responseId': response_id,
        'results': {
            'metadata': result.get('metadata', []),
            'records': result.get('records', []),
        },
        'query': saql,
        'responseTime': 42,
        'warnings': [],
    })


# =====================================================================
# Helper: Execute Simplified SAQL
# =====================================================================

def _execute_saql(saql):
    """
    Parse and execute a simplified SAQL query against in-memory datasets.

    Supported SAQL operations:
        - load "ref"              -> Load dataset by ID, ID/version, or name
        - foreach q generate ...  -> Field projection
        - filter q by ...         -> Basic equality/inequality filtering
        - order q by ...          -> Sorting (asc/desc)
        - limit q N               -> Row limit

    Args:
        saql: The SAQL query string.

    Returns:
        dict with 'metadata' (list of field info dicts) and 'records' (list of row dicts).

    Raises:
        ValueError: If the dataset reference cannot be resolved.
    """
    # --- Step 1: Extract dataset from load statement ---
    load_match = re.search(r'load\s+"([^"]+)"', saql)
    if not load_match:
        raise ValueError('SAQL must contain a load statement: q = load "datasetRef"')

    dataset_ref = load_match.group(1)
    dataset = None
    sample_data = None

    # Try matching by dataset ID directly
    if dataset_ref in _wave_datasets:
        dataset = _wave_datasets[dataset_ref]

    # Try matching by "datasetId/versionId" format
    if not dataset and '/' in dataset_ref:
        ds_id = dataset_ref.split('/')[0]
        if ds_id in _wave_datasets:
            dataset = _wave_datasets[ds_id]

    # Try matching by dataset name
    if not dataset:
        for ds in _wave_datasets.values():
            if ds.get('name') == dataset_ref:
                dataset = ds
                break

    if not dataset:
        raise ValueError(f'Dataset not found for reference: {dataset_ref}')

    sample_data = list(dataset.get('_sampleData', []))

    # --- Step 2: Parse foreach for field projection ---
    projected_fields = None
    foreach_match = re.search(r'foreach\s+\w+\s+generate\s+(.+?)(?:;|$)', saql, re.IGNORECASE)
    if foreach_match:
        fields_str = foreach_match.group(1).strip().rstrip(';')
        # Parse field names: 'FieldName' or 'FieldName' as Alias
        projected_fields = []
        for field_part in re.split(r',\s*', fields_str):
            field_part = field_part.strip()
            # Handle 'Field' as Alias or just 'Field'
            alias_match = re.match(r"'([^']+)'\s+as\s+'([^']+)'", field_part, re.IGNORECASE)
            if alias_match:
                projected_fields.append({
                    'source': alias_match.group(1),
                    'alias': alias_match.group(2),
                })
            else:
                # Simple field name (with or without quotes)
                field_name = field_part.strip("'\"")
                projected_fields.append({
                    'source': field_name,
                    'alias': field_name,
                })

    # --- Step 3: Parse filter for basic conditions ---
    filter_match = re.search(r'filter\s+\w+\s+by\s+(.+?)(?:;|$)', saql, re.IGNORECASE)
    if filter_match:
        filter_expr = filter_match.group(1).strip().rstrip(';')
        # Parse conditions joined by && or "and"
        condition_parts = re.split(r'\s*(?:&&|and)\s*', filter_expr, flags=re.IGNORECASE)

        for condition_str in condition_parts:
            condition_str = condition_str.strip()
            # Match: 'Field' == "value" or 'Field' != "value" or 'Field' > number
            cond_match = re.match(
                r"""'([^']+)'\s*(==|!=|>=|<=|>|<)\s*(?:"([^"]*)"|'([^']*)'|(\d+(?:\.\d+)?))""",
                condition_str,
            )
            if cond_match:
                field = cond_match.group(1)
                operator = cond_match.group(2)
                # Value is in group 3 (double-quoted), 4 (single-quoted), or 5 (numeric)
                value = cond_match.group(3) or cond_match.group(4)
                if value is None and cond_match.group(5):
                    value = float(cond_match.group(5)) if '.' in cond_match.group(5) else int(cond_match.group(5))

                filtered = []
                for row in sample_data:
                    row_val = row.get(field)
                    if row_val is None:
                        continue
                    if operator == '==' and row_val == value:
                        filtered.append(row)
                    elif operator == '!=' and row_val != value:
                        filtered.append(row)
                    elif operator == '>' and isinstance(row_val, (int, float)) and row_val > value:
                        filtered.append(row)
                    elif operator == '>=' and isinstance(row_val, (int, float)) and row_val >= value:
                        filtered.append(row)
                    elif operator == '<' and isinstance(row_val, (int, float)) and row_val < value:
                        filtered.append(row)
                    elif operator == '<=' and isinstance(row_val, (int, float)) and row_val <= value:
                        filtered.append(row)

                sample_data = filtered

    # --- Step 4: Parse order for sorting ---
    order_match = re.search(r'order\s+\w+\s+by\s+(.+?)(?:;|$)', saql, re.IGNORECASE)
    if order_match:
        order_expr = order_match.group(1).strip().rstrip(';')
        # Parse: 'FieldName' asc/desc
        order_field_match = re.match(r"'([^']+)'(?:\s+(asc|desc))?", order_expr, re.IGNORECASE)
        if order_field_match:
            order_field = order_field_match.group(1)
            order_dir = (order_field_match.group(2) or 'asc').lower()
            sample_data.sort(
                key=lambda r: (r.get(order_field) is None, r.get(order_field, '')),
                reverse=(order_dir == 'desc'),
            )

    # --- Step 5: Parse limit ---
    limit_match = re.search(r'limit\s+\w+\s+(\d+)', saql, re.IGNORECASE)
    if limit_match:
        limit_val = int(limit_match.group(1))
        sample_data = sample_data[:limit_val]

    # --- Step 6: Apply field projection ---
    if projected_fields:
        projected_records = []
        for row in sample_data:
            proj_row = {}
            for field_info in projected_fields:
                source = field_info['source']
                alias = field_info['alias']
                if source in row:
                    proj_row[alias] = row[source]
            projected_records.append(proj_row)
        records = projected_records
    else:
        records = sample_data

    # --- Step 7: Build metadata ---
    metadata = []
    if records:
        first_row = records[0]
        for field_name, field_value in first_row.items():
            field_type = 'numeric' if isinstance(field_value, (int, float)) else 'string'
            metadata.append({
                'lineageId': field_name,
                'type': field_type,
            })

    return {
        'metadata': metadata,
        'records': records,
    }
