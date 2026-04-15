*** Variables ***
# ═══════════════════════════════════════════════════════════════
# Baseline Data Extract Pipeline — SQL Queries & DDL
# ═══════════════════════════════════════════════════════════════
# Contains all SQL statements for the baseline tests:
#   - DDL (CREATE TABLE)
#   - Seed data (INSERT)
#   - Prerequisite queries (SELECT)
#   - Prerequisite updates (UPDATE)
# ═══════════════════════════════════════════════════════════════


# ─────────────────────────────────────────────────────────────
# DDL — PROCESS_CONFIG table
# ─────────────────────────────────────────────────────────────

${SQL_CREATE_PROCESS_CONFIG}
...    CREATE TABLE PROCESS_CONFIG (
...        PROCESS_CD            VARCHAR2(25 BYTE)       NOT NULL,
...        PROCESS_ORDER_SEQ     NUMBER(3)               NOT NULL,
...        REC_INACTIVE_FLAG     VARCHAR2(1 BYTE)        NOT NULL,
...        CONFIG_CD             VARCHAR2(30 BYTE)       NOT NULL,
...        CONFIG_VALUE          VARCHAR2(200 BYTE)      NOT NULL,
...        REC_CREATE_USERID     VARCHAR2(30 BYTE)       NOT NULL,
...        REC_CREATE_TIMESTAMP  DATE                    NOT NULL,
...        LAST_UPD_USERID       VARCHAR2(30 BYTE)       NOT NULL,
...        LAST_UPD_TIMESTAMP    DATE                    NOT NULL
...    )


# ─────────────────────────────────────────────────────────────
# DDL — PROCESS table (master process registry)
# Referenced by MAIN_CONFIG_QUERY in config JSON
# ─────────────────────────────────────────────────────────────

${SQL_CREATE_PROCESS}
...    CREATE TABLE PROCESS (
...        PROCESS_CD            VARCHAR2(25 BYTE)       NOT NULL,
...        PROCESS_DESC          VARCHAR2(200 BYTE),
...        REC_INACTIVE_FLAG     VARCHAR2(1 BYTE)        DEFAULT 'A' NOT NULL,
...        REC_CREATE_USERID     VARCHAR2(30 BYTE)       NOT NULL,
...        REC_CREATE_TIMESTAMP  DATE                    NOT NULL,
...        LAST_UPD_USERID       VARCHAR2(30 BYTE)       NOT NULL,
...        LAST_UPD_TIMESTAMP    DATE                    NOT NULL,
...        CONSTRAINT PK_PROCESS PRIMARY KEY (PROCESS_CD)
...    )

# ─────────────────────────────────────────────────────────────
# DDL — INTERFACE table (interfaces per process)
# Referenced by MAIN_CONFIG_QUERY in config JSON
# ─────────────────────────────────────────────────────────────

${SQL_CREATE_INTERFACE}
...    CREATE TABLE INTERFACE (
...        INTERFACE_CD          VARCHAR2(50 BYTE)       NOT NULL,
...        PROCESS_CD            VARCHAR2(25 BYTE)       NOT NULL,
...        INTERFACE_DESC        VARCHAR2(200 BYTE),
...        REC_INACTIVE_FLAG     VARCHAR2(1 BYTE)        DEFAULT 'A' NOT NULL,
...        REC_CREATE_USERID     VARCHAR2(30 BYTE)       NOT NULL,
...        REC_CREATE_TIMESTAMP  DATE                    NOT NULL,
...        LAST_UPD_USERID       VARCHAR2(30 BYTE)       NOT NULL,
...        LAST_UPD_TIMESTAMP    DATE                    NOT NULL,
...        CONSTRAINT PK_INTERFACE PRIMARY KEY (INTERFACE_CD, PROCESS_CD)
...    )

# ─────────────────────────────────────────────────────────────
# DDL — INTERFACE_PROCESS_CONFIG table (interface-level config overrides)
# Referenced by MAIN_CONFIG_QUERY in config JSON
# ─────────────────────────────────────────────────────────────

