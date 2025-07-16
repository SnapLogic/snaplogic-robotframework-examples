-- MFT Database Schema for audit trails and transfer metadata

CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(100) UNIQUE NOT NULL,
    email VARCHAR(255),
    role VARCHAR(50) DEFAULT 'user',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_login TIMESTAMP
);

CREATE TABLE IF NOT EXISTS transfer_logs (
    id SERIAL PRIMARY KEY,
    transfer_id VARCHAR(50) UNIQUE NOT NULL,
    user_id INTEGER REFERENCES users(id),
    source_path TEXT NOT NULL,
    destination_path TEXT NOT NULL,
    file_name VARCHAR(255) NOT NULL,
    file_size BIGINT,
    status VARCHAR(50) NOT NULL,
    started_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    completed_at TIMESTAMP,
    error_message TEXT,
    checksum VARCHAR(128),
    transfer_type VARCHAR(20) -- FTP, SFTP, FTPS, AS2, etc.
);

CREATE TABLE IF NOT EXISTS audit_logs (
    id SERIAL PRIMARY KEY,
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    user_id INTEGER REFERENCES users(id),
    action VARCHAR(100) NOT NULL,
    resource_type VARCHAR(50),
    resource_id VARCHAR(100),
    ip_address INET,
    user_agent TEXT,
    result VARCHAR(20),
    details JSONB
);

CREATE TABLE IF NOT EXISTS schedules (
    id SERIAL PRIMARY KEY,
    schedule_id VARCHAR(50) UNIQUE NOT NULL,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    cron_expression VARCHAR(100) NOT NULL,
    source_path TEXT NOT NULL,
    destination_path TEXT NOT NULL,
    enabled BOOLEAN DEFAULT true,
    created_by INTEGER REFERENCES users(id),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_run TIMESTAMP,
    next_run TIMESTAMP
);

CREATE TABLE IF NOT EXISTS partners (
    id SERIAL PRIMARY KEY,
    partner_id VARCHAR(50) UNIQUE NOT NULL,
    name VARCHAR(255) NOT NULL,
    type VARCHAR(50), -- CUSTOMER, SUPPLIER, INTERNAL
    connection_type VARCHAR(20), -- FTP, SFTP, AS2, API
    host VARCHAR(255),
    port INTEGER,
    username VARCHAR(100),
    public_key TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Indexes for performance
CREATE INDEX idx_transfer_logs_status ON transfer_logs(status);
CREATE INDEX idx_transfer_logs_user ON transfer_logs(user_id);
CREATE INDEX idx_audit_logs_timestamp ON audit_logs(timestamp);
CREATE INDEX idx_audit_logs_user ON audit_logs(user_id);

-- Insert sample data
INSERT INTO users (username, email, role) VALUES
    ('admin', 'admin@mft.local', 'admin'),
    ('mftuser', 'user@mft.local', 'user'),
    ('apiuser', 'api@mft.local', 'api');

INSERT INTO partners (partner_id, name, type, connection_type, host, port, username) VALUES
    ('PART-001', 'Acme Corporation', 'CUSTOMER', 'SFTP', 'sftp.acme.com', 22, 'acme_user'),
    ('PART-002', 'Global Suppliers Inc', 'SUPPLIER', 'FTPS', 'ftp.globalsuppliers.com', 21, 'gs_transfer'),
    ('PART-003', 'Internal Warehouse', 'INTERNAL', 'API', 'api.warehouse.local', 443, 'warehouse_api');

-- Grant permissions
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO mft_user;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO mft_user;
