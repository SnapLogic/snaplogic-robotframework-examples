"""
Robot Framework Library Loader for JMS Libraries
This file provides a more robust way to load the JMS libraries
"""

import sys
import os

# Add the directory containing this file to Python path
current_dir = os.path.dirname(os.path.abspath(__file__))
if current_dir not in sys.path:
    sys.path.insert(0, current_dir)

# Try to import the libraries
try:
    from robot_stomp_wrapper import robot_stomp_wrapper
    from cleanup_library_definitions import cleanup_library_definitions
    LIBRARIES_AVAILABLE = True
except ImportError as e:
    print(f"Warning: Could not import JMS libraries: {e}")
    LIBRARIES_AVAILABLE = False

# Export the libraries
__all__ = ['robot_stomp_wrapper', 'cleanup_library_definitions', 'LIBRARIES_AVAILABLE']

def get_robot_stomp_wrapper(*args, **kwargs):
    """Factory function to create robot_stomp_wrapper instance"""
    if LIBRARIES_AVAILABLE:
        return robot_stomp_wrapper(*args, **kwargs)
    else:
        raise ImportError("JMS libraries not available. Please install stomp-py: pip install stomp-py")

def get_cleanup_library_definitions(*args, **kwargs):
    """Factory function to create cleanup_library_definitions instance"""
    if LIBRARIES_AVAILABLE:
        return cleanup_library_definitions(*args, **kwargs)
    else:
        # This one has fallback, so it might still work
        from cleanup_library_definitions import cleanup_library_definitions
        return cleanup_library_definitions(*args, **kwargs)
