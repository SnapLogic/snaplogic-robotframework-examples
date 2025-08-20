# Snowflake Database Integration Test Suite 🚀

## 📖 Documentation

[![View Documentation](https://img.shields.io/badge/📖_View-Test_Documentation-29B5E8?style=for-the-badge)](https://htmlpreview.github.io/?https://raw.githubusercontent.com/SnapLogic/snaplogic-robotframework-examples/refs/heads/main/test/suite/pipeline_tests/snowflake/snowflake_test_documentation.html)

**[📊 View Live HTML Documentation](https://htmlpreview.github.io/?https://raw.githubusercontent.com/SnapLogic/snaplogic-robotframework-examples/refs/heads/main/test/suite/pipeline_tests/snowflake/snowflake_test_documentation.html)** - Comprehensive test suite documentation with interactive navigation

## 📋 Overview

This test suite validates Snowflake database integration with SnapLogic pipelines using Robot Framework. It demonstrates comprehensive testing approaches including database operations, pipeline execution, and data validation.

### Key Features
- ✅ **Database-Agnostic Operations**: Generic SQL keywords that work across different databases
- ✅ **Two-Layer Validation**: Database validation + Pipeline output validation
- ✅ **SnapLogic Integration**: Account creation, pipeline import, task execution
- ✅ **Multiple Data Formats**: Support for CSV and JSON data loading
- ✅ **Comprehensive Cleanup**: Automatic cleanup of test artifacts
- ✅ **Environment Management**: Secure credential handling via .env file

## 🏗️ Test Suite Structure

```
snowflake/
├── README.md                           # This file
├── snowflake_test_documentation.html  # Interactive HTML documentation
├── snowflake_tests_dblibrary.robot   # Main test suite using DatabaseLibrary
├── snowflake_tests_python_lib.robot  # Alternative test suite using Python library
└── test_data/                        # Test data files
    ├── employees.json                 # JSON test data (actively used)
    └── employees.csv                  # CSV test data (available for use)
```

## 🧪 Test Cases

| #   | Test Case                          | Description                                  | Tags                             |
| --- | ---------------------------------- | -------------------------------------------- | -------------------------------- |
| 1   | **Create Account**                 | Creates Snowflake account in SnapLogic       | `regression`, `snowflakeaccount` |
| 2   | **Upload Expression Library**      | Uploads expression library to shared folder  | `upload_expression_library`      |
| 3   | **Import Pipeline**                | Imports Snowflake pipeline (.slp)            | `regression`                     |
| 4   | **Create Triggered Task**          | Creates triggered task with parameters       | `regression`                     |
| 5   | **Execute Triggered Task**         | Executes task with updated parameters        | `regression`                     |
| 6   | **Create Table For DB Operations** | Creates employees tables in Snowflake        | `data_setup`, `regression`       |
| 7   | **Setup JSON Table**               | Creates table for JSON data loading          | `json`                           |
| 8   | **Load JSON Data**                 | Loads JSON employee data to Snowflake        | `json`                           |
| 9   | **Verify Expected Results**        | Validates data directly in Snowflake DB      | `connection`, `generic_sql`      |
| 10  | **Compare CSV Output**             | Compares pipeline output with expected files | `regression`                     |

## 🔧 Setup & Configuration

### Prerequisites

1. **Environment Variables** - Create a `.env` file with:
```bash
# Snowflake Configuration
SNOWFLAKE_ACCOUNT=snaplogic
SNOWFLAKE_USERNAME=Bigdatasnaplogic
SNOWFLAKE_PASSWORD=your_password_here
SNOWFLAKE_DATABASE=FDLDB
SNOWFLAKE_SCHEMA=INTUIT
SNOWFLAKE_WAREHOUSE=ELT_XS_WH
SNOWFLAKE_ROLE=SYSADMIN

# SnapLogic Configuration
ORG_NAME=your_org
PROJECT_SPACE=your_space
PROJECT_NAME=your_project
GROUNDPLEX_NAME=your_groundplex
GROUNDPLEX_LOCATION_PATH=your_location
```

2. **Required Libraries**
```bash
pip install robotframework
pip install robotframework-databaselibrary
pip install snowflake-connector-python
pip install python-dotenv
```

3. **Docker Setup** (if using containerized environment)
```bash
docker-compose up -d
```

## 🚀 Running Tests

### Run All Tests
```bash
robot snowflake_tests_dblibrary.robot
```

### Run Specific Tags
```bash
# Run regression tests only
robot --include regression snowflake_tests_dblibrary.robot

# Run data setup tests
robot --include data_setup snowflake_tests_dblibrary.robot

# Run generic SQL tests
robot --include generic_sql snowflake_tests_dblibrary.robot
```

### Run with Custom Output Directory
```bash
robot --outputdir results snowflake_tests_dblibrary.robot
```

### Run with Variable Overrides
```bash
robot -v SNOWFLAKE_DATABASE:TEST_DB snowflake_tests_dblibrary.robot
```

## 🔍 Two-Layer Validation Approach

### Layer 1: Snowflake Database Validation
- Direct validation against Snowflake database
- Verifies data insertion, updates, and queries
- Ensures database operations work correctly
- Uses generic SQL keywords for portability

### Layer 2: Pipeline Output Validation
- Validates SnapLogic pipeline execution
- Compares actual output files with expected results
- Ensures end-to-end data processing accuracy
- Verifies no data loss during transformation

## 📊 Project Status (As of 08/20)

### ✅ Completed
- [x] List requirements from Caterpillar experience
- [x] Build POC for Dylan's Snowflake pipeline
- [x] Implement two-layer validation approach
- [x] Create comprehensive test documentation

### 🔄 In Progress
- [ ] Define Intuit-specific requirements
- [ ] Schedule kick-off call (@riyengar @goutamb to inform @Swapna)
- [ ] Prepare for Intuit review (Target: 8/22)

### 📝 Requirements Needed from Intuit
- **Data Loading**: Preferred methods and formats
- **Test Data**: Can dummy data be used? Privacy considerations?
- **Verification Methods**: Database vs Output validation preference
- **Pipeline Scope**: Which pipelines need testing?

## 🧹 Cleanup Operations

The suite includes comprehensive cleanup that automatically removes:
- **Tables**: employees, employees2, control_date, TEST_SNOWFLAKE_TABLE, etc.
- **Views**: high_earners, secure_employees, mv_high_earners
- **Snowflake Objects**: stages, streams, tasks, stored procedures
- **Temporary Files**: test_output.csv, test_output.json, employees_export.csv

## 🔐 Security Considerations

For sensitive data testing, consider:
- Using encrypted test data files
- Environment variables for credentials (never commit .env)
- Data masking and tokenization
- Secure cleanup of test artifacts
- Audit logging for compliance

## 📈 Extensibility

This framework can be extended for:
- Multiple pipeline testing
- Additional database platforms
- Complex validation scenarios
- Performance testing
- Error scenario testing

## 🐛 Troubleshooting

| Issue                  | Possible Cause               | Solution                                             |
| ---------------------- | ---------------------------- | ---------------------------------------------------- |
| Connection Failed      | Invalid credentials          | Check .env file and Snowflake access                 |
| Table Already Exists   | Previous run didn't clean up | Run cleanup manually or use `drop_if_exists=${TRUE}` |
| Pipeline Import Failed | Pipeline file not found      | Verify pipeline_file_path                            |
| Data Mismatch          | Pipeline processing error    | Check SnapLogic dashboard logs                       |
| Cleanup Failed         | Insufficient permissions     | Ensure DROP privileges on test objects               |

## 👥 Team & Contact

**Development Team:**
- @Swapna - POC Development & Implementation
- @bthomas - Project Coordination
- @riyengar - Kick-off Call Coordination



**For Questions:**
- Check the [HTML Documentation](https://htmlpreview.github.io/?https://raw.githubusercontent.com/SnapLogic/snaplogic-robotframework-examples/refs/heads/main/test/suite/pipeline_tests/snowflake/snowflake_test_documentation.html)
- Review test execution logs in `results/` directory
- Contact the development team via Slack/Email

## 📚 Additional Resources

- [Robot Framework Documentation](https://robotframework.org/)
- [DatabaseLibrary Documentation](https://github.com/MarketSquare/Robotframework-DatabaseLibrary)
- [Snowflake Connector Python](https://docs.snowflake.com/en/user-guide/python-connector)
- [SnapLogic Documentation](https://docs-snaplogic.atlassian.net/)

## 📄 License

This test suite is part of the SnapLogic Robot Framework Examples repository.

---

**Last Updated:** August 20, 2024  
**Version:** 1.0.0  

