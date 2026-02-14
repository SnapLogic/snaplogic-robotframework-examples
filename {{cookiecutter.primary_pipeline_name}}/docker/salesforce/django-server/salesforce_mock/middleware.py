"""
Django Middleware — replaces Express middleware chain.

Provides:
  - CORS support (matching WireMock --enable-stub-cors)
  - Raw body preservation for CSV/XML content types
  - Request logging
  - Global error handling
"""
import json
import logging
import traceback
from datetime import datetime, timezone

from django.http import JsonResponse

logger = logging.getLogger('salesforce_mock')


class TrailingSlashMiddleware:
    """
    Strips trailing slashes from URL paths before routing.

    Express.js ignores trailing slashes by default (/query and /query/ match
    the same route). Django does NOT — it treats them as different URLs.
    SnapLogic sends some requests with trailing slashes (e.g., /query/?q=...)
    that would 404 without this middleware.

    Must be placed BEFORE django.middleware.common.CommonMiddleware in the
    middleware chain to prevent Django's APPEND_SLASH logic from interfering.
    """

    def __init__(self, get_response):
        self.get_response = get_response

    def __call__(self, request):
        # Strip trailing slash from path (but not for root path '/')
        if request.path != '/' and request.path.endswith('/'):
            request.path_info = request.path_info.rstrip('/')
            request.path = request.path.rstrip('/')
        return self.get_response(request)


class CORSMiddleware:
    """
    CORS middleware — matches the Express cors() middleware in server.js.
    Adds Access-Control-Allow-* headers to all responses.
    Handles OPTIONS preflight requests.
    """

    def __init__(self, get_response):
        self.get_response = get_response

    def __call__(self, request):
        # Handle OPTIONS preflight
        if request.method == 'OPTIONS':
            response = JsonResponse({}, status=200)
        else:
            response = self.get_response(request)

        response['Access-Control-Allow-Origin'] = '*'
        response['Access-Control-Allow-Methods'] = 'GET, POST, PATCH, DELETE, PUT, OPTIONS'
        response['Access-Control-Allow-Headers'] = 'Content-Type, Authorization, X-SFDC-Session'
        return response


class RawBodyMiddleware:
    """
    Preserves raw request body for CSV and XML content types.
    Django normally parses request.body only for form data.
    For CSV/XML, we need the raw text content.
    """

    def __init__(self, get_response):
        self.get_response = get_response

    def __call__(self, request):
        # Store raw body as text for CSV and XML content types
        content_type = request.content_type or ''
        if any(ct in content_type for ct in ['text/csv', 'application/xml', 'text/xml']):
            request.raw_body = request.body.decode('utf-8')
        return self.get_response(request)


class RequestLoggingMiddleware:
    """
    Request logging — matches the Express logging middleware in server.js.
    Logs: [timestamp] METHOD /path
    """

    def __init__(self, get_response):
        self.get_response = get_response

    def __call__(self, request):
        timestamp = datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%S')
        logger.info(f'[{timestamp}] {request.method} {request.get_full_path()}')
        return self.get_response(request)


class ErrorHandlerMiddleware:
    """
    Global error handler — matches the Express error middleware in routes.js.
    Catches unhandled exceptions and returns Salesforce-format error responses.
    """

    def __init__(self, get_response):
        self.get_response = get_response

    def __call__(self, request):
        return self.get_response(request)

    def process_exception(self, request, exception):
        logger.error(f'  Error: {str(exception)}')
        logger.error(traceback.format_exc())
        return JsonResponse(
            [{'message': str(exception), 'errorCode': 'UNKNOWN_EXCEPTION', 'fields': []}],
            safe=False,
            status=500
        )
