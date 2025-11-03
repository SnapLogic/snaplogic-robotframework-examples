# Pre-Configured Accounts - Quick Reference

This document provides a high-level overview of all pre-configured accounts available for testing.



---

## 🗄️ Database Accounts

| Database   | Account Name     | Container      | Host Port | Default User | Default Password | Config File       |
| ---------- | ---------------- | -------------- | --------- | ------------ | ---------------- | ----------------- |
| PostgreSQL | `postgres_acc`   | `postgres-db`  | 5432      | `snaplogic`  | `snaplogic`      | `.env.postgres`   |
| MySQL      | `mysql_acct`     | `mysql-db`     | 3306      | `testuser`   | `snaplogic`      | `.env.mysql`      |
| SQL Server | `sqlserver_acct` | `sqlserver-db` | 1433      | `sa`         | `Snaplogic123!`  | `.env.sqlserver`  |
| Oracle     | `oracle_acct`    | `oracle-db`    | 1521      | `SYSTEM`     | `Oracle123`      | `.env.oracle`     |
| Snowflake  | `snowflake_acct` | External ☁️    | 443       | Custom       | Custom           | `.env.snowflake`  |
| DB2        | `db2_acct`       | `db2-db`       | 50000     | TBD          | TBD              | `.env.db2`        |
| Teradata   | `teradata_acct`  | `teradata-db`  | 1025      | TBD          | TBD              | `.env.teradata`   |

**Location:** `env_files/database_accounts/`

**Note:** 
- ☁️ **Snowflake** is an external cloud service (not Docker-managed)
- Credentials must be configured in your local `.env` file
- Account identifier is auto-extracted from `SNOWFLAKE_HOSTNAME`
- See `.env.snowflake` for complete configuration details

---

## 📨 Messaging Service Accounts

| Service       | Account Name | Container  | Host Port | Bootstrap Server | UI Port | Config File  |
| ------------- | ------------ | ---------- | --------- | ---------------- | ------- | ------------ |
| Kafka (KRaft) | `kafka_acct` | `kafka`    | 9092      | `kafka:29092`    | 8082    | `.env.kafka` |
| JMS/ActiveMQ  | `jms_acct`   | `activemq` | TBD       | TBD              | TBD     | `.env.jms`   |

**Location:** `env_files/messaging_service_accounts/`



---

## 🔧 Mock Service Accounts

| Service         | Account Name      | Container      | API Port | Console Port | Access Key   | Secret Key   | Config File       |
| --------------- | ----------------- | -------------- | -------- | ------------ | ------------ | ------------ | ----------------- |
| S3 (MinIO)      | `s3_account`      | `minio`        | 9010     | 9011         | `minioadmin` | `minioadmin` | `.env.s3`         |
| Email (MailDev) | `mail_acct`       | `maildev-test` | 1025     | 1080         | -            | -            | `.env.email`      |
| Salesforce      | `salesforce_acct` | -              | -        | -            | Mock         | Mock         | `.env.salesforce` |

**Location:** `env_files/mock_service_accounts/`

---



**Last Updated:** October 2025 | **Status:** ✅ Active
