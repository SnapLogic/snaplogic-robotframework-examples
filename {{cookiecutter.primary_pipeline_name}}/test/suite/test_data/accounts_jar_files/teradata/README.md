# Teradata JDBC Drivers

This directory should contain the Teradata JDBC driver files required for SnapLogic to connect to Teradata databases.

## Required Files

1. **terajdbc4.jar** - Main Teradata JDBC driver
2. **tdgssconfig.jar** - Teradata GSS (Global Security Services) configuration

## How to Obtain the Drivers

1. Visit the Teradata Downloads page: https://downloads.teradata.com/
2. Navigate to "Teradata Tools and Utilities" → "Teradata JDBC Driver"
3. Download the latest JDBC driver package
4. Extract the following files from the package:
   - `terajdbc4.jar`
   - `tdgssconfig.jar`
5. Place both files in this directory

## Version Compatibility

- Recommended: Teradata JDBC Driver 17.20 or later
- Compatible with Teradata Database 16.x and 17.x

## File Verification

After placing the files, verify they exist:
```bash
ls -la /Users/spothana/QADocs/SNAPLOGIC_RF_EXAMPLES2/snaplogic-robotframework-examples/test/suite/test_data/accounts_jar_files/teradata/
```

Expected output:
```
terajdbc4.jar
tdgssconfig.jar
```

## Notes

- These files are required for the Teradata test suite to run successfully
- The files will be uploaded to SnapLogic during test execution
- Ensure the files have read permissions
