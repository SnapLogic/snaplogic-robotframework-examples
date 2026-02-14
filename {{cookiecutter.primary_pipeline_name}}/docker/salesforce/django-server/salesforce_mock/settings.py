"""
Django settings for Salesforce Mock API Server.

Minimal configuration — no database, no auth, no admin.
Pure lightweight API server for mocking Salesforce.
"""
import os

# Security
SECRET_KEY = 'salesforce-mock-server-not-for-production'
DEBUG = os.environ.get('DEBUG', 'false').lower() == 'true'
ALLOWED_HOSTS = ['*']

# Application definition — only our mock API app (no contrib apps needed)
INSTALLED_APPS = [
    'salesforce_mock.apps.SalesforceMockConfig',
]

MIDDLEWARE = [
    'salesforce_mock.middleware.TrailingSlashMiddleware',  # Strip trailing slashes (Express compat)
    'salesforce_mock.middleware.CORSMiddleware',
    'salesforce_mock.middleware.RawBodyMiddleware',
    'salesforce_mock.middleware.RequestLoggingMiddleware',
    'django.middleware.common.CommonMiddleware',
    'salesforce_mock.middleware.ErrorHandlerMiddleware',
]

ROOT_URLCONF = 'salesforce_mock.urls'

# No database — all data stored in-memory dicts
DATABASES = {}

# No templates needed
TEMPLATES = []

WSGI_APPLICATION = 'salesforce_mock.wsgi.application'

# Body parser limits (matching Express: 50mb)
DATA_UPLOAD_MAX_MEMORY_SIZE = 50 * 1024 * 1024  # 50MB
FILE_UPLOAD_MAX_MEMORY_SIZE = 50 * 1024 * 1024  # 50MB

# Server configuration (matching Node.js env vars)
HTTP_PORT = int(os.environ.get('HTTP_PORT', '8080'))
HTTPS_PORT = int(os.environ.get('HTTPS_PORT', '8443'))
SCHEMA_DIR = os.environ.get('SCHEMA_DIR', '/app/schemas')
P12_FILE = os.environ.get('P12_FILE', '/app/certs/custom-keystore.p12')
P12_PASSWORD = os.environ.get('P12_PASSWORD', 'password')

# Disable Django's CSRF (this is a mock API server)
CSRF_COOKIE_SECURE = False
APPEND_SLASH = False

# Logging
LOGGING = {
    'version': 1,
    'disable_existing_loggers': False,
    'formatters': {
        'simple': {
            'format': '[%(asctime)s] %(message)s',
            'datefmt': '%Y-%m-%dT%H:%M:%S',
        },
    },
    'handlers': {
        'console': {
            'class': 'logging.StreamHandler',
            'formatter': 'simple',
        },
    },
    'loggers': {
        'salesforce_mock': {
            'handlers': ['console'],
            'level': 'INFO',
        },
    },
}
