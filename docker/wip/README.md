# SnapLogic Testing Services

This directory contains Docker Compose configurations for mocking various external services used in SnapLogic integrations.

## 📁 Service Categories

### 1. API Services (`docker-compose-api-mocks.yml`)
Mock services for API-based integrations:
- **REST APIs**: Prism, WireMock, JSON Server, Mockoon
- **GraphQL**: GraphQL Faker
- **SOAP**: CastleMock
- **OAuth2/OIDC**: Mock OIDC Server
- **Email (SMTP)**: MailHog

### 2. File Transfer Services (`docker-compose-file-transfer.yml`)
Mock services for file-based integrations:
- **FTP Server**: Traditional file transfer (port 2121)
- **SFTP Server**: Secure file transfer (port 2222)
- **MFT Platform**: Enterprise managed file transfer with:
  - Web UI (port 8443)
  - REST API (port 5000)
  - SFTP/FTPS endpoints (ports 2223/2021)
  - Monitoring dashboard (port 3001)
  - Audit database

### 3. Database Services
Use the existing PostgreSQL setup:
- Located at: `../docker-compose.postgres.yml`
- For database connections and SQL operations

## 🚀 Quick Start

```bash
# Start API mocks only
docker-compose -f docker-compose-api-mocks.yml up -d

# Start file transfer services only
docker-compose -f docker-compose-file-transfer.yml up -d

# Start specific services (e.g., just FTP and SFTP)
docker-compose -f docker-compose-file-transfer.yml up -d ftp-server sftp-server

# Start MFT platform
docker-compose -f docker-compose-file-transfer.yml up -d mft-server mft-api-mock mft-db mft-monitor

# Start everything
docker-compose -f docker-compose-api-mocks.yml -f docker-compose-file-transfer.yml up -d
```

## 🎯 Why Separate Files?

1. **Logical Separation**:
   - **APIs**: HTTP/HTTPS protocols, request-response pattern
   - **File Transfer**: FTP/SFTP/MFT protocols, connection-based
   - **Different authentication methods and use cases**

2. **Resource Management**:
   - Start only what you need
   - MFT includes multiple services (server, API, DB, monitoring)
   - Easier to manage and troubleshoot

3. **SnapLogic Snap Categories**:
   - **API Services**: REST Snap, SOAP Snap, Email Sender
   - **File Services**: File Reader/Writer, Directory Browser
   - **MFT**: Enterprise file transfer with advanced features

## 📊 Service Overview

### API Services (Ports 8080-8087, 1025, 8025)
```
REST/SOAP/GraphQL → HTTP-based → API Snaps
Email → SMTP → Email Snaps
OAuth → HTTP → Account management
```

### File Transfer Services
```
Basic File Transfer (Ports 2121, 2222):
  FTP/SFTP → File protocols → File Snaps

MFT Platform (Ports 8443, 5000, 2223, 2021, 3001):
  Web UI → Management interface
  REST API → Automation and integration
  SFTP/FTPS → Secure file transfer
  Monitoring → Real-time dashboards
  Database → Audit trails and metadata
```

### Database Services (Port 5435)
```
PostgreSQL → SQL protocol → Database Snaps
```

## 🔧 Common Workflows

### 1. REST API to Database
```bash
docker-compose -f docker-compose-api-mocks.yml up -d
# PostgreSQL is already at localhost:5435
```

### 2. FTP to REST API
```bash
docker-compose -f docker-compose-file-transfer.yml up -d ftp-server
docker-compose -f docker-compose-api-mocks.yml up -d wiremock
```

### 3. MFT Integration Testing
```bash
# Full MFT platform with monitoring
docker-compose -f docker-compose-file-transfer.yml up -d mft-server mft-api-mock mft-db mft-monitor

# Access MFT Web UI
open https://localhost:8443

# Access monitoring dashboard
open http://localhost:3001
```

### 4. Complete Integration Testing
```bash
# All services
docker-compose -f docker-compose-api-mocks.yml -f docker-compose-file-transfer.yml up -d
```

## 📝 MFT vs Traditional File Transfer

### Traditional FTP/SFTP
- Simple file upload/download
- Basic authentication
- No built-in monitoring
- Manual processes

### MFT (Managed File Transfer)
- **Automation**: Scheduled transfers, event triggers
- **Security**: Encryption, compliance, audit trails
- **Monitoring**: Real-time status, alerts, dashboards
- **Integration**: REST APIs, webhooks
- **Reliability**: Retry logic, checksum verification
- **Management**: Web UI, partner management, workflows

## 🛠️ Directory Structure

```
wip/
├── docker-compose-api-mocks.yml      # API services
├── docker-compose-file-transfer.yml  # File transfer + MFT
├── api-specs/                        # OpenAPI specifications
├── wiremock-mappings/                # WireMock configs
├── json-dbs/                         # JSON Server data
├── ftp-data/                         # FTP server files
├── sftp-data/                        # SFTP server files
├── mft-data/                         # MFT platform data
├── mft-api-mappings/                 # MFT API mocks
├── mft-db-init/                      # MFT database schema
└── [other service-specific dirs]
```

## 🔍 Service Health Checks

```bash
# Check all running services
docker-compose -f docker-compose-file-transfer.yml ps

# MFT specific health checks
curl -k https://localhost:8443                    # MFT Web UI
curl http://localhost:5000/api/v1/transfer/list   # MFT API
curl http://localhost:5001/__admin/               # API Mock Admin
```

This modular approach gives you flexibility to test different integration patterns while keeping services logically organized!
