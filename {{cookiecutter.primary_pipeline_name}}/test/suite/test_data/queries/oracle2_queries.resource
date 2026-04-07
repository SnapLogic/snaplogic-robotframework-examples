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
