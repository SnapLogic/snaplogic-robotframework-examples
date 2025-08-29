-- Clear and seed new data in the PG source table
DELETE FROM qlik_ots_daily;

INSERT INTO qlik_ots_daily (id, name, m_curr_date, status) VALUES (1, 'FilterMe', '2025-07-23', 'Active');
INSERT INTO qlik_ots_daily (id, name, m_curr_date, status) VALUES (2, 'ValidRow', '2025-07-23', 'Active');
INSERT INTO qlik_ots_daily (id, name, m_curr_date, status) VALUES (3, 'IgnoreMe', '2025-07-23', 'Inactive');