${SQL_CREATE_INTERFACE_PROCESS_CONFIG}
...    CREATE TABLE INTERFACE_PROCESS_CONFIG (
...        INTERFACE_CD          VARCHAR2(50 BYTE)       NOT NULL,
...        PROCESS_CD            VARCHAR2(25 BYTE)       NOT NULL,
...        CONFIG_CD             VARCHAR2(30 BYTE)       NOT NULL,
...        CONFIG_VALUE          VARCHAR2(4000 BYTE),
...        REC_INACTIVE_FLAG     VARCHAR2(1 BYTE)        DEFAULT 'A' NOT NULL,
...        REC_CREATE_USERID     VARCHAR2(30 BYTE)       NOT NULL,
...        REC_CREATE_TIMESTAMP  DATE                    NOT NULL,
...        LAST_UPD_USERID       VARCHAR2(30 BYTE)       NOT NULL,
...        LAST_UPD_TIMESTAMP    DATE                    NOT NULL,
...        CONSTRAINT PK_INTERFACE_PROC_CONFIG PRIMARY KEY (INTERFACE_CD, PROCESS_CD, CONFIG_CD)
...    )

# ─────────────────────────────────────────────────────────────
# DDL — JOB_RUN_STATUS table (pipeline audit tracking)
# Used by INS Job Run Status snap to record pipeline execution start/completion
# ─────────────────────────────────────────────────────────────

${SQL_CREATE_JOB_RUN_STATUS}
...    CREATE TABLE JOB_RUN_STATUS (
...        JOB_RUN_ID            NUMBER                  NOT NULL,
...        JOB_NAME              VARCHAR2(100 BYTE)      NOT NULL,
...        JOB_STATUS_CD         VARCHAR2(3 BYTE)        NOT NULL,
...        START_TIME            DATE                    NOT NULL,
...        END_TIME              DATE,
...        REC_CREATE_USERID     VARCHAR2(50 BYTE)       NOT NULL,
...        REC_CREATE_TIMESTAMP  DATE                    NOT NULL,
...        LAST_UPD_USERID       VARCHAR2(50 BYTE)       NOT NULL,
...        LAST_UPD_TIMESTAMP    DATE                    NOT NULL,
...        SYSTEM_RUN_ID         VARCHAR2(100 BYTE),
...        PROCESS_CD            VARCHAR2(50 BYTE)
...    )

# ─────────────────────────────────────────────────────────────
# DDL — JOB_RUN_ID_SEQ sequence (generates unique job run IDs)
# Used by Get JobRunID snap: SELECT JOB_RUN_ID_SEQ.NEXTVAL FROM DUAL
# ─────────────────────────────────────────────────────────────

${SQL_CREATE_JOB_RUN_ID_SEQ}
...    CREATE SEQUENCE JOB_RUN_ID_SEQ START WITH 1 INCREMENT BY 1 NOCACHE

# ─────────────────────────────────────────────────────────────
# Seed Data — PROCESS table (register the pipeline process)
# ─────────────────────────────────────────────────────────────

${SQL_SEED_PROCESS}
...    INSERT INTO PROCESS
...        (PROCESS_CD, PROCESS_DESC, REC_INACTIVE_FLAG,
...         REC_CREATE_USERID, REC_CREATE_TIMESTAMP, LAST_UPD_USERID, LAST_UPD_TIMESTAMP)
...    VALUES
...        ('PIPELINE_DATA_EXTRACT', 'Baseline Data Extract Pipeline', 'A',
...         'TEST_USER', SYSDATE, 'TEST_USER', SYSDATE)

# ─────────────────────────────────────────────────────────────
# Seed Data — INTERFACE table (register interface for the pipeline)
# ─────────────────────────────────────────────────────────────

${SQL_SEED_INTERFACE}
...    INSERT INTO INTERFACE
...        (INTERFACE_CD, PROCESS_CD, INTERFACE_DESC, REC_INACTIVE_FLAG,
...         REC_CREATE_USERID, REC_CREATE_TIMESTAMP, LAST_UPD_USERID, LAST_UPD_TIMESTAMP)
...    VALUES
...        ('BASELINE_EXTRACT', 'PIPELINE_DATA_EXTRACT', 'Baseline Extract Interface', 'A',
...         'TEST_USER', SYSDATE, 'TEST_USER', SYSDATE)

# ─────────────────────────────────────────────────────────────
# Seed Data — Upstream job (CUST_ODS_LOAD)
# Deliberately set to FAIL prerequisites:
#   LOAD_STATUS_CD = 'I' (Incomplete, not 'C')
#   START_DT = yesterday (not today)
# This ensures the update logic gets exercised during testing.
# ─────────────────────────────────────────────────────────────

