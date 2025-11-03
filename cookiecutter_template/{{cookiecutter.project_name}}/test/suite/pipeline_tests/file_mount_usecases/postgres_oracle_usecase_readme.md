# PostgreSQL to Oracle Data Pipeline Test Suite

## Overview

This Robot Framework test suite demonstrates and validates an end-to-end data migration pipeline from PostgreSQL to Oracle using SnapLogic integration platform. It showcases enterprise-grade data movement with comprehensive validation.

## 🎯 Purpose

The test suite serves multiple purposes:
- **Functional Validation**: Ensures data can be successfully transferred from PostgreSQL to Oracle
- **Data Integrity**: Validates that data remains intact during the transfer process
- **Integration Testing**: Tests the complete integration between PostgreSQL, Oracle, and SnapLogic
- **Regression Prevention**: Automated tests to catch issues early in the development cycle
- **Documentation**: Self-documenting test cases that serve as living documentation

## 📋 Test Scenario

### Business Use Case
A common enterprise scenario where data needs to be migrated from a PostgreSQL operational database to an Oracle data warehouse for analytics and reporting. The pipeline handles employee data as a representative example.

### Data Flow
```
PostgreSQL (Source) → SnapLogic Pipeline → Oracle (Target) → CSV Export → Validation
```

## 🔧 Technical Components

### Prerequisites
- PostgreSQL database instance
- Oracle database instance
- SnapLogic platform with active Groundplex
- Docker environment for container management
- Robot Framework with required libraries

### Libraries Used
- **DatabaseLibrary**: Generic database operations
- **psycopg2**: PostgreSQL driver
- **oracledb**: Oracle driver
- **CSVLibrary**: CSV file handling
- **OperatingSystem**: File system operations

## 📊 Test Coverage

### 1. **Environment Setup**
- Creates SnapLogic accounts for both databases
- Establishes database connections
- Validates Groundplex availability

### 2. **Database Preparation**
```sql
-- PostgreSQL Source
CREATE TABLE employees (
    name VARCHAR(100),
    role VARCHAR(50),
    salary NUMERIC
);

-- Oracle Target
CREATE TABLE employees (
    name VARCHAR2(100),
    role VARCHAR2(50),
    salary NUMBER
);
```

### 3. **Data Loading**
- Loads employee data from CSV into PostgreSQL
- Validates row counts after loading
- Ensures data integrity in source

### 4. **File Protocol Operations**
Demonstrates advanced file handling capabilities:
- Upload expression libraries using `file:///` protocol
- Support for multiple mount points:
  - `/opt/snaplogic/expression-libraries`
  - `/app/test/suite/test_data`
- Copy and list operations on mounted volumes

### 5. **Pipeline Execution**
- Imports PostgreSQL-to-Oracle pipeline (`.slp` file)
- Creates triggered task for execution
- Executes data transfer with monitoring
- Handles errors and retries

### 6. **Data Validation**
Multiple validation approaches:
- **Row Count Validation**: Ensures all rows transferred
- **CSV Export**: Exports Oracle data to CSV
- **Data Comparison**: Compares actual vs expected output
- **Sort Order Testing**: Validates data with different sort orders

## 🚀 Test Execution

### Running the Test Suite
```bash
# Run all tests
make robot-run-all-tests TAGS=postgres_s3
```

### Test Structure
```
postgres_to_oracle.robot
├── Settings (Libraries, Resources)
├── Variables (Configuration)
├── Test Cases
│   ├── Create Account
│   ├── Create postgres table
│   ├── Load CSV Data
│   ├── Create oracle table
│   ├── Upload Files
│   ├── Import Pipeline
│   ├── Create Triggered Task
│   ├── Execute Pipeline
│   ├── Export Oracle Data
│   └── Compare Results
└── Keywords (Reusable functions)
```

## 📁 File Structure

```
test/suite/pipeline_tests/psdemo_usecase1/
├── postgres_to_oracle.robot          # Main test file
├── postgres_oracle_usecase_readme.md # This file
└── test_data/
    ├── actual_expected_data/
    │   ├── input_data/
    │   │   └── employees.csv         # Source data
    │   ├── actual_output/            # Generated exports
    │   └── expected_output/          # Expected results
    └── expression_libraries/
        └── test.expr                 # Custom transformations
```

## 🔍 Key Features

### 1. **Comprehensive Error Handling**
- Pre-execution validation (source data exists)
- Pipeline execution monitoring
- Post-execution verification
- Detailed error logging

### 2. **Multiple Export Formats**
```robot
# Different sort orders for validation
oracle    employees    ${ACTUAL_DATA_DIR}    None         oracle_employees.csv
oracle    employees    ${ACTUAL_DATA_DIR}    name         oracle_employees_sorted_by_name.csv
oracle    employees    ${ACTUAL_DATA_DIR}    salary DESC  oracle_employees_sorted_by_salary.csv
```

### 3. **Data Integrity Checks**
- Header structure validation
- Row count verification
- Field-level value comparison
- NULL value handling
- Special character handling in CSV

## 🎯 Success Criteria

The test suite passes when:
1. ✅ All database accounts created successfully
2. ✅ Source and target tables created without errors
3. ✅ CSV data loaded into PostgreSQL
4. ✅ Pipeline imported and deployed
5. ✅ Data transferred completely to Oracle
6. ✅ Oracle data exported to CSV successfully
7. ✅ Exported data matches expected output



### Debug Commands
```bash
# Check PostgreSQL data
docker exec postgres-db psql -U user -d db -c "SELECT COUNT(*) FROM employees;"

# Check Oracle data
docker exec oracle-db sqlplus user/pass@FREEPDB1 <<< "SELECT COUNT(*) FROM employees;"

# View Groundplex logs
docker logs snaplogic-groundplex
```

## 📈 Benefits

- **Automation**: Reduces manual testing effort by 90%
- **Reliability**: Consistent test execution
- **Speed**: Complete validation in minutes vs hours
- **Documentation**: Tests serve as living documentation
- **Confidence**: Ensures data integrity before production

## 🔄 Extension Points

The test suite can be extended to:
- Handle multiple tables
- Add data transformation validation
- Include performance benchmarks
- Test error scenarios
- Add data type conversion tests
- Include incremental load scenarios

## 📝 Maintenance

Regular maintenance tasks:
- Update test data as schemas evolve
- Refresh expected output files
- Update pipeline configurations
- Review and update documentation
- Add new test scenarios as needed

## 🤝 Contributing

When adding new tests:
1. Follow existing naming conventions
2. Add comprehensive documentation
3. Include positive and negative test cases
4. Update this README
5. Test locally before committing

