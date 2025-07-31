# SnapLogic Test Data Directory Structure

## Overview
This directory contains test data for SnapLogic pipeline testing, including input data, expected output data, and actual output data generated during test execution.

## Directory Structure
```
actual_expected_data/
├── input_data/          # Source data files for testing
├── expected_output/     # Expected results for comparison
├── actual_output/       # Auto-created by SnapLogic during pipeline execution
└── expression_libraries/ # Expression library files
```

## Important: SnapLogic Auto-Creates Directories

### How Directory Creation Works

**SnapLogic CAN automatically create directories** when using the File Writer Snap with local file protocol. This is a key behavior that explains why certain directories exist without explicit creation in test code.

### Conditions for Auto-Creation

SnapLogic will auto-create directories when:

1. **Using local file protocol**: URLs like `file:///opt/snaplogic/test_data/...`
2. **Parent directory exists and is writable**: The base path must be mounted and accessible
3. **File Writer Snap is configured**: The snap will create missing directories in the path

### Example

When a pipeline writes to:
```
file:///opt/snaplogic/test_data/actual_expected_data/actual_output/employee_mysql.csv
```

SnapLogic will:
- Check if `/opt/snaplogic/test_data/actual_expected_data/` exists (base path)
- Create the `actual_output` directory if it doesn't exist
- Write the file `employee_mysql.csv`

### Docker Volume Mapping

In our test environment, the local path is mapped to the container:
```yaml
volumes:
  - ../test/suite/test_data:/opt/snaplogic/test_data
```

This means:
- **Local path**: `/test/suite/test_data/actual_expected_data/actual_output`
- **Container path**: `/opt/snaplogic/test_data/actual_expected_data/actual_output`
- **SnapLogic creates**: The directory in the container, which appears on the host

## Test Implementation Notes

### Why Tests Don't Create Directories

The Robot Framework tests don't explicitly create the `actual_output` directory because:

1. **SnapLogic handles it**: The pipeline's File Writer Snap creates it automatically
2. **Test assumes pipeline behavior**: Tests rely on SnapLogic's directory creation
3. **Cleaner test code**: No need for directory setup/teardown in tests

### Variable Definition in Tests

Tests define the path as:
```robot
${ACTUAL_DATA_DIR}  /app/test/suite/test_data/actual_expected_data/actual_output
```

Note: The `/app/` prefix is used because tests run inside the Docker container where the test directory is mounted at `/app/test`.

## Best Practices

1. **Don't manually create** the `actual_output` directory - let SnapLogic handle it
2. **Ensure base paths exist** - Parent directories must be present and writable
3. **Use consistent paths** - Match the paths between pipelines and test validations
4. **Clean up between tests** - Consider clearing output directories in test teardown if needed

## Troubleshooting

If directories are not being created:

1. **Check permissions**: Ensure the base path is writable
2. **Verify mounts**: Confirm Docker volumes are properly mounted
3. **Check file protocol**: Must use `file:///` protocol for local writes
4. **Review pipeline logs**: Check for File Writer Snap errors

## Related Documentation

- [SnapLogic File Writer Snap Documentation](https://docs-snaplogic.atlassian.net/wiki/spaces/SD/pages/1438814/File+Writer)
- [Docker Volume Mounting Guide](../../../../../../../docker/README.md)
- [Test Framework Overview](../../../README.md)