${SQL_SEED_UPSTREAM_LOAD_STATUS_CD}
...    INSERT INTO PROCESS_CONFIG
...        (PROCESS_CD, PROCESS_ORDER_SEQ, REC_INACTIVE_FLAG, CONFIG_CD, CONFIG_VALUE,
...         REC_CREATE_USERID, REC_CREATE_TIMESTAMP, LAST_UPD_USERID, LAST_UPD_TIMESTAMP)
...    VALUES
...        ('CUST_ODS_LOAD', 1, 'A', 'LOAD_STATUS_CD', 'I',
...         'TEST_USER', SYSDATE, 'TEST_USER', SYSDATE)

${SQL_SEED_UPSTREAM_START_DT}
...    INSERT INTO PROCESS_CONFIG
...        (PROCESS_CD, PROCESS_ORDER_SEQ, REC_INACTIVE_FLAG, CONFIG_CD, CONFIG_VALUE,
...         REC_CREATE_USERID, REC_CREATE_TIMESTAMP, LAST_UPD_USERID, LAST_UPD_TIMESTAMP)
...    VALUES
...        ('CUST_ODS_LOAD', 1, 'A', 'START_DT', TO_CHAR(SYSDATE - 1, 'MM/DD/YYYY'),
...         'TEST_USER', SYSDATE, 'TEST_USER', SYSDATE)


# ─────────────────────────────────────────────────────────────
# Seed Data — Pipeline config (PIPELINE_DATA_EXTRACT)
# Seeded for future steps (pipeline execution & verification)
# ─────────────────────────────────────────────────────────────

${SQL_SEED_PIPELINE_LOAD_STATUS_CD}
...    INSERT INTO PROCESS_CONFIG
...        (PROCESS_CD, PROCESS_ORDER_SEQ, REC_INACTIVE_FLAG, CONFIG_CD, CONFIG_VALUE,
...         REC_CREATE_USERID, REC_CREATE_TIMESTAMP, LAST_UPD_USERID, LAST_UPD_TIMESTAMP)
...    VALUES
...        ('PIPELINE_DATA_EXTRACT', 1, 'A', 'LOAD_STATUS_CD', 'C',
...         'TEST_USER', SYSDATE, 'TEST_USER', SYSDATE)

${SQL_SEED_PIPELINE_START_DT}
...    INSERT INTO PROCESS_CONFIG
...        (PROCESS_CD, PROCESS_ORDER_SEQ, REC_INACTIVE_FLAG, CONFIG_CD, CONFIG_VALUE,
...         REC_CREATE_USERID, REC_CREATE_TIMESTAMP, LAST_UPD_USERID, LAST_UPD_TIMESTAMP)
...    VALUES
...        ('PIPELINE_DATA_EXTRACT', 1, 'A', 'START_DT', TO_CHAR(SYSDATE, 'MM/DD/YYYY'),
...         'TEST_USER', SYSDATE, 'TEST_USER', SYSDATE)

${SQL_SEED_PIPELINE_LOAD_STATUS_TS}
...    INSERT INTO PROCESS_CONFIG
...        (PROCESS_CD, PROCESS_ORDER_SEQ, REC_INACTIVE_FLAG, CONFIG_CD, CONFIG_VALUE,
...         REC_CREATE_USERID, REC_CREATE_TIMESTAMP, LAST_UPD_USERID, LAST_UPD_TIMESTAMP)
...    VALUES
...        ('PIPELINE_DATA_EXTRACT', 1, 'A', 'LOAD_STATUS_TS', TO_CHAR(SYSDATE - 1, 'MM/DD/YYYY'),
...         'TEST_USER', SYSDATE, 'TEST_USER', SYSDATE)

${SQL_SEED_PIPELINE_FILE_SEQ_NO}
...    INSERT INTO PROCESS_CONFIG
...        (PROCESS_CD, PROCESS_ORDER_SEQ, REC_INACTIVE_FLAG, CONFIG_CD, CONFIG_VALUE,
...         REC_CREATE_USERID, REC_CREATE_TIMESTAMP, LAST_UPD_USERID, LAST_UPD_TIMESTAMP)
...    VALUES
...        ('PIPELINE_DATA_EXTRACT', 1, 'A', 'FILE_SEQ_NO', '000057',
...         'TEST_USER', SYSDATE, 'TEST_USER', SYSDATE)

