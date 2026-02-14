"""
Django App Configuration
========================
Port of: server.js lines 66-91 (schema loading at startup)

Standard Django AppConfig that loads JSON schema files into the
in-memory database when the application starts.

This is the Django-conventional way to run startup logic:
  settings.py registers the app in INSTALLED_APPS →
  Django calls AppConfig.ready() once during initialization →
  Schemas are loaded and database is initialized.
"""
import json
import os
import logging
from pathlib import Path

from django.apps import AppConfig

logger = logging.getLogger('salesforce_mock')


class SalesforceMockConfig(AppConfig):
    """
    Django AppConfig for the Salesforce Mock API Server.

    The ready() method loads all JSON schema files from SCHEMA_DIR
    into the shared schemas and database singletons. This runs once
    at startup, before any HTTP requests are processed.
    """
    name = 'salesforce_mock'
    default_auto_field = 'django.db.models.BigAutoField'

    def ready(self):
        """Load all JSON schema files on application startup."""
        from salesforce_mock.state.database import schemas, database

        # Guard against double-loading (Django can call ready() twice in dev)
        if len(schemas) > 0:
            return

        schema_dir = os.environ.get('SCHEMA_DIR', '/app/schemas')

        print('=' * 52)
        print('  Salesforce Mock API Server - Loading Schemas')
        print('=' * 52)

        schema_path = Path(schema_dir)
        if schema_path.exists():
            for file in sorted(schema_path.glob('*.json')):
                try:
                    with open(file, 'r') as f:
                        schema = json.load(f)
                    name = schema['name']
                    schemas[name] = schema
                    database[name] = []
                    field_count = len(schema.get('fields', {}))
                    print(f'  Loaded: {name} '
                          f'(prefix: {schema.get("idPrefix", "???")}, '
                          f'fields: {field_count})')
                except Exception as e:
                    print(f'  Failed to load {file.name}: {e}')
        else:
            print(f'  Schema directory not found: {schema_dir}')

        print(f'  Total objects: {len(schemas)}')
        print('=' * 52)
        print()
