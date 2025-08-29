-- Create the OTS_DAILY target table if it doesn't exist
BEGIN
    EXECUTE IMMEDIATE 'CREATE TABLE OTS_DAILY (
        ID          NUMBER,
        NAME        VARCHAR2(100),
        M_CURR_DATE DATE,
        STATUS      VARCHAR2(20)
    )';
EXCEPTION
    WHEN OTHERS THEN
        IF SQLCODE != -955 THEN -- -955 = ORA-00955: name is already used by an existing object
            RAISE;
        END IF;
END;
/

-- Optionally create lookup or join tables, if used in your business logic
BEGIN
    EXECUTE IMMEDIATE 'CREATE TABLE STATUS_MAP (
        CODE    VARCHAR2(10),
        STATUS  VARCHAR2(20)
    )';
EXCEPTION
    WHEN OTHERS THEN
        IF SQLCODE != -955 THEN
            RAISE;
        END IF;
END;
/

BEGIN
    EXECUTE IMMEDIATE 'CREATE TABLE ACCOUNTS (
        ID   NUMBER,
        CODE VARCHAR2(10)
    )';
EXCEPTION
    WHEN OTHERS THEN
        IF SQLCODE != -955 THEN
            RAISE;
        END IF;
END;
/

COMMIT;