${SQL_SEED_PIPELINE_EMAIL_NOTIFY}
...    INSERT INTO PROCESS_CONFIG
...        (PROCESS_CD, PROCESS_ORDER_SEQ, REC_INACTIVE_FLAG, CONFIG_CD, CONFIG_VALUE,
...         REC_CREATE_USERID, REC_CREATE_TIMESTAMP, LAST_UPD_USERID, LAST_UPD_TIMESTAMP)
...    VALUES
...        ('PIPELINE_DATA_EXTRACT', 1, 'A', 'EMAIL_NOTIFY', 'test@example.com',
...         'TEST_USER', SYSDATE, 'TEST_USER', SYSDATE)

# ─────────────────────────────────────────────────────────────
# Seed Data — Pipeline connection accounts and operational config
# These values are read by MAIN_CONFIG_QUERY and passed to child pipeline
# ─────────────────────────────────────────────────────────────

${SQL_SEED_PIPELINE_ORA_CONN}
...    INSERT INTO PROCESS_CONFIG
...        (PROCESS_CD, PROCESS_ORDER_SEQ, REC_INACTIVE_FLAG, CONFIG_CD, CONFIG_VALUE,
...         REC_CREATE_USERID, REC_CREATE_TIMESTAMP, LAST_UPD_USERID, LAST_UPD_TIMESTAMP)
...    VALUES
...        ('PIPELINE_DATA_EXTRACT', 1, 'A', 'ORA_CONN_ACCOUNT', '../shared/oracle_acct',
...         'TEST_USER', SYSDATE, 'TEST_USER', SYSDATE)

${SQL_SEED_PIPELINE_JETS_CONN}
...    INSERT INTO PROCESS_CONFIG
...        (PROCESS_CD, PROCESS_ORDER_SEQ, REC_INACTIVE_FLAG, CONFIG_CD, CONFIG_VALUE,
...         REC_CREATE_USERID, REC_CREATE_TIMESTAMP, LAST_UPD_USERID, LAST_UPD_TIMESTAMP)
...    VALUES
...        ('PIPELINE_DATA_EXTRACT', 1, 'A', 'JETS_CONN_ACCOUNT', '../shared/oracle_acct',
...         'TEST_USER', SYSDATE, 'TEST_USER', SYSDATE)

${SQL_SEED_PIPELINE_JETS_SCHEMA}
...    INSERT INTO PROCESS_CONFIG
...        (PROCESS_CD, PROCESS_ORDER_SEQ, REC_INACTIVE_FLAG, CONFIG_CD, CONFIG_VALUE,
...         REC_CREATE_USERID, REC_CREATE_TIMESTAMP, LAST_UPD_USERID, LAST_UPD_TIMESTAMP)
...    VALUES
...        ('PIPELINE_DATA_EXTRACT', 1, 'A', 'JETS_SCHEMA', 'SYSTEM',
...         'TEST_USER', SYSDATE, 'TEST_USER', SYSDATE)

${SQL_SEED_PIPELINE_AWS_CONN}
...    INSERT INTO PROCESS_CONFIG
...        (PROCESS_CD, PROCESS_ORDER_SEQ, REC_INACTIVE_FLAG, CONFIG_CD, CONFIG_VALUE,
...         REC_CREATE_USERID, REC_CREATE_TIMESTAMP, LAST_UPD_USERID, LAST_UPD_TIMESTAMP)
...    VALUES
...        ('PIPELINE_DATA_EXTRACT', 1, 'A', 'AWS_CONN_ACCOUNT', '../shared/s3_account',
...         'TEST_USER', SYSDATE, 'TEST_USER', SYSDATE)

${SQL_SEED_PIPELINE_EMAIL_CONN}
...    INSERT INTO PROCESS_CONFIG
...        (PROCESS_CD, PROCESS_ORDER_SEQ, REC_INACTIVE_FLAG, CONFIG_CD, CONFIG_VALUE,
...         REC_CREATE_USERID, REC_CREATE_TIMESTAMP, LAST_UPD_USERID, LAST_UPD_TIMESTAMP)
...    VALUES
...        ('PIPELINE_DATA_EXTRACT', 1, 'A', 'EMAIL_CONN_ACCOUNT', '../../shared/mail_acct',
...         'TEST_USER', SYSDATE, 'TEST_USER', SYSDATE)

