# ============================================
# IBM DB2 DATABASE ACCOUNT
# ============================================
# DB2 database configuration for local Docker instance
# Container: db2-db
# ============================================

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
