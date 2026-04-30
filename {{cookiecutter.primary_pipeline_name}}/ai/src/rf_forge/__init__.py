"""
RF Forge - AI-powered CLI for generating Robot Framework test cases
for SnapLogic pipeline testing.

Standalone utility skills — each generates specific test artifacts:
- /create-account: SnapLogic account test cases
- /import-pipeline: Pipeline import test cases
- /upload-file: File upload test cases
- /create-triggered-task: Triggered task test cases
- /compare-csv: CSV comparison test cases
- /verify-data-in-db: Database verification test cases
- /export-data-to-csv: Data export test cases
- /end-to-end-pipeline-verification: Complete E2E test suite

Example CLI usage:
    rf-forge create-account "Create an Oracle account" --codebase-path ./my-project
"""

__version__ = "0.1.0"
