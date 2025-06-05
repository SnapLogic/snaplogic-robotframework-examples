# SnapLogic Common Robot Library Guide

## Table of Contents

1. [Overview](#overview)
2. [Library Distribution](#library-distribution)
3. [Installation Process](#installation-process)
4. [Library Structure and Documentation](#library-structure-and-documentation)
5. [Local Exploration Setup](#local-exploration-setup)
6. [Exploring Keywords and Documentation](#exploring-keywords-and-documentation)
7. [Usage in Test Framework](#usage-in-test-framework)
8. [Best Practices](#best-practices)

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
snaplogic-common-robot/
├── .gitignore
├── .pre-commit-config.yaml
├── .travis.yml
├── Makefile
├── pyproject.toml
├── snaplogic_common_robot.Dockerfile
├── entrypoint.sh
├── scripts/
│   ├── delete_old_package_versions.sh
│   ├── generate_calver.py
│   ├── generate_libdoc.sh
│   └── upload_lib_docs_to_s3.py
├── meta-data/
├── dist/
└── src/
    ├── requirements.txt
    ├── snaplogic_common_robot/
    │   ├── __init__.py
    │   ├── libdocs/
    │   │   ├── __init__.py
    │   │   ├── robot-doc-styles.css
    │   │   └── test.txt
    │   ├── libraries/
    │   │   ├── __init__.py
    │   │   └── utils.py
    │   ├── snaplogic_apis_keywords/
    │   │   ├── __init__.py
    │   │   ├── snaplogic_apis.resource      # SnapLogic API resource file
    │   │   └── snaplogic_keywords.resource  # Main keyword resource file
    │   └── test_data/
    │       ├── __init__.py
    │       ├── slim_groundplex.json
    │       └── triggered_task.json
    ├── slim_common_robot/
    │   └── libdocs/
    │       └── __init__.py
    └── testresults/
        └── libdoc/
            ├── index.html
            ├── raw_snaplogic_apis.html
            ├── raw_snaplogic_keywords.html
            ├── robot-doc-styles.css
            ├── snaplogic_apis.html
            └── snaplogic_keywords.html
```

### Embedded Documentation

The library includes comprehensive documentation that is packaged with the installation:

#### 1. Keyword Documentation (LibDoc)
```bash
# Generated Robot Framework keyword documentation
snaplogic-common-robot/src/testresults/libdoc/index.html
snaplogic-common-robot/src/testresults/libdoc/snaplogic_keywords.html
snaplogic-common-robot/src/testresults/libdoc/snaplogic_apis.html
```


#### 2. Resource Files Documentation
```robot
# All keywords include detailed documentation in resource files
# snaplogic_keywords.resource - Main keyword resource file
# snaplogic_apis.resource - SnapLogic API resource file

# Example keyword documentation structure:
# Create Account From Template
#     [Documentation]    Creates a SnapLogic account from a JSON template file.
#     [Arguments]    ${template_path}
#     ...
```

## Local Exploration Setup

To explore the **snaplogic_common_robot** library locally, you can install the package for inspection and testing.

### Why Local Exploration?

- **Keyword Discovery** - Browse available keywords and their documentation
- **Testing Keywords** - Test individual keywords in isolation
- **Documentation Review** - Access embedded documentation and examples
- **Development** - Develop new tests using the library
- **Debugging** - Understand keyword implementation for troubleshooting

### Quick Installation

```bash
# Install snaplogic-common-robot (automatically installs all dependencies)
pip install snaplogic-common-robot

# Verify installation
pip show snaplogic-common-robot

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


### 3. Explore Test Data and Examples

```bash
# View test data templates included in the package
cd src/snaplogic_common_robot/test_data/

# View example JSON templates
cat slim_groundplex.json
cat triggered_task.json
```

## Usage in Test Framework

### Add the keywords path as resource

```robot
*** Settings ***

Resource    snaplogic_common_robot/snaplogic_apis_keywords/snaplogic_keywords.resource
Resource    snaplogic_common_robot/snaplogic_apis_keywords/snaplogic_apis.resource

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

7. **Utility Functions**
   - File and JSON handling utilities
   - Template processing functions
   - Data validation helpers


### Troubleshooting

```bash
# Check library installation
pip show snaplogic-common-robot

# Verify keyword availability
python -m robot.libdoc snaplogic_common_robot.snaplogic_apis_keywords.snaplogic_keywords list
python -m robot.libdoc snaplogic_common_robot.snaplogic_apis_keywords.snaplogic_apis list

# View generated documentation
open src/testresults/libdoc/index.html




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

**Build and Package Management**: pyproject.toml configuration, automated version generation, Docker containerization

By installing the library locally, you can explore all available keywords and bundled libraries for comprehensive SnapLogic automation testing.

---

*The snaplogic_common_robot library is the foundation for consistent, maintainable SnapLogic automation testing across all projects and environments.*