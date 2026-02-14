"""
In-Memory Database
==================
Port of: the database/schemas objects from server.js

Module-level dict singletons imported by all views.
All data is lost on restart (by design for clean tests).
"""

# Schema definitions loaded from JSON files
# { 'Account': { name, idPrefix, fields: {...} }, 'Contact': {...}, ... }
schemas = {}

# In-memory record storage
# { 'Account': [record1, record2, ...], 'Contact': [...], ... }
database = {}


def reset_all():
    """Clear all records, preserve schema definitions."""
    total = 0
    for name in database:
        total += len(database[name])
        database[name] = []
    return total
