# SnapLogic Common Robot Library Guide

## Table of Contents

1. [Overview](#overview)
2. [Library Distribution](#library-distribution)
3. [Installation Process](#installation-process)
4. [Library Structure and Documentation](#library-structure-and-documentation)
5. [Local Exploration Setup](#local-exploration-setup)
6. [Creating Virtual Environment](#creating-virtual-environment)
7. [Exploring Keywords and Documentation](#exploring-keywords-and-documentation)
8. [Usage in Test Framework](#usage-in-test-framework)
9. [Best Practices](#best-practices)

## Overview

**snaplogic_common_robot** is a custom Robot Framework library that provides reusable keywords and utilities specifically designed for SnapLogic automation testing. This library encapsulates common SnapLogic operations, API interactions, and testing patterns into convenient Robot Framework keywords.

### Key Features

- **SnapLogic API Integration** - Keywords for SnapLogic REST API operations
- **Pipeline Management** - Keywords for pipeline import, export, and execution
- **Account Management** - Keywords for creating and managing SnapLogic accounts
- **Project Operations** - Keywords for project space and project management
- **Groundplex Operations** - Keywords for Groundplex creation and management
- **Embedded Documentation** - Complete keyword documentation included in the package
- **Reusable Components** - Common testing patterns abstracted into keywords

### Library Benefits

- **Consistency** - Standardized approach to SnapLogic testing across projects
- **Productivity** - Pre-built keywords reduce test development time
- **Maintainability** - Centralized library simplifies updates and bug fixes
- **Documentation** - Built-in keyword documentation and examples
- **Version Control** - Semantic versioning for stable releases
- **Rich Dependencies** - Includes comprehensive set of testing libraries automatically

## Library Distribution

### PyPI Publication

The **snaplogic_common_robot** library is published to a PyPI server, making it easily installable and distributable:

```bash
# Library is available on PyPI server
Package Name: snaplogic-common-robot
Distribution: Python Package Index (PyPI)
Format: Python Wheel (.whl) and Source Distribution (.tar.gz)
```




### Bundled Dependencies

When you install snaplogic-common-robot, the following libraries are automatically installed:

#### Core Robot Framework Libraries
- robotframework
- robotframework-requests
- robotframework-docker
- robotframework-databaselibrary
- robotframework-jsonlibrary
- robotframework-robocop
- robotframework-tidy
- robotframework-dependencylibrary

#### Data Processing Libraries
- envyaml
- deepdiff
- pyyaml
- jinja2
- tabulate
- pymongo

#### Cloud and Infrastructure Tools
- awscli
- boto3

#### Development and Build Tools
- cookiecutter
- twine
- build
- python-dotenv

## Installation Process

### Installation via requirements.txt

The library is installed automatically as part of the Docker container build process. When you install snaplogic-common-robot, it automatically installs all its dependencies:

```txt
# requirements.txt
snaplogic-common-robot
# This single line automatically installs 20+ packages
```

### Container Build Integration

```dockerfile
# robot.Dockerfile
FROM python:3.11-slim

# Set the working directory
WORKDIR /app
# Copy the requirements file and install dependencies
COPY requirements.txt . 
RUN pip install --no-cache-dir --index-url https://pypi.org/simple -r requirements.txt

# The snaplogic-common-robot library is now available
```

### Manual Installation

For local development or exploration:

```bash
# Install from PyPI (includes ALL dependencies automatically)
pip install snaplogic-common-robot

# Install specific version
pip install snaplogic-common-robot==1.2.3
```

### Verification

```bash
# Verify installation
pip list | grep snaplogic-common-robot

# Check installed version and dependencies
pip show snaplogic-common-robot
```

## Library Structure and Documentation

### Package Structure

```
snaplogic_common_robot/
├── __init__.py
├── snaplogic_apis_keywords/
│   ├── __init__.py
│   ├── snaplogic_keywords.resource     # Main keyword resource file
│   ├── api_client.py                   # SnapLogic API client
│   ├── pipeline_keywords.py            # Pipeline-related keywords
│   ├── account_keywords.py             # Account management keywords
│   ├── project_keywords.py             # Project operations keywords
│   └── groundplex_keywords.py          # Groundplex management keywords
├── utilities/
│   ├── __init__.py
│   ├── json_utils.py                   # JSON manipulation utilities
│   ├── file_utils.py                   # File operation utilities
│   └── validation_utils.py             # Data validation utilities
├── docs/
│   ├── keywords.html                   # Generated keyword documentation
│   ├── examples/                       # Usage examples
│   └── api_reference.md               # API reference guide
└── tests/
    ├── unit_tests/                     # Unit tests for library
    └── integration_tests/              # Integration tests
```

### Embedded Documentation

The library includes comprehensive documentation that is packaged with the installation:

#### 1. Keyword Documentation (LibDoc)
```bash
# Generated Robot Framework keyword documentation
snaplogic-common-robot/src/snaplogic_common_robot/libdocs/index.html
```


#### 2. Inline Documentation
```python
# All keywords include detailed docstrings
def create_snaplogic_account(self, account_name, account_type, settings):
    """Creates a SnapLogic account with specified settings.
    
    Arguments:
    - account_name: Name for the new account
    - account_type: Type of account (e.g., 'oracle', 's3')
    - settings: Dictionary of account configuration settings
    
    Returns:
    - account_id: Unique identifier of created account
    
    Example:
    | Create SnapLogic Account | MyOracleDB | oracle | ${oracle_settings} |
    """
```

## Local Exploration Setup

To explore the **snaplogic_common_robot** library locally, you can set up a virtual environment and install the package for inspection and testing.

### Why Local Exploration?

- **Keyword Discovery** - Browse available keywords and their documentation
- **Testing Keywords** - Test individual keywords in isolation
- **Documentation Review** - Access embedded documentation and examples
- **Development** - Develop new tests using the library
- **Debugging** - Understand keyword implementation for troubleshooting

## Creating Virtual Environment

### Step-by-Step Virtual Environment Setup

#### Method 1: Using venv (Recommended)

```bash
# 1. Navigate to your project directory
cd /path/to/your/project

# 2. Create virtual environment
python -m venv snaplogic_robot_env

# 3. Activate virtual environment
# On macOS/Linux:
source snaplogic_robot_env/bin/activate

# On Windows:
snaplogic_robot_env\Scripts\activate

# 4. Verify activation (should show virtual env path)
which python
# Expected: /path/to/your/project/snaplogic_robot_env/bin/python
```



### Install Required Packages

```bash
# With virtual environment activated

# 1. Upgrade pip
pip install --upgrade pip

# 2. Install snaplogic-common-robot (automatically installs all dependencies)
pip install snaplogic-common-robot

# 3. Verify installation
pip list
```

### Verify Setup

```bash
# Check Robot Framework installation
robot --version

# Check snaplogic-common-robot installation
python -c "import snaplogic_common_robot; print('SnapLogic library installed successfully')"
```

## Exploring Keywords and Documentation



### 1. List Available Keywords

```bash
# List all keywords in the library
python -m robot.libdoc snaplogic_common_robot list

# Get specific keyword information
python -m robot.libdoc snaplogic_common_robot show "Create Snaplex"
```


### 2. Create Test Robot File

Create a simple Robot file to test keywords:

```robot
# test_exploration.robot
*** Settings ***
Library    snaplogic_common_robot.snaplogic_apis_keywords.snaplogic_keywords

*** Test Cases ***
Explore SnapLogic Keywords
    [Documentation]    Test basic SnapLogic library functionality
    Log    Testing SnapLogic Common Robot Library
    Log    SnapLogic library keywords are available
```

Run the test:
```bash
make robot-run-tests TAGS=oracle # Mutiple tags can be added
```


### 3. Explore Keyword Examples

```bash
# If examples are included in the package
cd snaplogic_common_robot/docs/examples/

# View example Robot files
cat pipeline_examples.robot
cat account_examples.robot
```

## Usage in Test Framework

### Add the keywords path as resource

```robot
*** Settings ***

Resource    snaplogic_common_robot/snaplogic_apis_keywords/snaplogic_keywords.resource

```

### Example Keyword Usage

```robot
*** Test Cases ***
Create And Configure Account
    [Documentation]    Example of using snaplogic-common-robot keywords
    
    # Use keywords from the library
    Create Account From Template    ${account_payload_path}/acc_oracle.json
    
    Import Pipelines From Template    ${unique_id}    ${pipeline_file_path}    ${pipeline_name}    ${pipeline_name_slp}
    
    Create Triggered Task From Template
    ...    ${unique_id}
    ...    ${project_path}
    ...    ${pipeline_name}
    ...    ${task_name}
    ...    ${task_params}
    ...    ${task_notifications}
```

### Available Keyword Categories

1. **Authentication Keywords**
   - Set Up SnapLogic Connection
   - Authenticate User
   - Get Auth Token

2. **Project Management Keywords**
   - Create Project Space
   - Delete Project Space
   - Create Project
   - Get Project Details

3. **Account Management Keywords**
   - Create Account From Template
   - Update Account Settings
   - Delete Account
   - Validate Account

4. **Pipeline Keywords**
   - Import Pipelines From Template
   - Export Pipeline
   - Validate Pipeline
   - Execute Pipeline

5. **Groundplex Keywords**
   - Create Snaplex
   - Download Config File
   - Check Snaplex Status
   - Delete Snaplex

6. **Task Management Keywords**
   - Create Triggered Task From Template
   - Run Triggered Task
   - Get Task Status
   - Update Task Parameters


###  Troubleshooting

```bash
# Check library installation
pip show snaplogic-common-robot

# Verify keyword availability
python -m robot.libdoc snaplogic_common_robot list




## Summary

The **snaplogic_common_robot** library provides a comprehensive set of Robot Framework keywords specifically designed for SnapLogic automation testing. Key points:

- **Distributed via PyPI** for easy installation and version management
- **Comprehensive Dependencies** - Single install brings 20+ testing libraries automatically
- **Installed automatically** through requirements.txt in the Docker container
- **Includes embedded documentation** with keywords, examples, and API references
- **Easily explorable locally** using virtual environments
- **Complete Testing Ecosystem** - Includes Robot Framework extensions,  data processing libraries, and development utilities

### Key Dependencies Included

**Core Testing**: robotframework, robotframework-requests, robotframework-jsonlibrary, robotframework-databaselibrary, robotframework-docker

**Cloud Integration**: boto3, awscli

**Data Processing**: pyyaml, jinja2, deepdiff, tabulate, pymongo

**Development Tools**: robotframework-robocop, robotframework-tidy, cookiecutter

By setting up a local virtual environment, you can explore all available keywords and bundled libraries for comprehensive SnapLogic automation testing.

---

*The snaplogic_common_robot library is the foundation for consistent, maintainable SnapLogic automation testing across all projects and environments.*