${SQL_SEED_PIPELINE_S3_PATH}
...    INSERT INTO PROCESS_CONFIG
...        (PROCESS_CD, PROCESS_ORDER_SEQ, REC_INACTIVE_FLAG, CONFIG_CD, CONFIG_VALUE,
...         REC_CREATE_USERID, REC_CREATE_TIMESTAMP, LAST_UPD_USERID, LAST_UPD_TIMESTAMP)
...    VALUES
...        ('PIPELINE_DATA_EXTRACT', 1, 'A', 'S3_PATH', 's3://test-bucket/extract/',
...         'TEST_USER', SYSDATE, 'TEST_USER', SYSDATE)

${SQL_SEED_PIPELINE_EXTRACT_FILENM}
...    INSERT INTO PROCESS_CONFIG
...        (PROCESS_CD, PROCESS_ORDER_SEQ, REC_INACTIVE_FLAG, CONFIG_CD, CONFIG_VALUE,
...         REC_CREATE_USERID, REC_CREATE_TIMESTAMP, LAST_UPD_USERID, LAST_UPD_TIMESTAMP)
...    VALUES
...        ('PIPELINE_DATA_EXTRACT', 1, 'A', 'EXTRACT_FILENM', 'BASELINE_EXTRACT_',
...         'TEST_USER', SYSDATE, 'TEST_USER', SYSDATE)

${SQL_SEED_PIPELINE_TERM}
...    INSERT INTO PROCESS_CONFIG
...        (PROCESS_CD, PROCESS_ORDER_SEQ, REC_INACTIVE_FLAG, CONFIG_CD, CONFIG_VALUE,
...         REC_CREATE_USERID, REC_CREATE_TIMESTAMP, LAST_UPD_USERID, LAST_UPD_TIMESTAMP)
...    VALUES
...        ('PIPELINE_DATA_EXTRACT', 1, 'A', 'TERM', '1',
...         'TEST_USER', SYSDATE, 'TEST_USER', SYSDATE)

${SQL_SEED_PIPELINE_SRC_CONN}
...    INSERT INTO PROCESS_CONFIG
...        (PROCESS_CD, PROCESS_ORDER_SEQ, REC_INACTIVE_FLAG, CONFIG_CD, CONFIG_VALUE,
...         REC_CREATE_USERID, REC_CREATE_TIMESTAMP, LAST_UPD_USERID, LAST_UPD_TIMESTAMP)
...    VALUES
...        ('PIPELINE_DATA_EXTRACT', 1, 'A', 'SRC_CONN_ACCOUNT', '../shared/oracle_acct',
...         'TEST_USER', SYSDATE, 'TEST_USER', SYSDATE)


# ─────────────────────────────────────────────────────────────
# Prerequisite Queries — Upstream job check (SELECT)
# ─────────────────────────────────────────────────────────────

${SQL_QUERY_UPSTREAM_STATUS}
...    SELECT P.PROCESS_CD, P.CONFIG_CD, P.CONFIG_VALUE
...    FROM PROCESS_CONFIG P
...    WHERE P.PROCESS_CD = 'CUST_ODS_LOAD'
...    AND CONFIG_CD IN ('START_DT', 'LOAD_STATUS_CD')


# ─────────────────────────────────────────────────────────────
# Pipeline Config Queries — Pipeline's own configuration (SELECT)
# ─────────────────────────────────────────────────────────────

${SQL_QUERY_PIPELINE_CONFIG}
...    SELECT P.PROCESS_CD, P.CONFIG_CD, P.CONFIG_VALUE
...    FROM PROCESS_CONFIG P
...    WHERE P.PROCESS_CD = 'PIPELINE_DATA_EXTRACT'


# ─────────────────────────────────────────────────────────────
# Prerequisite Updates — Fix upstream job status (UPDATE)
# ─────────────────────────────────────────────────────────────

${SQL_UPDATE_LOAD_STATUS_CD}
...    UPDATE PROCESS_CONFIG
...    SET CONFIG_VALUE='C', LAST_UPD_TIMESTAMP=SYSDATE
...    WHERE CONFIG_CD='LOAD_STATUS_CD' AND PROCESS_CD='CUST_ODS_LOAD'

${SQL_UPDATE_START_DT_TODAY}
...    UPDATE PROCESS_CONFIG
...    SET CONFIG_VALUE=TO_CHAR(SYSDATE,'MM/DD/YYYY'), LAST_UPD_TIMESTAMP=SYSDATE
...    WHERE CONFIG_CD='START_DT' AND PROCESS_CD='CUST_ODS_LOAD'
