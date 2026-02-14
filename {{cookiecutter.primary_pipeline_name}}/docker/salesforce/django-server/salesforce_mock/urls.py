"""
Root URL Configuration
======================
Port of: lib/routes.js

CRITICAL ROUTE ORDER:
  Routes are registered in the same order as Express (first match wins).
  Django uses top-to-bottom matching, so specific patterns BEFORE generic ones.

  1. Search        (/search must not match /sobjects/:object)
  2. Download      (/Attachment/:id/Body must not match generic CRUD)
  3. Platform Events (__e objects intercepted before REST CRUD)
  4. REST API      (CRUD + SOQL + OAuth + Limits)
  5. Bulk API v1   (/services/async/...)
  6. Bulk v2 Ingest (/jobs/ingest/...)
  7. Bulk v2 Query  (/jobs/query/...)
  8. Wave Analytics (/wave/...)
  9. CometD         (/cometd/...)
  10. Admin + Health (last)
"""
from django.urls import path, re_path
from salesforce_mock.views import (
    rest_views,
    search_views,
    download_views,
    event_views,
    bulk_v1_views,
    bulk_v2_ingest_views,
    bulk_v2_query_views,
    wave_views,
    admin_views,
)

# Version pattern segment
V = '<str:version>'

urlpatterns = [
    # ═══════════════════════════════════════════════════════════════
    # 1. SEARCH — Must be BEFORE REST routes
    # ═══════════════════════════════════════════════════════════════
    path(f'services/data/{V}/search', search_views.sosl_search),

    # ═══════════════════════════════════════════════════════════════
    # 2. DOWNLOAD — Must be BEFORE generic /sobjects/:object/:id
    # ═══════════════════════════════════════════════════════════════
    path(f'services/data/{V}/sobjects/Attachment/<str:record_id>/Body',
         download_views.download_attachment_body),
    path(f'services/data/{V}/sobjects/ContentVersion/<str:record_id>/VersionData',
         download_views.download_content_version),
    path(f'services/data/{V}/sobjects/Document/<str:record_id>/Body',
         download_views.download_document_body),

    # ═══════════════════════════════════════════════════════════════
    # 3. PLATFORM EVENTS — Intercept __e objects before REST CRUD
    #    Uses re_path to match only objects ending in __e
    # ═══════════════════════════════════════════════════════════════
    re_path(r'^services/data/(?P<version>[^/]+)/sobjects/(?P<object_name>\w+__e)$',
            event_views.publish_event),

    # ═══════════════════════════════════════════════════════════════
    # 4. REST API — CRUD + SOQL + OAuth + Describe + Limits
    # ═══════════════════════════════════════════════════════════════
    # OAuth (no version prefix)
    path('services/oauth2/token', rest_views.oauth_token),

    # Describe (before generic CRUD — more specific path)
    path(f'services/data/{V}/sobjects/<str:object_name>/describe',
         rest_views.describe_object),

    # SOQL Query
    path(f'services/data/{V}/query', rest_views.soql_query),

    # API Limits
    path(f'services/data/{V}/limits', rest_views.api_limits),

    # Upsert by external ID (before generic /:id — more path segments)
    path(f'services/data/{V}/sobjects/<str:object_name>/<str:ext_id_field>/<str:ext_id_value>',
         rest_views.upsert_record),

    # CRUD: Create (POST), Read/Update/Delete by ID
    path(f'services/data/{V}/sobjects/<str:object_name>/<str:record_id>',
         rest_views.record_detail),
    path(f'services/data/{V}/sobjects/<str:object_name>',
         rest_views.create_record),

    # ═══════════════════════════════════════════════════════════════
    # 5. BULK API v1 — /services/async/:version/job[/...]
    # ═══════════════════════════════════════════════════════════════
    path(f'services/async/{V}/job/<str:job_id>/batch/<str:batch_id>/result',
         bulk_v1_views.get_v1_batch_results),
    path(f'services/async/{V}/job/<str:job_id>/batch/<str:batch_id>',
         bulk_v1_views.get_v1_batch),
    path(f'services/async/{V}/job/<str:job_id>/batch',
         bulk_v1_views.v1_batch_handler),
    path(f'services/async/{V}/job/<str:job_id>',
         bulk_v1_views.v1_job_handler),
    path(f'services/async/{V}/job',
         bulk_v1_views.create_v1_job),

    # ═══════════════════════════════════════════════════════════════
    # 6. BULK API v2 INGEST — /services/data/:version/jobs/ingest[/...]
    # ═══════════════════════════════════════════════════════════════
    path(f'services/data/{V}/jobs/ingest/<str:job_id>/successfulResults',
         bulk_v2_ingest_views.get_successful_results),
    path(f'services/data/{V}/jobs/ingest/<str:job_id>/failedResults',
         bulk_v2_ingest_views.get_failed_results),
    path(f'services/data/{V}/jobs/ingest/<str:job_id>/unprocessedrecords',
         bulk_v2_ingest_views.get_unprocessed_records),
    path(f'services/data/{V}/jobs/ingest/<str:job_id>/batches',
         bulk_v2_ingest_views.upload_csv_data),
    path(f'services/data/{V}/jobs/ingest/<str:job_id>',
         bulk_v2_ingest_views.ingest_job_detail),
    path(f'services/data/{V}/jobs/ingest',
         bulk_v2_ingest_views.ingest_job_list),

    # ═══════════════════════════════════════════════════════════════
    # 7. BULK API v2 QUERY — /services/data/:version/jobs/query[/...]
    # ═══════════════════════════════════════════════════════════════
    path(f'services/data/{V}/jobs/query/<str:job_id>/results',
         bulk_v2_query_views.get_query_results),
    path(f'services/data/{V}/jobs/query/<str:job_id>',
         bulk_v2_query_views.query_job_detail),
    path(f'services/data/{V}/jobs/query',
         bulk_v2_query_views.query_job_list),

    # ═══════════════════════════════════════════════════════════════
    # 8. WAVE ANALYTICS — /services/data/:version/wave/[...]
    # ═══════════════════════════════════════════════════════════════
    path(f'services/data/{V}/wave/datasets/<str:dataset_id>/versions',
         wave_views.list_dataset_versions),
    path(f'services/data/{V}/wave/datasets/<str:dataset_id>',
         wave_views.get_dataset),
    path(f'services/data/{V}/wave/datasets',
         wave_views.list_datasets),
    path(f'services/data/{V}/wave/query',
         wave_views.wave_query),

    # ═══════════════════════════════════════════════════════════════
    # 9. COMETD — /cometd/:version
    # ═══════════════════════════════════════════════════════════════
    path(f'cometd/{V}', event_views.cometd_handler),

    # ═══════════════════════════════════════════════════════════════
    # 10. ADMIN + HEALTH — Last
    # ═══════════════════════════════════════════════════════════════
    path('__admin/db/<str:object_name>', admin_views.admin_db_object),
    path('__admin/db', admin_views.admin_db),
    path('__admin/reset', admin_views.admin_reset),
    path('__admin/schemas', admin_views.admin_schemas),
    path('__admin/bulk-jobs', admin_views.admin_bulk_jobs),
    path('__admin/events', admin_views.admin_events),
    path('__admin/streaming-clients', admin_views.admin_streaming_clients),
    path('__admin/health', admin_views.admin_health),
    path('health', admin_views.health),

    # Root URL — landing page with available endpoints
    path('', admin_views.root_index),
]
