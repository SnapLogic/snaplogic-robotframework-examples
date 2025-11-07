# Test Data Management Guide
*Best Practices, Conventions, and Implementation Strategies for SnapLogic Robot Framework Testing*

## Overview

Effective test data management is crucial for reliable, maintainable automated testing. This guide provides comprehensive strategies for organizing, loading, and managing test data in the SnapLogic Robot Framework environment, with practical examples and established conventions.

## Table of Contents

1. [Test Data Management Philosophy](#test-data-management-philosophy)
2. [Repository Structure Conventions](#repository-structure-conventions)
3. [Data File Organization](#data-file-organization)
4. [Loading CSV Test Data](#loading-csv-test-data)
5. [Loading JSON Test Data](#loading-json-test-data)
6. [Database Test Data Strategies](#database-test-data-strategies)
7. [Environment-Specific Data Management](#environment-specific-data-management)
8. [Data Validation and Integrity](#data-validation-and-integrity)
9. [Test Data Lifecycle Management](#test-data-lifecycle-management)
10. [Advanced Data Management Patterns](#advanced-data-management-patterns)
11. [Troubleshooting Data Issues](#troubleshooting-data-issues)

## Test Data Management Philosophy

### 🎯 Core Principles

#### **1. Data Isolation**
- Each test suite maintains its own test data
- No shared data dependencies between tests
- Clean data state for every test execution

#### **2. Predictable Data**
- Consistent, known data sets for reliable assertions
- Version-controlled test data alongside code
- Reproducible test results across environments

#### **3. Realistic Data**
- Test data mirrors production data characteristics
- Realistic data volumes and complexity
- Edge cases and boundary conditions covered

#### **4. Maintainable Structure**
- Clear naming conventions and organization
- Self-documenting data files
- Easy to update and extend

### 🏗️ Data Management Strategy

```
Test Data Flow:
───────────────
Source Files → Data Loading → Database/Services → Pipeline Processing → Validation
     │              │                │                    │               │
  Repository     Robot Keywords    Mock Services      SnapLogic        Assertions
```

## Repository Structure Conventions

### 📁 Recommended Directory Structure

```
test/
├── suite/
│   ├── pipeline_tests/
│   │   ├── oracle_pipeline.robot
│   │   ├── postgres_to_s3.robot
│   │   └── minio_integration.robot
│   │
│   └── test_data/                          # Central test data directory
│       ├── accounts_payload/               # SnapLogic account configurations
│       │   ├── acc_oracle.json
│       │   ├── acc_postgres.json
│       │   └── acc_s3.json
│       │
│       ├── actual_expected_data/           # Input/output data for validation
│       │   ├── input_data/                 # Source test files
│       │   │   ├── employees.csv
│       │   │   ├── employees.json
│       │   │   ├── customers.csv
│       │   │   └── orders.json
│       │   │
│       │   ├── expected_output/            # Expected pipeline results
│       │   │   ├── employees_processed.csv
│       │   │   ├── customer_summary.json
│       │   │   └── order_report.csv
│       │   │
│       │   └── actual_output/              # Generated test results (gitignored)
│       │       ├── employees_processed.csv
│       │       └── customer_summary.json
│       │
│       ├── datasets/                       # Reusable data sets
│       │   ├── small/                      # Small data sets (< 100 rows)
│       │   │   ├── employees_10.csv
│       │   │   └── customers_25.json
│       │   │
│       │   ├── medium/                     # Medium data sets (100-1000 rows)
│       │   │   ├── employees_500.csv
│       │   │   └── transactions_800.json
│       │   │
│       │   └── large/                      # Large data sets (> 1000 rows)
│       │       ├── employees_5000.csv
│       │       └── transactions_10000.json
│       │
│       ├── templates/                      # Data templates and generators
│       │   ├── employee_template.json
│       │   ├── customer_template.csv
│       │   └── data_generators.py
│       │
│       ├── queries/                        # SQL queries and database scripts
│       │   ├── setup_queries.sql
│       │   ├── teardown_queries.sql
│       │   └── validation_queries.sql
│       │
│       └── schemas/                        # Data schemas and validation
│           ├── employee_schema.json
│           ├── customer_schema.yaml
│           └── validation_rules.py
│
└── resources/                              # Shared resources and utilities
    ├── data_helpers.resource               # Data loading keywords
    ├── file_operations.resource            # File manipulation utilities
    └── validation_helpers.resource         # Data validation keywords
```

### 🏷️ Naming Conventions

#### **File Naming Standards**
```bash
# CSV Files
employees.csv                   # Basic entity data
employees_10.csv               # Size-specific data (10 rows)
employees_with_nulls.csv       # Data with special characteristics
employees_invalid.csv          # Invalid data for negative testing

# JSON Files
customers.json                 # Basic entity data
customers_nested.json         # Complex nested structures
customers_array.json          # Array-based data
customers_edge_cases.json     # Edge case scenarios

# SQL Files
setup_employees_table.sql     # Table creation scripts
insert_test_data.sql          # Data insertion scripts
cleanup_test_data.sql         # Cleanup scripts
validate_data_integrity.sql   # Validation queries
```

#### **Directory Naming Standards**
```bash
input_data/          # Source data files
expected_output/     # Expected pipeline results
actual_output/       # Generated test results
datasets/           # Reusable data collections
templates/          # Data generation templates
queries/            # SQL scripts and queries
schemas/            # Data structure definitions
```

### 📝 File Documentation Standards

#### **CSV File Headers**
```csv
# employees.csv - Test employee data for HR pipeline testing
# Created: 2025-01-20
# Rows: 4
# Purpose: Basic employee data with salary information
# Test Cases: salary_analysis.robot, employee_export.robot
name,role,salary,department
Alice,Manager,75000,Engineering
Bob,Developer,65000,Engineering
Charlie,Designer,60000,Marketing
Diana,QA Engineer,55000,Engineering
```

#### **JSON File Documentation**
```json
{
  "_metadata": {
    "description": "Customer data for CRM integration testing",
    "created": "2025-01-20",
    "record_count": 3,
    "purpose": "Customer demographics and purchase history",
    "test_cases": ["customer_import.robot", "crm_sync.robot"],
    "schema_version": "1.0"
  },
  "customers": [
    {
      "id": 1,
      "name": "John Doe",
      "email": "john.doe@example.com",
      "purchase_history": [
        {"item": "Widget A", "price": 29.99, "date": "2024-01-15"}
      ]
    }
  ]
}
```

## Data File Organization

### 📊 CSV Data Organization

#### **Standard CSV Structure**
```csv
# Basic structure with clear headers
id,name,role,salary,hire_date,active
1,Alice Johnson,Senior Manager,85000,2020-03-15,true
2,Bob Smith,Developer,70000,2021-06-01,true
3,Charlie Brown,Designer,65000,2022-01-10,true
4,Diana Wilson,QA Engineer,60000,2022-08-20,false
```

#### **CSV with Edge Cases**
```csv
# employees_edge_cases.csv - Testing data validation
id,name,role,salary,hire_date,active
1,Alice Johnson,Senior Manager,85000,2020-03-15,true
2,"Smith, Bob",Developer,70000,2021-06-01,true
3,Charlie "Chuck" Brown,Designer,,2022-01-10,
4,,QA Engineer,60000,,true
5,Diana Wilson,Senior "Data" Analyst,65000,invalid_date,false
```

#### **CSV Data Variations**
```bash
# Size-based variations
employees_5.csv      # Small dataset for quick tests
employees_100.csv    # Medium dataset for performance tests
employees_1000.csv   # Large dataset for stress tests

# Content-based variations
employees_all_valid.csv       # Clean, valid data
employees_with_nulls.csv      # Data with missing values
employees_duplicates.csv      # Data with duplicate records
employees_invalid.csv         # Data with validation errors
```

### 📋 JSON Data Organization

#### **Standard JSON Structure**
```json
{
  "employees": [
    {
      "id": 1,
      "personal_info": {
        "name": "Alice Johnson",
        "email": "alice.johnson@company.com",
        "hire_date": "2020-03-15"
      },
      "job_info": {
        "role": "Senior Manager",
        "department": "Engineering",
        "salary": 85000,
        "active": true
      },
      "contact": {
        "phone": "+1-555-0101",
        "address": {
          "street": "123 Main St",
          "city": "San Francisco",
          "state": "CA",
          "zip": "94102"
        }
      }
    }
  ]
}
```

#### **JSON Array Structure**
```json
[
  {
    "id": 1,
    "name": "Alice Johnson",
    "role": "Senior Manager",
    "salary": 85000
  },
  {
    "id": 2,
    "name": "Bob Smith", 
    "role": "Developer",
    "salary": 70000
  }
]
```

#### **JSON with Nested Complexity**
```json
{
  "company": {
    "name": "Tech Corp",
    "departments": [
      {
        "name": "Engineering",
        "employees": [
          {
            "id": 1,
            "name": "Alice Johnson",
            "projects": [
              {
                "name": "Project Alpha",
                "status": "active",
                "tasks": [
                  {"id": 1, "title": "Design API", "completed": true},
                  {"id": 2, "title": "Implement tests", "completed": false}
                ]
              }
            ]
          }
        ]
      }
    ]
  }
}
```

## Loading CSV Test Data

### 🔧 CSV Loading Keywords

#### **Basic CSV Loading Keyword**
```robot
*** Keywords ***
Load CSV Data Template
    [Documentation]    Loads CSV data into database with automatic row count validation
    ...    
    ...    Arguments:
    ...    - csv_file_path: Path to CSV file
    ...    - table_name: Target database table
    ...    - truncate_table: Whether to clear table before loading
    ...    
    ...    Returns:
    ...    - Number of rows loaded
    ...    
    ...    Example:
    ...    ${rows_loaded}=    Load CSV Data Template    ${CSV_FILE_PATH}    employees    ${TRUE}
    
    [Arguments]    ${csv_file_path}    ${table_name}    ${truncate_table}=${FALSE}
    
    # Validate file exists
    File Should Exist    ${csv_file_path}
    Log    📁 Loading CSV file: ${csv_file_path}    INFO
    
    # Get expected row count from file
    ${expected_rows}=    Get CSV Row Count    ${csv_file_path}
    Log    📊 Expected rows to load: ${expected_rows}    INFO
    
    # Truncate table if requested
    IF    ${truncate_table}
        Log    🗑️ Truncating table: ${table_name}    INFO
        Execute SQL String    TRUNCATE TABLE ${table_name}
    END
    
    # Load CSV data
    ${initial_count}=    Execute SQL String    SELECT COUNT(*) FROM ${table_name}
    Log    📈 Initial table row count: ${initial_count}    INFO
    
    # Import CSV to database
    Import CSV To Database    ${csv_file_path}    ${table_name}
    
    # Verify loaded row count
    ${final_count}=    Execute SQL String    SELECT COUNT(*) FROM ${table_name}
    ${loaded_rows}=    Evaluate    ${final_count} - ${initial_count}
    
    Log    ✅ Rows loaded: ${loaded_rows}    INFO
    Log    📊 Final table row count: ${final_count}    INFO
    
    # Assert expected count matches loaded count
    Should Be Equal As Numbers    ${loaded_rows}    ${expected_rows}
    ...    Expected ${expected_rows} rows but loaded ${loaded_rows} rows
    
    RETURN    ${loaded_rows}
```

#### **Advanced CSV Loading with Validation**
```robot
*** Keywords ***
Load CSV With Column Validation
    [Documentation]    Loads CSV with column mapping and data type validation
    [Arguments]    ${csv_file_path}    ${table_name}    ${column_mapping}    ${validation_rules}=${NONE}
    
    # Validate CSV structure
    ${csv_headers}=    Get CSV Headers    ${csv_file_path}
    Log    📋 CSV Headers: ${csv_headers}    INFO
    
    # Validate column mapping
    FOR    ${csv_column}    ${db_column}    IN    &{column_mapping}
        List Should Contain Value    ${csv_headers}    ${csv_column}
        ...    CSV missing required column: ${csv_column}
    END
    
    # Load with column mapping
    ${rows_loaded}=    Import CSV With Mapping    ${csv_file_path}    ${table_name}    ${column_mapping}
    
    # Apply validation rules if provided
    IF    ${validation_rules} is not None
        Validate Loaded Data    ${table_name}    ${validation_rules}
    END
    
    RETURN    ${rows_loaded}

Get CSV Row Count
    [Documentation]    Counts data rows in CSV file (excluding header)
    [Arguments]    ${csv_file_path}
    
    ${csv_content}=    Get File    ${csv_file_path}
    ${lines}=    Split String    ${csv_content}    \n
    ${total_lines}=    Get Length    ${lines}
    
    # Subtract 1 for header row, account for empty last line
    ${data_rows}=    Evaluate    ${total_lines} - 1
    IF    '${lines[-1]}' == ''
        ${data_rows}=    Evaluate    ${data_rows} - 1
    END
    
    RETURN    ${data_rows}

Get CSV Headers
    [Documentation]    Extracts column headers from CSV file
    [Arguments]    ${csv_file_path}
    
    ${first_line}=    Get File First Line    ${csv_file_path}
    ${headers}=    Split String    ${first_line}    ,
    
    # Clean headers (remove quotes, whitespace)
    ${clean_headers}=    Create List
    FOR    ${header}    IN    @{headers}
        ${clean_header}=    Strip String    ${header}    characters="' 
        Append To List    ${clean_headers}    ${clean_header}
    END
    
    RETURN    ${clean_headers}
```

### 📊 CSV Loading Examples

#### **Example 1: Basic Employee Data Loading**
```robot
*** Test Cases ***
Load Employee CSV Data
    [Documentation]    Loads employee data from CSV file into database
    [Tags]    csv    data_loading    employees
    
    # Test data file
    ${csv_file}=    Set Variable    ${CURDIR}/../test_data/input_data/employees.csv
    
    # Load data with table truncation
    ${rows_loaded}=    Load CSV Data Template    ${csv_file}    employees    ${TRUE}
    
    # Assertions
    Should Be Equal As Numbers    ${rows_loaded}    4
    Log    ✅ Successfully loaded ${rows_loaded} employee records    INFO
    
    # Verify data in database
    ${db_count}=    Execute SQL String    SELECT COUNT(*) FROM employees
    Should Be Equal As Numbers    ${db_count}    4
```

#### **Example 2: CSV Loading with Data Validation**
```robot
*** Test Cases ***
Load And Validate Employee Data
    [Documentation]    Loads CSV data with comprehensive validation
    [Tags]    csv    validation    employees
    
    # Column mapping configuration
    &{column_mapping}=    Create Dictionary
    ...    name=employee_name
    ...    role=job_title
    ...    salary=annual_salary
    ...    department=dept_name
    
    # Validation rules
    &{validation_rules}=    Create Dictionary
    ...    salary_min=30000
    ...    salary_max=200000
    ...    required_fields=name,role
    
    # Load with validation
    ${csv_file}=    Set Variable    ${CURDIR}/../test_data/input_data/employees_detailed.csv
    ${rows_loaded}=    Load CSV With Column Validation
    ...    ${csv_file}
    ...    employees
    ...    ${column_mapping}
    ...    ${validation_rules}
    
    Log    ✅ Loaded and validated ${rows_loaded} records    INFO
```

#### **Example 3: Performance Testing with Large CSV**
```robot
*** Test Cases ***
Load Large CSV Dataset
    [Documentation]    Performance test with large CSV file
    [Tags]    csv    performance    large_data
    
    ${start_time}=    Get Time    epoch
    
    # Load large dataset
    ${csv_file}=    Set Variable    ${CURDIR}/../test_data/datasets/large/employees_5000.csv
    ${rows_loaded}=    Load CSV Data Template    ${csv_file}    employees_large    ${TRUE}
    
    ${end_time}=    Get Time    epoch
    ${duration}=    Evaluate    ${end_time} - ${start_time}
    
    # Performance assertions
    Should Be Equal As Numbers    ${rows_loaded}    5000
    Should Be True    ${duration} < 30    Loading took too long: ${duration} seconds
    
    Log    📊 Loaded ${rows_loaded} rows in ${duration} seconds    INFO
    Log    ⚡ Performance: ${${rows_loaded}/${duration}} rows/second    INFO
```

## Loading JSON Test Data

### 🔧 JSON Loading Keywords

#### **Basic JSON Loading Keyword**
```robot
*** Keywords ***
Load JSON Data Template
    [Documentation]    Loads JSON data into database with automatic record count validation
    ...    
    ...    Arguments:
    ...    - json_file_path: Path to JSON file
    ...    - table_name: Target database table  
    ...    - truncate_table: Whether to clear table before loading
    ...    
    ...    Returns:
    ...    - Number of records loaded
    ...    
    ...    Example:
    ...    ${records_loaded}=    Load JSON Data Template    ${JSON_FILE_PATH}    customers    ${TRUE}
    
    [Arguments]    ${json_file_path}    ${table_name}    ${truncate_table}=${FALSE}
    
    # Validate file exists
    File Should Exist    ${json_file_path}
    Log    📁 Loading JSON file: ${json_file_path}    INFO
    
    # Parse JSON and get record count
    ${json_data}=    Load JSON From File    ${json_file_path}
    ${expected_records}=    Get JSON Record Count    ${json_data}
    Log    📊 Expected records to load: ${expected_records}    INFO
    
    # Truncate table if requested
    IF    ${truncate_table}
        Log    🗑️ Truncating table: ${table_name}    INFO
        Execute SQL String    TRUNCATE TABLE ${table_name}
    END
    
    # Get initial count
    ${initial_count}=    Execute SQL String    SELECT COUNT(*) FROM ${table_name}
    Log    📈 Initial table record count: ${initial_count}    INFO
    
    # Load JSON data
    ${loaded_records}=    Import JSON To Database    ${json_data}    ${table_name}
    
    # Verify loaded record count
    ${final_count}=    Execute SQL String    SELECT COUNT(*) FROM ${table_name}
    ${actual_loaded}=    Evaluate    ${final_count} - ${initial_count}
    
    Log    ✅ Records loaded: ${actual_loaded}    INFO
    Log    📊 Final table record count: ${final_count}    INFO
    
    # Assert expected count matches loaded count
    Should Be Equal As Numbers    ${actual_loaded}    ${expected_records}
    ...    Expected ${expected_records} records but loaded ${actual_loaded} records
    
    RETURN    ${actual_loaded}

Get JSON Record Count
    [Documentation]    Counts records in JSON data structure
    [Arguments]    ${json_data}
    
    # Handle different JSON structures
    ${data_type}=    Evaluate    type($json_data).__name__
    
    IF    '${data_type}' == 'list'
        # JSON array - count elements
        ${count}=    Get Length    ${json_data}
    ELSE IF    '${data_type}' == 'dict'
        # JSON object - look for common array keys
        ${count}=    Get JSON Object Record Count    ${json_data}
    ELSE
        Fail    Unsupported JSON structure: ${data_type}
    END
    
    RETURN    ${count}

Get JSON Object Record Count
    [Documentation]    Counts records in JSON object with nested arrays
    [Arguments]    ${json_object}
    
    # Common patterns for data arrays in JSON objects
    @{array_keys}=    Create List    data    records    items    employees    customers    results
    
    FOR    ${key}    IN    @{array_keys}
        ${has_key}=    Run Keyword And Return Status    Dictionary Should Contain Key    ${json_object}    ${key}
        IF    ${has_key}
            ${array_data}=    Get From Dictionary    ${json_object}    ${key}
            ${is_list}=    Evaluate    isinstance($array_data, list)
            IF    ${is_list}
                ${count}=    Get Length    ${array_data}
                RETURN    ${count}
            END
        END
    END
    
    # If no array found, assume single record
    RETURN    1
```

#### **Advanced JSON Loading with Schema Validation**
```robot
*** Keywords ***
Load JSON With Schema Validation
    [Documentation]    Loads JSON data with schema validation
    [Arguments]    ${json_file_path}    ${table_name}    ${schema_file}=${NONE}    ${field_mapping}=${NONE}
    
    # Load and parse JSON
    ${json_data}=    Load JSON From File    ${json_file_path}
    Log    📋 JSON structure loaded successfully    INFO
    
    # Validate against schema if provided
    IF    '${schema_file}' != 'None'
        Validate JSON Against Schema    ${json_data}    ${schema_file}
        Log    ✅ JSON schema validation passed    INFO
    END
    
    # Load with field mapping if provided
    IF    '${field_mapping}' != 'None'
        ${records_loaded}=    Import JSON With Field Mapping    ${json_data}    ${table_name}    ${field_mapping}
    ELSE
        ${records_loaded}=    Import JSON To Database    ${json_data}    ${table_name}
    END
    
    RETURN    ${records_loaded}

Import JSON To Database
    [Documentation]    Imports JSON data to database table
    [Arguments]    ${json_data}    ${table_name}
    
    ${data_type}=    Evaluate    type($json_data).__name__
    
    IF    '${data_type}' == 'list'
        # Handle JSON array
        ${records_loaded}=    Import JSON Array To Database    ${json_data}    ${table_name}
    ELSE IF    '${data_type}' == 'dict'
        # Handle JSON object
        ${records_loaded}=    Import JSON Object To Database    ${json_data}    ${table_name}
    ELSE
        Fail    Unsupported JSON data type: ${data_type}
    END
    
    RETURN    ${records_loaded}

Import JSON Array To Database
    [Documentation]    Imports JSON array to database
    [Arguments]    ${json_array}    ${table_name}
    
    ${record_count}=    Set Variable    0
    
    FOR    ${record}    IN    @{json_array}
        ${sql}=    Build Insert SQL From JSON    ${record}    ${table_name}
        Execute SQL String    ${sql}
        ${record_count}=    Evaluate    ${record_count} + 1
    END
    
    RETURN    ${record_count}
```

### 📋 JSON Loading Examples

#### **Example 1: Basic JSON Array Loading**
```robot
*** Test Cases ***
Load Customer JSON Data
    [Documentation]    Loads customer data from JSON array
    [Tags]    json    data_loading    customers
    
    # JSON array structure: [{"id": 1, "name": "John"}, ...]
    ${json_file}=    Set Variable    ${CURDIR}/../test_data/input_data/customers.json
    
    # Load data with table truncation
    ${records_loaded}=    Load JSON Data Template    ${json_file}    customers    ${TRUE}
    
    # Assertions
    Should Be Equal As Numbers    ${records_loaded}    3
    Log    ✅ Successfully loaded ${records_loaded} customer records    INFO
    
    # Verify specific data
    ${customer_names}=    Execute SQL String    SELECT name FROM customers ORDER BY id
    Should Contain    ${customer_names}    John Doe
```

#### **Example 2: Nested JSON Object Loading**
```robot
*** Test Cases ***
Load Complex JSON Structure
    [Documentation]    Loads nested JSON data with multiple levels
    [Tags]    json    nested    complex_data
    
    # JSON structure: {"company": {"employees": [...]}}
    ${json_file}=    Set Variable    ${CURDIR}/../test_data/input_data/company_data.json
    
    # Custom field mapping for nested structure
    &{field_mapping}=    Create Dictionary
    ...    employees.name=employee_name
    ...    employees.job_info.role=job_title
    ...    employees.job_info.salary=annual_salary
    ...    employees.contact.email=email_address
    
    # Load with schema validation
    ${schema_file}=    Set Variable    ${CURDIR}/../test_data/schemas/company_schema.json
    ${records_loaded}=    Load JSON With Schema Validation
    ...    ${json_file}
    ...    employees
    ...    ${schema_file}
    ...    ${field_mapping}
    
    Log    ✅ Loaded ${records_loaded} employees from nested JSON    INFO
```

#### **Example 3: JSON Loading with Data Transformation**
```robot
*** Test Cases ***
Load JSON With Data Transformation
    [Documentation]    Loads JSON data with field transformations
    [Tags]    json    transformation    data_processing
    
    ${json_file}=    Set Variable    ${CURDIR}/../test_data/input_data/employees_raw.json
    
    # Load raw JSON
    ${json_data}=    Load JSON From File    ${json_file}
    
    # Transform data
    ${transformed_data}=    Transform Employee JSON Data    ${json_data}
    
    # Load transformed data
    ${records_loaded}=    Import JSON To Database    ${transformed_data}    employees_processed
    
    Log    ✅ Loaded ${records_loaded} transformed records    INFO
    
    # Verify transformations
    ${avg_salary}=    Execute SQL String    SELECT AVG(salary) FROM employees_processed
    Should Be True    ${avg_salary} > 0

*** Keywords ***
Transform Employee JSON Data
    [Documentation]    Applies business logic transformations to employee JSON
    [Arguments]    ${raw_json_data}
    
    ${transformed_data}=    Create List
    
    FOR    ${employee}    IN    @{raw_json_data}
        # Apply salary normalization
        ${salary}=    Get From Dictionary    ${employee}    salary
        ${normalized_salary}=    Normalize Salary    ${salary}
        Set To Dictionary    ${employee}    salary    ${normalized_salary}
        
        # Add calculated fields
        ${annual_bonus}=    Calculate Annual Bonus    ${normalized_salary}
        Set To Dictionary    ${employee}    annual_bonus    ${annual_bonus}
        
        Append To List    ${transformed_data}    ${employee}
    END
    
    RETURN    ${transformed_data}
```

## Database Test Data Strategies

### 🗄️ Database Setup and Teardown

#### **Database Setup Keywords**
```robot
*** Keywords ***
Initialize Test Database
    [Documentation]    Sets up clean database state for testing
    [Arguments]    ${database_name}=${TEST_DATABASE}
    
    Log    🏗️ Initializing test database: ${database_name}    INFO
    
    # Connect to database
    Connect to Database    ${database_name}    ${DB_USER}    ${DB_PASSWORD}    ${DB_HOST}    ${DB_PORT}
    
    # Create test tables
    Execute SQL Script    ${CURDIR}/../test_data/queries/create_tables.sql
    
    # Set up test data constraints
    Execute SQL Script    ${CURDIR}/../test_data/queries/setup_constraints.sql
    
    Log    ✅ Database initialization complete    INFO

Setup Test Tables
    [Documentation]    Creates all required tables for test suite
    
    # Employee table
    Execute SQL String    CREATE TABLE IF NOT EXISTS employees (
    ...    id SERIAL PRIMARY KEY,
    ...    name VARCHAR(100) NOT NULL,
    ...    role VARCHAR(50),
    ...    salary INTEGER,
    ...    department VARCHAR(50),
    ...    hire_date DATE,
    ...    active BOOLEAN DEFAULT true
    ...)
    
    # Customer table
    Execute SQL String    CREATE TABLE IF NOT EXISTS customers (
    ...    id SERIAL PRIMARY KEY,
    ...    name VARCHAR(100) NOT NULL,
    ...    email VARCHAR(100) UNIQUE,
    ...    phone VARCHAR(20),
    ...    created_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    ...)
    
    Log    ✅ Test tables created successfully    INFO

Cleanup Test Database
    [Documentation]    Cleans up test data and tables
    
    Log    🧹 Cleaning up test database    INFO
    
    # Drop test tables in correct order (foreign keys first)
    @{tables}=    Create List    order_items    orders    customers    employees
    
    FOR    ${table}    IN    @{tables}
        ${table_exists}=    Run Keyword And Return Status
        ...    Execute SQL String    SELECT 1 FROM ${table} LIMIT 1
        IF    ${table_exists}
            Execute SQL String    DROP TABLE IF EXISTS ${table} CASCADE
            Log    🗑️ Dropped table: ${table}    INFO
        END
    END
    
    Log    ✅ Database cleanup complete    INFO
```

#### **Data Isolation Strategies**
```robot
*** Keywords ***
Create Isolated Test Data
    [Documentation]    Creates test data with unique identifiers to avoid conflicts
    [Arguments]    ${test_id}=${TEST_UNIQUE_ID}
    
    # Use test ID prefix for unique data
    ${employee_prefix}=    Set Variable    test_${test_id}_
    
    # Create employees with unique names
    Execute SQL String    INSERT INTO employees (name, role, salary, department) VALUES
    ...    ('${employee_prefix}alice', 'Manager', 75000, 'Engineering'),
    ...    ('${employee_prefix}bob', 'Developer', 65000, 'Engineering'),
    ...    ('${employee_prefix}charlie', 'Designer', 60000, 'Marketing')
    
    # Return test data identifiers
    ${test_data_info}=    Create Dictionary
    ...    employee_prefix=${employee_prefix}
    ...    employee_count=3
    ...    test_id=${test_id}
    
    RETURN    ${test_data_info}

Cleanup Isolated Test Data
    [Documentation]    Removes test data created with specific test ID
    [Arguments]    ${test_id}=${TEST_UNIQUE_ID}
    
    ${employee_prefix}=    Set Variable    test_${test_id}_
    
    # Clean up employees with test prefix
    Execute SQL String    DELETE FROM employees WHERE name LIKE '${employee_prefix}%'
    
    Log    🧹 Cleaned up test data for test ID: ${test_id}    INFO
```

### 🔄 Data State Management

#### **Database State Keywords**
```robot
*** Keywords ***
Save Database State
    [Documentation]    Saves current database state for restoration
    [Arguments]    ${state_name}
    
    # Create backup tables
    Execute SQL String    CREATE TABLE employees_backup_${state_name} AS SELECT * FROM employees
    Execute SQL String    CREATE TABLE customers_backup_${state_name} AS SELECT * FROM customers
    
    Log    💾 Database state saved as: ${state_name}    INFO

Restore Database State
    [Documentation]    Restores database to previously saved state
    [Arguments]    ${state_name}
    
    # Restore from backup tables
    Execute SQL String    TRUNCATE TABLE employees
    Execute SQL String    INSERT INTO employees SELECT * FROM employees_backup_${state_name}
    
    Execute SQL String    TRUNCATE TABLE customers  
    Execute SQL String    INSERT INTO customers SELECT * FROM customers_backup_${state_name}
    
    Log    ♻️ Database state restored from: ${state_name}    INFO

Clean Database State
    [Documentation]    Removes saved database state
    [Arguments]    ${state_name}
    
    Execute SQL String    DROP TABLE IF EXISTS employees_backup_${state_name}
    Execute SQL String    DROP TABLE IF EXISTS customers_backup_${state_name}
    
    Log    🗑️ Database state cleaned: ${state_name}    INFO
```

## Environment-Specific Data Management

### 🌍 Multi-Environment Data Strategy

#### **Environment-Specific Data Loading**
```robot
*** Keywords ***
Load Environment Specific Data
    [Documentation]    Loads data appropriate for current test environment
    [Arguments]    ${data_type}    ${environment}=${TEST_ENVIRONMENT}
    
    # Determine data file based on environment
    ${data_file}=    Get Environment Data File    ${data_type}    ${environment}
    
    Log    🌍 Loading ${data_type} data for environment: ${environment}    INFO
    Log    📁 Data file: ${data_file}    INFO
    
    # Load data based on file type
    ${file_extension}=    Get File Extension    ${data_file}
    
    IF    '${file_extension}' == '.csv'
        ${records_loaded}=    Load CSV Data Template    ${data_file}    ${data_type}    ${TRUE}
    ELSE IF    '${file_extension}' == '.json'
        ${records_loaded}=    Load JSON Data Template    ${data_file}    ${data_type}    ${TRUE}
    ELSE
        Fail    Unsupported data file type: ${file_extension}
    END
    
    RETURN    ${records_loaded}

Get Environment Data File
    [Documentation]    Returns appropriate data file for environment
    [Arguments]    ${data_type}    ${environment}
    
    # Environment-specific data files
    ${data_dir}=    Set Variable    ${CURDIR}/../test_data/datasets/${environment}
    ${data_file}=    Set Variable    ${data_dir}/${data_type}.csv
    
    # Fallback to default if environment-specific file doesn't exist
    ${file_exists}=    Run Keyword And Return Status    File Should Exist    ${data_file}
    IF    not ${file_exists}
        Log    ⚠️ Environment-specific file not found, using default    WARN
        ${data_file}=    Set Variable    ${CURDIR}/../test_data/input_data/${data_type}.csv
    END
    
    File Should Exist    ${data_file}
    RETURN    ${data_file}
```

#### **Environment Configuration**
```robot
*** Variables ***
# Environment-specific configurations
&{DEV_CONFIG}=
...    database_size=small
...    data_volume=100
...    performance_threshold=5

&{TEST_CONFIG}=
...    database_size=medium
...    data_volume=1000
...    performance_threshold=10

&{PROD_CONFIG}=
...    database_size=large
...    data_volume=10000
...    performance_threshold=30

*** Keywords ***
Get Environment Configuration
    [Documentation]    Returns configuration for current environment
    [Arguments]    ${environment}=${TEST_ENVIRONMENT}
    
    IF    '${environment}' == 'dev'
        RETURN    ${DEV_CONFIG}
    ELSE IF    '${environment}' == 'test'
        RETURN    ${TEST_CONFIG}
    ELSE IF    '${environment}' == 'prod'
        RETURN    ${PROD_CONFIG}
    ELSE
        Fail    Unknown environment: ${environment}
    END
```

## Data Validation and Integrity

### ✅ Data Quality Validation

#### **Data Validation Keywords**
```robot
*** Keywords ***
Validate Data Integrity
    [Documentation]    Performs comprehensive data integrity checks
    [Arguments]    ${table_name}    ${validation_rules}
    
    Log    🔍 Validating data integrity for table: ${table_name}    INFO
    
    # Check for required fields
    Validate Required Fields    ${table_name}    ${validation_rules}
    
    # Check data types and formats
    Validate Data Types    ${table_name}    ${validation_rules}
    
    # Check business rules
    Validate Business Rules    ${table_name}    ${validation_rules}
    
    # Check for duplicates
    Validate No Duplicates    ${table_name}    ${validation_rules}
    
    Log    ✅ Data integrity validation passed    INFO

Validate Required Fields
    [Documentation]    Validates that required fields are not null
    [Arguments]    ${table_name}    ${validation_rules}
    
    ${required_fields}=    Get From Dictionary    ${validation_rules}    required_fields    ${EMPTY}
    
    IF    '${required_fields}' != '${EMPTY}'
        @{fields}=    Split String    ${required_fields}    ,
        FOR    ${field}    IN    @{fields}
            ${field}=    Strip String    ${field}
            ${null_count}=    Execute SQL String    
            ...    SELECT COUNT(*) FROM ${table_name} WHERE ${field} IS NULL
            Should Be Equal As Numbers    ${null_count}    0
            ...    Found ${null_count} NULL values in required field: ${field}
        END
    END

Validate Data Types
    [Documentation]    Validates data types and formats
    [Arguments]    ${table_name}    ${validation_rules}
    
    # Email format validation
    ${email_field}=    Get From Dictionary    ${validation_rules}    email_field    ${NONE}
    IF    '${email_field}' != 'None'
        ${invalid_emails}=    Execute SQL String
        ...    SELECT COUNT(*) FROM ${table_name} 
        ...    WHERE ${email_field} IS NOT NULL 
        ...    AND ${email_field} !~ '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'
        Should Be Equal As Numbers    ${invalid_emails}    0
        ...    Found ${invalid_emails} invalid email addresses
    END
    
    # Numeric range validation
    ${salary_min}=    Get From Dictionary    ${validation_rules}    salary_min    ${NONE}
    ${salary_max}=    Get From Dictionary    ${validation_rules}    salary_max    ${NONE}
    IF    '${salary_min}' != 'None' and '${salary_max}' != 'None'
        ${out_of_range}=    Execute SQL String
        ...    SELECT COUNT(*) FROM ${table_name}
        ...    WHERE salary < ${salary_min} OR salary > ${salary_max}
        Should Be Equal As Numbers    ${out_of_range}    0
        ...    Found ${out_of_range} salary values outside valid range
    END

Compare Data Sets
    [Documentation]    Compares two data sets for differences
    [Arguments]    ${source_file}    ${target_file}    ${comparison_rules}=${NONE}
    
    Log    🔄 Comparing data sets    INFO
    Log    📁 Source: ${source_file}    INFO
    Log    📁 Target: ${target_file}    INFO
    
    # Determine file types and compare accordingly
    ${source_ext}=    Get File Extension    ${source_file}
    ${target_ext}=    Get File Extension    ${target_file}
    
    IF    '${source_ext}' == '.csv' and '${target_ext}' == '.csv'
        Compare CSV Files    ${source_file}    ${target_file}    ${comparison_rules}
    ELSE IF    '${source_ext}' == '.json' and '${target_ext}' == '.json'
        Compare JSON Files    ${source_file}    ${target_file}    ${comparison_rules}
    ELSE
        Fail    Cannot compare files with different types: ${source_ext} vs ${target_ext}
    END
    
    Log    ✅ Data comparison completed successfully    INFO
```

### 📊 File Comparison Utilities

#### **CSV Comparison Keywords**
```robot
*** Keywords ***
Compare CSV Files
    [Documentation]    Compares two CSV files for structural and content differences
    [Arguments]    ${file1}    ${file2}    ${comparison_rules}=${NONE}
    
    # Load CSV files
    ${csv1_data}=    Read CSV File    ${file1}
    ${csv2_data}=    Read CSV File    ${file2}
    
    # Compare headers
    ${headers1}=    Get CSV Headers    ${file1}
    ${headers2}=    Get CSV Headers    ${file2}
    Lists Should Be Equal    ${headers1}    ${headers2}
    ...    CSV headers do not match
    
    # Compare row counts
    ${rows1}=    Get Length    ${csv1_data}
    ${rows2}=    Get Length    ${csv2_data}
    Should Be Equal As Numbers    ${rows1}    ${rows2}
    ...    Row counts differ: ${rows1} vs ${rows2}
    
    # Compare content row by row
    FOR    ${index}    IN RANGE    ${rows1}
        ${row1}=    Get From List    ${csv1_data}    ${index}
        ${row2}=    Get From List    ${csv2_data}    ${index}
        Compare CSV Rows    ${row1}    ${row2}    ${index}
    END
    
    Log    ✅ CSV files are identical    INFO

Compare CSV Rows
    [Documentation]    Compares individual CSV rows
    [Arguments]    ${row1}    ${row2}    ${row_index}
    
    ${fields1}=    Split String    ${row1}    ,
    ${fields2}=    Split String    ${row2}    ,
    
    ${field_count1}=    Get Length    ${fields1}
    ${field_count2}=    Get Length    ${fields2}
    Should Be Equal As Numbers    ${field_count1}    ${field_count2}
    ...    Field count mismatch in row ${row_index}
    
    FOR    ${field_index}    IN RANGE    ${field_count1}
        ${field1}=    Get From List    ${fields1}    ${field_index}
        ${field2}=    Get From List    ${fields2}    ${field_index}
        ${field1}=    Strip String    ${field1}    characters="' 
        ${field2}=    Strip String    ${field2}    characters="' 
        Should Be Equal    ${field1}    ${field2}
        ...    Field mismatch in row ${row_index}, field ${field_index}: '${field1}' != '${field2}'
    END
```

#### **JSON Comparison Keywords**
```robot
*** Keywords ***
Compare JSON Files
    [Documentation]    Compares two JSON files for structural and content differences
    [Arguments]    ${file1}    ${file2}    ${comparison_rules}=${NONE}
    
    # Load JSON files
    ${json1}=    Load JSON From File    ${file1}
    ${json2}=    Load JSON From File    ${file2}
    
    # Compare JSON structures
    ${comparison_result}=    Compare JSON Objects    ${json1}    ${json2}
    
    IF    not ${comparison_result}
        Fail    JSON files are not identical
    END
    
    Log    ✅ JSON files are identical    INFO

Compare JSON Objects
    [Documentation]    Recursively compares JSON objects
    [Arguments]    ${obj1}    ${obj2}
    
    # Compare types
    ${type1}=    Evaluate    type($obj1).__name__
    ${type2}=    Evaluate    type($obj2).__name__
    
    IF    '${type1}' != '${type2}'
        Log    Type mismatch: ${type1} vs ${type2}    ERROR
        RETURN    ${FALSE}
    END
    
    # Compare based on type
    IF    '${type1}' == 'dict'
        ${result}=    Compare JSON Dictionaries    ${obj1}    ${obj2}
    ELSE IF    '${type1}' == 'list'
        ${result}=    Compare JSON Arrays    ${obj1}    ${obj2}
    ELSE
        ${result}=    Evaluate    $obj1 == $obj2
    END
    
    RETURN    ${result}
```

## Test Data Lifecycle Management

### 🔄 Data Generation and Maintenance

#### **Dynamic Data Generation**
```robot
*** Keywords ***
Generate Test Data
    [Documentation]    Generates test data based on templates and parameters
    [Arguments]    ${data_type}    ${record_count}    ${template_file}=${NONE}
    
    Log    🏭 Generating ${record_count} ${data_type} records    INFO
    
    IF    '${template_file}' != 'None'
        ${template}=    Load JSON From File    ${template_file}
        ${generated_data}=    Generate From Template    ${template}    ${record_count}
    ELSE
        ${generated_data}=    Generate Default Data    ${data_type}    ${record_count}
    END
    
    # Save generated data
    ${output_file}=    Set Variable    ${CURDIR}/../test_data/generated/${data_type}_${record_count}.json
    Save JSON To File    ${generated_data}    ${output_file}
    
    Log    ✅ Generated data saved to: ${output_file}    INFO
    RETURN    ${output_file}

Generate Employee Data
    [Documentation]    Generates realistic employee test data
    [Arguments]    ${count}=10
    
    ${employees}=    Create List
    
    # Sample data pools
    @{first_names}=    Create List    Alice    Bob    Charlie    Diana    Eve    Frank    Grace    Henry
    @{last_names}=    Create List    Johnson    Smith    Brown    Wilson    Davis    Miller    Moore    Taylor
    @{roles}=    Create List    Developer    Manager    Designer    QA Engineer    Data Analyst    DevOps Engineer
    @{departments}=    Create List    Engineering    Marketing    Sales    HR    Finance
    
    FOR    ${i}    IN RANGE    ${count}
        ${first_name}=    Get Random Item    ${first_names}
        ${last_name}=    Get Random Item    ${last_names}
        ${role}=    Get Random Item    ${roles}
        ${department}=    Get Random Item    ${departments}
        ${salary}=    Evaluate    random.randint(45000, 120000)
        
        &{employee}=    Create Dictionary
        ...    id=${i + 1}
        ...    name=${first_name} ${last_name}
        ...    role=${role}
        ...    department=${department}
        ...    salary=${salary}
        ...    hire_date=2024-01-${i + 1:02d}
        ...    active=${TRUE}
        
        Append To List    ${employees}    ${employee}
    END
    
    RETURN    ${employees}

Get Random Item
    [Documentation]    Returns random item from list
    [Arguments]    ${item_list}
    
    ${list_length}=    Get Length    ${item_list}
    ${random_index}=    Evaluate    random.randint(0, ${list_length} - 1)
    ${random_item}=    Get From List    ${item_list}    ${random_index}
    
    RETURN    ${random_item}
```

#### **Data Refresh and Updates**
```robot
*** Keywords ***
Refresh Test Data
    [Documentation]    Updates test data files with fresh data
    [Arguments]    ${data_categories}
    
    Log    🔄 Refreshing test data for categories: ${data_categories}    INFO
    
    FOR    ${category}    IN    @{data_categories}
        Log    Refreshing ${category} data...    INFO
        
        IF    '${category}' == 'employees'
            Refresh Employee Data
        ELSE IF    '${category}' == 'customers'
            Refresh Customer Data
        ELSE IF    '${category}' == 'orders'
            Refresh Order Data
        ELSE
            Log    Unknown data category: ${category}    WARN
        END
    END
    
    Log    ✅ Test data refresh completed    INFO

Archive Old Test Data
    [Documentation]    Archives old test data before generating new data
    [Arguments]    ${data_file}
    
    ${timestamp}=    Get Time    format=%Y%m%d_%H%M%S
    ${backup_file}=    Set Variable    ${data_file}.backup_${timestamp}
    
    Copy File    ${data_file}    ${backup_file}
    Log    📦 Archived old data: ${backup_file}    INFO
```

## Advanced Data Management Patterns

### 🎭 Data Masking and Privacy

#### **Data Anonymization Keywords**
```robot
*** Keywords ***
Anonymize Personal Data
    [Documentation]    Anonymizes personal data for privacy compliance
    [Arguments]    ${source_file}    ${target_file}    ${anonymization_rules}
    
    Log    🎭 Anonymizing personal data    INFO
    
    # Load source data
    ${source_data}=    Load JSON From File    ${source_file}
    
    # Apply anonymization rules
    ${anonymized_data}=    Apply Anonymization Rules    ${source_data}    ${anonymization_rules}
    
    # Save anonymized data
    Save JSON To File    ${anonymized_data}    ${target_file}
    
    Log    ✅ Data anonymization completed    INFO

Apply Anonymization Rules
    [Documentation]    Applies specific anonymization transformations
    [Arguments]    ${data}    ${rules}
    
    ${anonymized_data}=    Create List
    
    FOR    ${record}    IN    @{data}
        ${anonymized_record}=    Copy Dictionary    ${record}
        
        # Anonymize email addresses
        ${email_rule}=    Get From Dictionary    ${rules}    email    ${NONE}
        IF    '${email_rule}' != 'None'
            ${original_email}=    Get From Dictionary    ${record}    email
            ${anonymized_email}=    Anonymize Email    ${original_email}
            Set To Dictionary    ${anonymized_record}    email    ${anonymized_email}
        END
        
        # Anonymize names
        ${name_rule}=    Get From Dictionary    ${rules}    name    ${NONE}
        IF    '${name_rule}' != 'None'
            ${anonymized_name}=    Generate Fake Name
            Set To Dictionary    ${anonymized_record}    name    ${anonymized_name}
        END
        
        Append To List    ${anonymized_data}    ${anonymized_record}
    END
    
    RETURN    ${anonymized_data}
```

### 🧪 Data Factory Pattern

#### **Data Factory Implementation**
```robot
*** Keywords ***
Create Data Factory
    [Documentation]    Factory pattern for creating different types of test data
    [Arguments]    ${data_type}    ${parameters}=${EMPTY_DICT}
    
    Log    🏭 Creating data factory for type: ${data_type}    INFO
    
    IF    '${data_type}' == 'employee'
        ${data}=    Create Employee Data Factory    ${parameters}
    ELSE IF    '${data_type}' == 'customer'
        ${data}=    Create Customer Data Factory    ${parameters}
    ELSE IF    '${data_type}' == 'order'
        ${data}=    Create Order Data Factory    ${parameters}
    ELSE
        Fail    Unknown data factory type: ${data_type}
    END
    
    RETURN    ${data}

Create Employee Data Factory
    [Documentation]    Creates employee data with configurable parameters
    [Arguments]    ${parameters}
    
    # Extract parameters with defaults
    ${count}=    Get From Dictionary    ${parameters}    count    10
    ${department}=    Get From Dictionary    ${parameters}    department    Engineering
    ${salary_range}=    Get From Dictionary    ${parameters}    salary_range    50000-100000
    ${active_only}=    Get From Dictionary    ${parameters}    active_only    ${TRUE}
    
    # Parse salary range
    @{salary_parts}=    Split String    ${salary_range}    -
    ${min_salary}=    Convert To Integer    ${salary_parts}[0]
    ${max_salary}=    Convert To Integer    ${salary_parts}[1]
    
    # Generate employees
    ${employees}=    Create List
    
    FOR    ${i}    IN RANGE    ${count}
        &{employee}=    Create Dictionary
        ...    id=${i + 1}
        ...    name=Employee ${i + 1}
        ...    department=${department}
        ...    salary=${min_salary + (${max_salary} - ${min_salary}) * ${i} // ${count}}
        ...    active=${active_only}
        
        Append To List    ${employees}    ${employee}
    END
    
    RETURN    ${employees}
```

## Troubleshooting Data Issues

### 🔍 Common Data Problems and Solutions

#### **File Loading Issues**
```robot
*** Keywords ***
Debug CSV Loading Issues
    [Documentation]    Diagnoses and reports CSV loading problems
    [Arguments]    ${csv_file_path}
    
    Log    🔍 Debugging CSV loading issues for: ${csv_file_path}    INFO
    
    # Check file existence
    ${file_exists}=    Run Keyword And Return Status    File Should Exist    ${csv_file_path}
    IF    not ${file_exists}
        Log    ❌ File does not exist: ${csv_file_path}    ERROR
        RETURN
    END
    
    # Check file permissions
    ${file_info}=    Get File Info    ${csv_file_path}
    Log    📋 File info: ${file_info}    INFO
    
    # Check file content
    ${file_size}=    Get File Size    ${csv_file_path}
    IF    ${file_size} == 0
        Log    ❌ File is empty: ${csv_file_path}    ERROR
        RETURN
    END
    
    # Check CSV structure
    ${first_line}=    Get File First Line    ${csv_file_path}
    Log    📄 First line (headers): ${first_line}    INFO
    
    ${line_count}=    Get Line Count    ${csv_file_path}
    Log    📊 Total lines: ${line_count}    INFO
    
    # Check for common CSV issues
    Check CSV Format Issues    ${csv_file_path}

Check CSV Format Issues
    [Documentation]    Identifies common CSV formatting problems
    [Arguments]    ${csv_file_path}
    
    ${content}=    Get File    ${csv_file_path}
    
    # Check for inconsistent delimiters
    ${comma_count}=    Count String Occurrences    ${content}    ,
    ${semicolon_count}=    Count String Occurrences    ${content}    ;
    ${tab_count}=    Count String Occurrences    ${content}    \t
    
    Log    📊 Delimiter analysis:    INFO
    Log    - Commas: ${comma_count}    INFO
    Log    - Semicolons: ${semicolon_count}    INFO
    Log    - Tabs: ${tab_count}    INFO
    
    # Check for encoding issues
    ${has_bom}=    Run Keyword And Return Status    Should Start With    ${content}    \ufeff
    IF    ${has_bom}
        Log    ⚠️ File contains BOM (Byte Order Mark)    WARN
    END
    
    # Check for unescaped quotes
    ${quote_issues}=    Count String Occurrences    ${content}    \"\"
    IF    ${quote_issues} > 0
        Log    ⚠️ Found ${quote_issues} potential quote escaping issues    WARN
    END

Debug JSON Loading Issues
    [Documentation]    Diagnoses JSON loading and parsing problems
    [Arguments]    ${json_file_path}
    
    Log    🔍 Debugging JSON loading issues for: ${json_file_path}    INFO
    
    # Check file existence and basic info
    File Should Exist    ${json_file_path}
    ${file_size}=    Get File Size    ${json_file_path}
    Log    📊 File size: ${file_size} bytes    INFO
    
    # Try to parse JSON
    ${parse_status}=    Run Keyword And Return Status    Load JSON From File    ${json_file_path}
    IF    not ${parse_status}
        Log    ❌ JSON parsing failed    ERROR
        
        # Try to identify JSON issues
        ${content}=    Get File    ${json_file_path}
        Analyze JSON Structure Issues    ${content}
    ELSE
        Log    ✅ JSON parsing successful    INFO
    END

Analyze JSON Structure Issues
    [Documentation]    Identifies common JSON structure problems
    [Arguments]    ${json_content}
    
    # Check for common JSON issues
    ${has_trailing_comma}=    Contains String    ${json_content}    ,}
    IF    ${has_trailing_comma}
        Log    ❌ Found trailing comma before closing brace    ERROR
    END
    
    ${has_trailing_comma_array}=    Contains String    ${json_content}    ,]
    IF    ${has_trailing_comma_array}
        Log    ❌ Found trailing comma before closing bracket    ERROR
    END
    
    # Check bracket/brace balance
    ${open_braces}=    Count String Occurrences    ${json_content}    {
    ${close_braces}=    Count String Occurrences    ${json_content}    }
    ${open_brackets}=    Count String Occurrences    ${json_content}    [
    ${close_brackets}=    Count String Occurrences    ${json_content}    ]
    
    Log    📊 Structure analysis:    INFO
    Log    - Open braces: ${open_braces}, Close braces: ${close_braces}    INFO
    Log    - Open brackets: ${open_brackets}, Close brackets: ${close_brackets}    INFO
    
    IF    ${open_braces} != ${close_braces}
        Log    ❌ Unbalanced braces: ${open_braces} open, ${close_braces} close    ERROR
    END
    
    IF    ${open_brackets} != ${close_brackets}
        Log    ❌ Unbalanced brackets: ${open_brackets} open, ${close_brackets} close    ERROR
    END
```

### 🛠️ Data Recovery and Repair

#### **Data Recovery Keywords**
```robot
*** Keywords ***
Recover Corrupted CSV
    [Documentation]    Attempts to recover data from corrupted CSV file
    [Arguments]    ${corrupted_file}    ${output_file}
    
    Log    🔧 Attempting to recover corrupted CSV: ${corrupted_file}    INFO
    
    ${content}=    Get File    ${corrupted_file}
    ${lines}=    Split To Lines    ${content}
    
    ${recovered_lines}=    Create List
    ${error_count}=    Set Variable    0
    
    FOR    ${line_num}    ${line}    IN ENUMERATE    @{lines}    start=1
        ${is_valid}=    Run Keyword And Return Status    Validate CSV Line    ${line}
        IF    ${is_valid}
            Append To List    ${recovered_lines}    ${line}
        ELSE
            Log    ⚠️ Skipping invalid line ${line_num}: ${line}    WARN
            ${error_count}=    Evaluate    ${error_count} + 1
        END
    END
    
    # Save recovered data
    ${recovered_content}=    Catenate    SEPARATOR=\n    @{recovered_lines}
    Create File    ${output_file}    ${recovered_content}
    
    ${total_lines}=    Get Length    ${lines}
    ${recovered_lines_count}=    Get Length    ${recovered_lines}
    
    Log    📊 Recovery summary:    INFO
    Log    - Total lines: ${total_lines}    INFO
    Log    - Recovered lines: ${recovered_lines_count}    INFO
    Log    - Error lines: ${error_count}    INFO
    
    RETURN    ${output_file}

Validate CSV Line
    [Documentation]    Validates a single CSV line for common issues
    [Arguments]    ${line}
    
    # Skip empty lines
    ${trimmed_line}=    Strip String    ${line}
    IF    '${trimmed_line}' == ''
        RETURN    ${FALSE}
    END
    
    # Check for basic CSV structure
    ${field_count}=    Count String Occurrences    ${line}    ,
    IF    ${field_count} == 0
        RETURN    ${FALSE}
    END
    
    # Check for unmatched quotes
    ${quote_count}=    Count String Occurrences    ${line}    "
    ${is_even_quotes}=    Evaluate    ${quote_count} % 2 == 0
    
    RETURN    ${is_even_quotes}
```

---

## 📚 Related Documentation

- **[PostgreSQL to S3 Test Workflow Guide](postgres_to_s3_test_workflow_guide.md)** - Detailed example of data loading in action
- **[Robot Framework Test Execution Flow](robot_framework_test_execution_flow.md)** - Understanding test initialization and data setup
- **[SnapLogic Common Robot Library Guide](snaplogic_common_robot_library_guide.md)** - Available data manipulation keywords
- **[Docker Compose Guide](../infra_setup_guides/docker_compose_guide.md)** - Database and service setup for testing

---

## 📚 Explore More Documentation

💡 **Need help finding other guides?** Check out our **[📖 Complete Documentation Reference](../../reference.md)** for a comprehensive overview of all available tutorials, how-to guides, and quick start paths. It's your one-stop navigation hub for the entire SnapLogic Test Framework documentation!

---

*This comprehensive guide provides the foundation for effective test data management in SnapLogic Robot Framework testing environments, ensuring reliable, maintainable, and scalable test automation practices.*