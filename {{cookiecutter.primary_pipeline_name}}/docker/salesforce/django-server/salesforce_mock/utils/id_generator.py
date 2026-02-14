"""
Salesforce ID Generator
=======================
Port of: lib/id-generator.js

Generates 18-character IDs matching Salesforce format:
  - First 3 chars: Object key prefix (e.g., 001 for Account, 003 for Contact)
  - Next 15 chars: Random alphanumeric (uppercase)
"""
import random
import string

ID_CHARS = string.ascii_uppercase + string.digits


def generate_id(prefix):
    """
    Generate a Salesforce-style 18-character ID.

    Args:
        prefix: 3-character object key prefix (e.g., "001", "003", "00Q")

    Returns:
        18-character Salesforce-style ID string
    """
    return prefix + ''.join(random.choice(ID_CHARS) for _ in range(15))
