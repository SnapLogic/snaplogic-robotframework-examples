# ============================================
# IBM DB2 DATABASE ACCOUNT
# ============================================
# DB2 database configuration for local Docker instance
# Container: db2-db
# ============================================

# Account payload file name can be found at this location "../../test/suite/test_data/accounts_payload"
DB2_ACCOUNT_PAYLOAD_FILE_NAME=acc_db2.json

DB2_ACCOUNT_NAME=db2_acct
DB2_HOST=db2-db
DB2_DATABASE=TESTDB
DB2_PORT=50000
DB2_USER=db2inst1
DB2_PASSWORD=snaplogic
DB2_JDBC_JAR=db2jcc4.jar
DB2_JDBC_DRIVER_CLASS=com.ibm.db2.jcc.DB2Driver
DB2_JDBC_URL=jdbc:db2://host.docker.internal:50000/TESTDB
DB2_TEST_QUERY=SELECT 1 FROM SYSIBM.SYSDUMMY1

# Port mapping configuration
# Host port that maps to container port 50000
DB2_HOST_PORT=50000

DB2_URL_PROPERTIES=[]

# Example: enable SSL + set current schema — uncomment and replace the line above:
# DB2_URL_PROPERTIES=[{"urlPropertyName":{"value":"sslConnection","expression":false},"urlPropertyValue":{"value":"true","expression":false}},{"urlPropertyName":{"value":"currentSchema","expression":false},"urlPropertyValue":{"value":"MYSCHEMA","expression":false}}]


# ============================================
# URL PROPERTIES (per-customer override)
# ============================================
# This is the "URL properties" table from the SnapLogic Edit Account UI.
# It's injected as a raw JSON array into acc_db2.json — NOT a string.
#
# Rules:
#   - Bare JSON only. Do NOT wrap the value in quotes (single or double).
#     This framework's .env parser keeps quotes as literal characters,
#     which breaks the rendered JSON.
#   - Must be on a single line (no line breaks).
#   - Use [] for "no URL properties".

# Validate (run from project root, requires tools container running):
#   docker exec -it snaplogic-test-example-tools-container python3 -c \
#     "import os; from dotenv import load_dotenv; \
#      load_dotenv('/app/env_files/database_accounts/.env.db2'); \
#      import json; print(json.loads(os.environ['DB2_URL_PROPERTIES']))"
#   ✅ prints a Python list → JSON is parseable
#   ❌ JSONDecodeError → fix the value before running tests
#
# The real test is still: make robot-run-tests-no-gp TAGS="db2"
