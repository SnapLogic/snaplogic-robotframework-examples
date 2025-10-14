-- Create the source/postgres table for pipeline extraction
CREATE TABLE IF NOT EXISTS qlik_ots_daily (
    id           INTEGER,
    name         VARCHAR(100),
    m_curr_date  DATE,
    status       VARCHAR(20)
);
