# MFT (Managed File Transfer) Mock Services

This directory provides a complete MFT environment for testing SnapLogic integrations with enterprise-grade file transfer systems.

## 🎯 What is MFT?

Managed File Transfer (MFT) goes beyond simple FTP/SFTP by providing:
- **Security**: Encryption in transit and at rest
- **Automation**: Scheduled transfers and workflows
- **Monitoring**: Real-time transfer status and alerts
- **Audit Trail**: Complete logging of all activities
- **Integration**: REST APIs for programmatic control
- **Reliability**: Checksum verification, retry mechanisms

## 🚀 Quick Start

```bash
# Start MFT services
docker-compose -f ../docker-compose-file-transfer.yml up -d mft-server mft-api-mock mft-db mft-monitor

# Access MFT interfaces
- Web UI: https://localhost:8443 (admin/admin123)
- REST API: http://localhost:5000
- Monitor: http://localhost:3001 (admin/monitor123)
- SFTP: sftp -P 2223 mftuser@localhost
- FTPS: ftps://localhost:2021
```

## 📊 MFT Components

### 1. MFT Server (CrushFTP)
- **Purpose**: Core MFT functionality
- **Features**: 
  - Multiple protocol support (FTP, FTPS, SFTP, HTTPS)
  - User management and permissions
  - Folder monitoring
  - Event triggers
  - PGP encryption support

### 2. MFT REST API Mock
- **Purpose**: Simulate MFT API endpoints
- **Endpoints**:
  - `/api/v1/auth/login` - Authentication
  - `/api/v1/transfer/initiate` - Start transfer
  - `/api/v1/transfer/{id}/status` - Check status
  - `/api/v1/transfer/list` - List transfers
  - `/api/v1/schedule/create` - Create schedule
  - `/api/v1/audit/logs` - Audit trail

### 3. MFT Database
- **Purpose**: Store metadata and audit trails
- **Tables**:
  - `users` - User accounts
  - `transfer_logs` - Transfer history
  - `audit_logs` - All activities
  - `schedules` - Automated transfers
  - `partners` - Trading partners

### 4. MFT Monitor (Grafana)
- **Purpose**: Real-time monitoring dashboard
- **Metrics**:
  - Transfer success/failure rates
  - Data volume trends
  - Partner connectivity
  - System performance

## 🔧 SnapLogic Integration

### 1. File Transfer via SFTP
```json
{
  "protocol": "SFTP",
  "hostname": "localhost",
  "port": 2223,
  "username": "mftuser",
  "password": "mftpass",
  "directory": "/partners/snaplogic/inbound"
}
```

### 2. REST API Integration
```json
{
  "method": "POST",
  "url": "http://localhost:5000/api/v1/transfer/initiate",
  "headers": {
    "Authorization": "Bearer YOUR_TOKEN",
    "Content-Type": "application/json"
  },
  "body": {
    "source": "sftp://source/file.csv",
    "destination": "sftp://dest/processed/",
    "encryption": "PGP",
    "notify": ["admin@company.com"]
  }
}
```

### 3. Scheduled Transfers
```json
{
  "name": "Daily Order Export",
  "cron": "0 2 * * *",
  "source": "/orders/daily/*.csv",
  "destination": "sftp://partner/imports/",
  "postProcessing": "MOVE_TO_ARCHIVE"
}
```

## 📁 Directory Structure

```
mft-data/
├── users/           # User home directories
├── partners/        # Partner-specific folders
├── archive/         # Processed files
└── quarantine/      # Failed transfers

mft-api-mappings/    # WireMock API responses
mft-db-init/         # Database schema
mft-logs/            # Transfer and audit logs
```

## 🧪 Testing Scenarios

### 1. Basic File Transfer
```bash
# Upload file via SFTP
echo "test data" > test.txt
sftp -P 2223 mftuser@localhost
sftp> put test.txt /partners/acme/inbound/
sftp> quit

# Check transfer status via API
curl http://localhost:5000/api/v1/transfer/list
```

### 2. Automated Transfer with Monitoring
```bash
# Create schedule via API
curl -X POST http://localhost:5000/api/v1/schedule/create \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Hourly Sync",
    "cron": "0 * * * *",
    "source": "/data/export/*.xml",
    "destination": "sftp://partner/import/"
  }'

# Monitor in Grafana
open http://localhost:3001
```

### 3. Secure Transfer with Audit
```bash
# Transfer with encryption
curl -X POST http://localhost:5000/api/v1/transfer/initiate \
  -d '{
    "source": "/sensitive/data.csv",
    "destination": "sftp://secure-partner/",
    "encryption": "AES256",
    "requireChecksum": true
  }'

# Check audit trail
curl http://localhost:5000/api/v1/audit/logs?action=FILE_TRANSFERRED
```

## 🔒 Security Features

1. **Encryption**:
   - TLS for all connections
   - PGP/GPG file encryption
   - Encrypted file storage

2. **Authentication**:
   - Multi-factor authentication
   - SSH key authentication
   - API token management

3. **Authorization**:
   - Role-based access control
   - Partner-specific permissions
   - IP whitelisting

4. **Compliance**:
   - Full audit trail
   - Data retention policies
   - GDPR compliance features

## 📈 Advanced Features

### AS2 Protocol Support
```bash
# AS2 endpoint: http://localhost:5000/as2
# Configure in SnapLogic AS2 connector
```

### Event-Driven Processing
```json
{
  "event": "FILE_RECEIVED",
  "trigger": {
    "pattern": "*.order",
    "action": "EXECUTE_PIPELINE",
    "pipeline": "ProcessOrder"
  }
}
```

### High Availability
- Clustering support
- Load balancing
- Failover mechanisms

## 🔍 Troubleshooting

### Check Service Health
```bash
# MFT Server
docker logs mft-mock-server

# API Mock
curl http://localhost:5001/__admin/

# Database
docker exec mft-mock-db psql -U mft_user -d mft_db -c "SELECT COUNT(*) FROM transfer_logs;"
```

### Common Issues
1. **Connection refused**: Check firewall and port mappings
2. **Authentication failed**: Verify credentials in environment
3. **Transfer stuck**: Check disk space and permissions

## 🎓 MFT Best Practices

1. **Use separate folders** for each partner
2. **Implement retention policies** for processed files
3. **Monitor transfer patterns** for anomalies
4. **Test failover scenarios** regularly
5. **Encrypt sensitive data** in transit and at rest
6. **Maintain audit logs** for compliance

This MFT mock environment provides a realistic testing platform for enterprise file transfer scenarios in SnapLogic!
