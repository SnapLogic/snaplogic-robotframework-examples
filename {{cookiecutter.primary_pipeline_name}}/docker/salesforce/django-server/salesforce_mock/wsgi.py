"""
WSGI config for Salesforce Mock API Server.

Schema loading happens automatically via AppConfig.ready()
when Django initializes the 'salesforce_mock' app.
"""
import os
from django.core.wsgi import get_wsgi_application

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'salesforce_mock.settings')

application = get_wsgi_application()
