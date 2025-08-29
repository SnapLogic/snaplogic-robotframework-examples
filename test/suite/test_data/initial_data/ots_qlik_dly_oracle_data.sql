-- Seed data for ACCOUNTS and STATUS_MAP (for join/lookup)
DELETE FROM STATUS_MAP;
DELETE FROM ACCOUNTS;
DELETE FROM OTS_DAILY;

INSERT INTO STATUS_MAP (CODE, STATUS) VALUES ('A', 'Active');
INSERT INTO STATUS_MAP (CODE, STATUS) VALUES ('I', 'Inactive');

INSERT INTO ACCOUNTS (ID, CODE) VALUES (1, 'A');
INSERT INTO ACCOUNTS (ID, CODE) VALUES (2, 'I');

-- Optionally, seed OTS_DAILY if you want existing data for the join
-- (Delete above ensures OTS_DAILY starts empty for true ETL tests.)

COMMIT;
