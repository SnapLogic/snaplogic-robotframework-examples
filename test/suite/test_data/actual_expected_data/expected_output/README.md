# SRC Directory Structure

This directory contains pipeline configurations and build tools for the SnapLogic test framework.

## Directory Structure

```
src/
├── pipelines/                 # SnapLogic pipeline files (.slp)
│   ├── postgres_to_s3.slp    # PostgreSQL to S3 export pipeline
│   └── oracle.slp             # Oracle database pipeline
├── tools/                     # Build and deployment tools
│   └── requirements.txt       # Python dependencies
└── README.md                  # This documentation file
```

## Data Files Location

**Important**: The test data files are NOT located in the `src/` directory. They are located in the `test/` directory structure:

```
test/suite/test_data/actual_expected_data/
├── input_data/                # Input data files for testing
│   ├── employees.csv          # Source CSV data (2 rows)
│   └── employees.json         # Source JSON data (2 rows)
├── expected_output/           # Expected output files from pipeline
│   ├── demo-bucket/
│   │   ├── employees.csv      # Expected CSV with ID column (4 rows)
│   │   └── employees.json     # Expected JSON with ID field (4 rows)
│   └── README.md              # Expected output documentation
└── actual_output/             # Actual files downloaded from S3
    └── demo-bucket/           # Files downloaded during test execution
        └── (files created dynamically during testing)
```

## Pipeline Files

### postgres_to_s3.slp
- **Purpose**: Exports data from PostgreSQL database to S3/MinIO bucket
- **Input**: PostgreSQL table (employees)
- **Output**: CSV/JSON files in S3 bucket (demo-bucket)
- **Used by**: `test/suite/pipeline_tests/postgres_to_s3.robot`

### oracle.slp
- **Purpose**: Oracle database operations pipeline
- **Used by**: `test/suite/pipeline_tests/oracle.robot`

## Data Flow Overview

### 1. Input Phase
- **CSV Input**: `test/suite/test_data/actual_expected_data/input_data/employees.csv` (2 rows) → PostgreSQL Database
- **JSON Input**: `test/suite/test_data/actual_expected_data/input_data/employees.json` (2 rows) → PostgreSQL Database
- **Total in DB**: 4 rows with auto-generated ID column

### 2. Pipeline Processing
- **Pipeline Location**: `src/pipelines/postgres_to_s3.slp`
- **PostgreSQL → S3**: Pipeline exports 4 rows from database to S3 bucket
- **S3 Storage**: Files stored in MinIO S3 (demo-bucket)

### 3. Output Phase  
- **S3 → Local**: Files downloaded from S3 to `test/suite/test_data/actual_expected_data/actual_output/demo-bucket/`
- **Comparison**: Actual output vs Expected output validation

## Robot Framework Variable Mapping

```robotframework
# Pipeline configuration (from src/)
${pipeline_file_path}        = ${CURDIR}/../../../src/pipelines

# Input data (from test/suite/test_data/)
${CSV_DATA_TO_DB}           = ${CURDIR}/../test_data/actual_expected_data/input_data/employees.csv
${JSON_DATA_TO_DB}          = ${CURDIR}/../test_data/actual_expected_data/input_data/employees.json

# Output data (base directory - bucket subdirectory created automatically)
${TEST_DATA_DIR}            = ${CURDIR}/../test_data/actual_expected_data/actual_output

# Expected data (for validation)
${EXPECTED_OUTPUT_DIR}      = ${CURDIR}/../test_data/actual_expected_data/expected_output/demo-bucket
```

## Directory Creation

The download process automatically creates:
- `test/suite/test_data/actual_expected_data/actual_output/demo-bucket/` (bucket name appended automatically)
- Files are downloaded to: `${TEST_DATA_DIR}/${DEMO_BUCKET}/filename`

## File Content Examples

### Input CSV (employees.csv)
```csv
name,role,salary
Swapna,Engineer,90000
Bob,Analyst,75000
```

### Input JSON (employees.json)
```json
[
  {"name": "Swapna", "role": "Engineer", "salary": 90000},
  {"name": "Bob", "role": "Analyst", "salary": 75000}
]
```

### Expected Output CSV (after pipeline)
```csv
"id","name","role","salary"
"1","Swapna","Engineer","90000"
"2","Bob","Analyst","75000"
"3","Swapna","Engineer","90000"
"4","Bob","Analyst","75000"
```

## Tools Directory

### requirements.txt
Contains Python dependencies needed for the test framework:
- Robot Framework libraries
- Database drivers (psycopg2 for PostgreSQL)
- AWS/S3 libraries (boto3 for MinIO)
- Other testing dependencies

## Usage in Tests

1. **Pipeline Import**: SnapLogic pipelines from `src/pipelines/` are imported into SnapLogic platform
2. **Data Loading**: CSV and JSON files from `test/suite/test_data/actual_expected_data/input_data/` loaded into PostgreSQL
3. **Pipeline Execution**: SnapLogic pipeline exports data to S3
4. **File Download**: S3 files downloaded to `test/suite/test_data/actual_expected_data/actual_output/demo-bucket/`
5. **Validation**: Compare actual vs expected output files
6. **Cleanup**: `actual_output/` directory recreated for each test run

## Development Notes

- **Pipeline Development**: Use SnapLogic Designer to create/modify `.slp` files
- **Version Control**: Pipeline files (.slp) should be version controlled
- **Dependencies**: Install requirements from `tools/requirements.txt` before running tests
- **Path Resolution**: All paths in Robot Framework tests are relative to the test file location

## Directory Permissions

- **pipelines/**: Read-only pipeline definition files
- **tools/**: Read-only configuration files
- **Test data files**: Located in `test/suite/test_data/` (see test directory structure)