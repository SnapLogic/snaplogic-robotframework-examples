# Python to Robot Framework Keywords: Translation Rules and Guidelines

## Table of Contents
1. [Overview](#overview)
2. [Basic Translation Rules](#basic-translation-rules)
3. [What Becomes a Keyword](#what-becomes-a-keyword)
4. [What Does NOT Become a Keyword](#what-does-not-become-a-keyword)
5. [Naming Conventions](#naming-conventions)
6. [Library Types](#library-types)
7. [Controlling Keyword Creation](#controlling-keyword-creation)
8. [Best Practices](#best-practices)
9. [Common Pitfalls](#common-pitfalls)
10. [Examples](#examples)

---

## Overview

Robot Framework automatically converts Python methods into keywords through its library API. This transformation is NOT a Python feature but a Robot Framework capability that enables writing tests in natural language while using Python implementations.

## Basic Translation Rules

### The Core Process:
1. Robot Framework imports your Python library
2. Uses Python's introspection to examine the library
3. Filters methods based on visibility rules
4. Transforms method names to keyword names
5. Registers them in the keyword registry
6. Handles execution and argument passing

## What Becomes a Keyword

### ✅ Automatically Converted to Keywords:

#### 1. **Public Instance Methods**
```python
class MyLibrary:
    def do_something(self):  # ✅ Becomes "Do Something"
        pass
    
    def calculate_total(self, a, b):  # ✅ Becomes "Calculate Total"
        return a + b
```

#### 2. **Public Class Methods**
```python
class MyLibrary:
    @classmethod
    def get_instance_count(cls):  # ✅ Becomes "Get Instance Count"
        return cls.count
```

#### 3. **Module-Level Functions** (in module libraries)
```python
# my_library.py
def perform_action():  # ✅ Becomes "Perform Action"
    pass

def validate_input(value):  # ✅ Becomes "Validate Input"
    return bool(value)
```

#### 4. **Static Methods**
```python
class MyLibrary:
    @staticmethod
    def utility_function():  # ✅ Becomes "Utility Function"
        return "result"
```

## What Does NOT Become a Keyword

### ❌ NOT Converted to Keywords:

#### 1. **Private Methods** (starting with underscore)
```python
class MyLibrary:
    def _internal_helper(self):  # ❌ Private method
        pass
    
    def __double_underscore(self):  # ❌ Name mangled method
        pass
```

#### 2. **Special/Magic Methods**
```python
class MyLibrary:
    def __init__(self):  # ❌ Constructor
        pass
    
    def __str__(self):  # ❌ String representation
        return "MyLibrary"
    
    def __getattr__(self, name):  # ❌ Attribute access
        pass
```

#### 3. **Properties**
```python
class MyLibrary:
    @property
    def status(self):  # ❌ Property, not a method
        return self._status
    
    @status.setter
    def status(self, value):  # ❌ Setter
        self._status = value
```

#### 4. **Class Variables and Attributes**
```python
class MyLibrary:
    class_variable = "value"  # ❌ Class variable
    CONSTANT = 42  # ❌ Constant
    
    def __init__(self):
        self.instance_var = "data"  # ❌ Instance variable
```

#### 5. **Inherited Private Methods**
```python
class BaseLibrary:
    def _base_helper(self):  # ❌ Private in base class
        pass

class MyLibrary(BaseLibrary):
    pass  # _base_helper is NOT a keyword
```

## Naming Conventions

### Method Name → Keyword Name Translation

| Python Method Name | Robot Framework Keyword | Rule Applied |
|-------------------|------------------------|--------------|
| `do_something()` | `Do Something` | Underscores → spaces, Title case |
| `calculate_total_amount()` | `Calculate Total Amount` | Each word capitalized |
| `HTTPSConnection()` | `HTTPSConnection` | Preserves uppercase |
| `get_JSON_data()` | `Get JSON Data` | Mixed case preserved |
| `__init__()` | (not converted) | Special methods ignored |
| `_private_method()` | (not converted) | Private methods ignored |

### Special Cases:
```python
class MyLibrary:
    def runTest(self):  # Becomes "Run Test" (camelCase split)
        pass
    
    def IOError(self):  # Becomes "IOError" (uppercase preserved)
        pass
    
    def get_2fa_code(self):  # Becomes "Get 2fa Code"
        pass
```

## Library Types

### 1. **Class-Based Library** (Most Common)
```python
class MyLibrary:
    def keyword_one(self):
        pass
    
    def keyword_two(self, arg):
        pass
```

### 2. **Module-Based Library**
```python
# my_library.py
def keyword_one():
    pass

def keyword_two(arg):
    pass

# Variables in module libraries
ROBOT_LIBRARY_SCOPE = 'GLOBAL'  # Special variable
```

### 3. **Dynamic Library** (Advanced)
```python
class DynamicLibrary:
    def get_keyword_names(self):
        return ['Dynamic Keyword 1', 'Dynamic Keyword 2']
    
    def run_keyword(self, name, args):
        # Dynamic execution
        pass
```

### 4. **Hybrid Library**
```python
from robot.api.deco import keyword

class HybridLibrary:
    @keyword  # Explicitly marked
    def visible_keyword(self):
        pass
    
    def also_visible(self):  # Public = keyword
        pass
    
    def _not_visible(self):  # Private = not keyword
        pass
```

## Controlling Keyword Creation

### Using Robot Framework Decorators

#### 1. **@keyword - Custom Keyword Names**
```python
from robot.api.deco import keyword

class MyLibrary:
    @keyword("Execute Database Query")  # Custom name
    def db_query(self, sql):
        pass
    
    @keyword(name="Click Button", tags=["UI", "interaction"])
    def perform_click(self, locator):
        pass
```

#### 2. **@not_keyword - Exclude Public Methods**
```python
from robot.api.deco import not_keyword

class MyLibrary:
    @not_keyword  # Won't become a keyword despite being public
    def utility_method(self):
        pass
    
    def normal_keyword(self):  # Will become a keyword
        pass
```

#### 3. **Library Scope Configuration**
```python
from robot.api.deco import library

@library(scope='GLOBAL', version='1.0.0', doc_format='ROBOT')
class MyLibrary:
    """Library documentation"""
    pass
```

### Library Scope Options:
- `GLOBAL`: Single instance for all tests
- `SUITE`: New instance per test suite
- `TEST`: New instance per test case

## Best Practices

### 1. **Clear, Descriptive Names**
```python
# Good ✅
def validate_email_address(self, email):
    pass

def create_user_account(self, username, password):
    pass

# Avoid ❌
def do_it(self, x):
    pass

def process(self, data):
    pass
```

### 2. **Consistent Naming Convention**
```python
class MyLibrary:
    # Pick one style and stick to it
    def get_user_name(self):  # snake_case
        pass
    
    def get_user_email(self):  # consistent with above
        pass
    
    # Don't mix styles in the same library
    def getUserPhone(self):  # ❌ Avoid mixing camelCase
        pass
```

### 3. **Proper Documentation**
```python
def send_email(self, recipient, subject, body, attachments=None):
    """Send an email message.
    
    Arguments:
    - recipient: Email address of the recipient
    - subject: Email subject line
    - body: Email body content
    - attachments: Optional list of file paths to attach
    
    Example:
    | Send Email | user@example.com | Test Subject | Hello World |
    
    Returns:
    Message ID of the sent email
    """
    pass
```

### 4. **Use Type Hints** (Python 3.5+)
```python
from typing import List, Optional, Dict

class MyLibrary:
    def process_data(self, 
                    data: Dict[str, any],
                    filters: Optional[List[str]] = None) -> Dict:
        """Process data with optional filters."""
        pass
```

### 5. **Hide Implementation Details**
```python
class MyLibrary:
    def public_keyword(self):
        """This becomes a keyword."""
        result = self._complex_calculation()
        return self._format_output(result)
    
    def _complex_calculation(self):
        """Hidden from Robot Framework."""
        pass
    
    def _format_output(self, data):
        """Also hidden."""
        pass
```

## Common Pitfalls

### 1. **Forgetting About Private Methods**
```python
class MyLibrary:
    def setup_connection(self):
        self._connect()  # ❌ This will fail in RF if _connect is needed as keyword
    
    def _connect(self):  # This is NOT available as a keyword
        pass
```

### 2. **Naming Conflicts**
```python
class MyLibrary:
    def get_status(self):  # Becomes "Get Status"
        pass
    
    def get_Status(self):  # Also becomes "Get Status" - CONFLICT!
        pass
```

### 3. **Return Value Confusion**
```python
class MyLibrary:
    @property
    def current_value(self):  # ❌ Properties don't become keywords
        return self._value
    
    def get_current_value(self):  # ✅ This becomes a keyword
        return self._value
```

### 4. **Import Issues**
```python
# Wrong ❌
class _InternalLibrary:  # Class starting with _ won't be found
    def keyword(self):
        pass

# Right ✅
class PublicLibrary:
    def keyword(self):
        pass
```

## Examples

### Complete Example Library
```python
from robot.api.deco import keyword, not_keyword, library
from robot.api import logger
from typing import Optional, List, Dict

@library(scope='SUITE', version='1.0.0')
class ExampleLibrary:
    """Example library demonstrating keyword creation rules.
    
    This library shows various ways methods become keywords.
    """
    
    def __init__(self):
        """Constructor - NOT a keyword."""
        self._connection = None
        self.counter = 0
    
    # Standard keyword - automatic conversion
    def connect_to_server(self, host: str, port: int = 8080) -> bool:
        """Connect to a server.
        
        Arguments:
        - host: Server hostname or IP
        - port: Server port (default: 8080)
        
        Example:
        | Connect To Server | example.com | 443 |
        """
        logger.info(f"Connecting to {host}:{port}")
        self._connection = f"{host}:{port}"
        return True
    
    # Custom keyword name
    @keyword("Verify Connection Active")
    def check_connection(self) -> bool:
        """Verify that connection is active."""
        return self._connection is not None
    
    # Method with complex arguments
    def send_data(self, 
                  data: Dict[str, any],
                  headers: Optional[Dict[str, str]] = None,
                  timeout: float = 30.0) -> Dict:
        """Send data to the connected server.
        
        Arguments:
        - data: Dictionary of data to send
        - headers: Optional HTTP headers
        - timeout: Request timeout in seconds
        
        Returns:
        Response dictionary
        """
        self.counter += 1
        return {"status": "sent", "count": self.counter}
    
    # Not a keyword despite being public
    @not_keyword
    def internal_validation(self, data):
        """This won't be available as a keyword."""
        return bool(data)
    
    # Private method - not a keyword
    def _establish_connection(self, host, port):
        """Private method - not exposed to Robot Framework."""
        pass
    
    # Property - not a keyword
    @property
    def connection_string(self):
        """Property - not a keyword."""
        return self._connection
    
    # Static method - becomes a keyword
    @staticmethod
    def calculate_checksum(data: str) -> int:
        """Calculate checksum for data.
        
        This is a static method that becomes a keyword.
        """
        return sum(ord(c) for c in data)
    
    # Class method - becomes a keyword
    @classmethod
    def get_library_info(cls) -> Dict:
        """Get library information.
        
        Returns library metadata as a dictionary.
        """
        return {
            "name": cls.__name__,
            "version": "1.0.0",
            "scope": "SUITE"
        }
```

### Using the Library in Robot Framework
```robot
*** Settings ***
Library    ExampleLibrary

*** Test Cases ***
Example Test
    # Using automatic keyword names
    Connect To Server    example.com    443
    
    # Using custom keyword name
    Verify Connection Active
    
    # Using keyword with complex arguments
    &{data}=    Create Dictionary    key=value    foo=bar
    &{headers}=    Create Dictionary    Content-Type=application/json
    ${response}=    Send Data    ${data}    headers=${headers}    timeout=60
    
    # Using static method keyword
    ${checksum}=    Calculate Checksum    test data
    
    # Using class method keyword
    ${info}=    Get Library Info
    
    # Note: These would FAIL - not available as keywords:
    # Internal Validation    ${data}  # Marked with @not_keyword
    # Establish Connection    # Private method
    # Connection String    # Property, not method
```

## Summary

The transformation from Python methods to Robot Framework keywords follows clear rules:
1. **Public visibility** is required (no underscore prefix)
2. **Method names** are transformed (underscores to spaces, title case)
3. **Special methods** are excluded (__init__, __str__, etc.)
4. **Properties** don't become keywords
5. **Control** is available via decorators (@keyword, @not_keyword)

This system allows writing natural language tests while maintaining clean Python implementation code.
