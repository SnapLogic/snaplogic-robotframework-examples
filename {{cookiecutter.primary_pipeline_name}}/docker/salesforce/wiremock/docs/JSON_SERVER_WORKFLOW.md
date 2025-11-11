# JSON Server and json-db Complete Workflow Documentation

## Table of Contents
1. [Overview](#overview)
2. [Architecture](#architecture)
3. [Key Components](#key-components)
4. [Complete Workflow](#complete-workflow)
5. [Data Loading Process](#data-loading-process)
6. [CRUD Operations Flow](#crud-operations-flow)
7. [HTML Dashboard Connection](#html-dashboard-connection)
8. [File Relationships](#file-relationships)
9. [Testing and Verification](#testing-and-verification)
10. [Troubleshooting](#troubleshooting)

## Overview

The Salesforce mock environment uses JSON Server to provide stateful CRUD operations with data persistence. This document explains how all components work together.

### Quick Summary
- **json-db folder**: Contains the data file (`salesforce-db.json`)
- **JSON Server**: Node.js application that creates REST APIs from JSON files
- **WireMock**: Translates Salesforce API format to JSON Server format
- **HTML Dashboard**: Web UI to view and manage data

## Architecture

```
┌─────────────────────────────────────────────────────┐
│                SnapLogic/Your Test Code              │
└─────────────────────┬───────────────────────────────┘
                      │ Salesforce API Format
                      │ POST /services/data/v59.0/sobjects/Account
                      ▼
┌─────────────────────────────────────────────────────┐
│               WireMock (Port 8089)                   │
│         Proxy Mappings (Translation Layer)           │
└─────────────────────┬───────────────────────────────┘
                      │ JSON Server Format
                      │ POST /accounts
                      ▼
┌─────────────────────────────────────────────────────┐
│            JSON Server (Port 8082)                   │
│         Container: salesforce-json-mock              │
└─────────────────────┬───────────────────────────────┘
                      │ Read/Write Operations
                      ▼
┌─────────────────────────────────────────────────────┐
│          /data/salesforce-db.json                    │
│            (Inside Container)                        │
└─────────────────────┬───────────────────────────────┘
                      │ Volume Mount
                      ▼
┌─────────────────────────────────────────────────────┐
│      docker/salesforce/json-db/                      │
│          salesforce-db.json                          │
│       (On Your Host File System)                     │
└─────────────────────────────────────────────────────┘
```

## Key Components

### 1. json-db Folder
- **Location**: `/docker/salesforce/json-db/`
- **Purpose**: Storage directory for database files
- **Contents**:
  - `salesforce-db.json` - The actual data file
  - `jsonserver_data.html` - Web dashboard for viewing data

### 2. JSON Server
- **What**: Node.js application (npm package)
- **Running as**: Docker container `salesforce-json-mock`
- **Image**: `clue/json-server`
- **Port**: 8082 (host) → 80 (container)
- **Purpose**: Creates REST API endpoints from JSON file

### 3. Proxy Mappings
- **Location**: `/docker/salesforce/wiremock/proxy_mappings/`
- **Purpose**: Translate between Salesforce API and JSON Server formats
- **Examples**:
  - `02-proxy-create-account.json` - Maps Salesforce create to JSON Server POST
  - `03-proxy-get-account.json` - Maps Salesforce get to JSON Server GET

### 4. HTML Dashboard
- **File**: `jsonserver_data.html`
- **Connection**: Line 380: `const API_BASE = 'http://localhost:8082';`
- **Auto-refresh**: Every 1 second (line 541: `setInterval(fetchData, 1000);`)

## Complete Workflow

### Step 1: Docker Compose Configuration

```yaml
# docker-compose.salesforce-mock.yml
salesforce-json-server:
  image: clue/json-server
  container_name: salesforce-json-mock
  ports:
    - "8082:80"
  volumes:
    - ./json-db:/data  # Maps local folder to container
  command: --watch /data/salesforce-db.json --host 0.0.0.0
```

### Step 2: Volume Mount Process

```
Local Directory Structure:
docker/salesforce/json-db/
├── salesforce-db.json      # Pre-loaded data file
└── jsonserver_data.html    # Dashboard

Container sees:
/data/
└── salesforce-db.json      # Same file, different path
```

### Step 3: JSON Server Startup

When container starts:
1. Docker mounts `./json-db` → `/data`
2. JSON Server executes: `--watch /data/salesforce-db.json`
3. Reads and parses the JSON file
4. Creates REST endpoints based on top-level keys:
   - `accounts` → `/accounts`
   - `contacts` → `/contacts`
   - `opportunities` → `/opportunities`

## Data Loading Process

### Initial Load (Container Startup)

```javascript
// What JSON Server does internally (simplified):
const fs = require('fs');
const jsonServer = require('json-server');

// 1. Read the file specified in command
const data = JSON.parse(fs.readFileSync('/data/salesforce-db.json', 'utf-8'));

// 2. Create routes from top-level keys
// data = { "accounts": [...], "contacts": [...], "opportunities": [...] }
// Creates:
//   GET    /accounts
//   GET    /accounts/:id
//   POST   /accounts
//   PUT    /accounts/:id
//   DELETE /accounts/:id
//   ... same for contacts and opportunities

// 3. Start server on port 80
server.listen(80);
```

### The --watch Flag

```javascript
// The --watch flag enables file monitoring
fs.watchFile('/data/salesforce-db.json', (curr, prev) => {
  if (curr.mtime !== prev.mtime) {
    // File changed externally
    console.log('Reloading /data/salesforce-db.json');
    const newData = JSON.parse(fs.readFileSync('/data/salesforce-db.json'));
    updateRoutes(newData);
  }
});
```

## CRUD Operations Flow

### CREATE - Add New Account

```bash
# 1. Request through WireMock
curl -X POST http://localhost:8089/services/data/v59.0/sobjects/Account \
  -H "Content-Type: application/json" \
  -d '{"Name": "New Company"}'
```

**Flow:**
1. WireMock receives Salesforce-format request
2. Proxy mapping (`02-proxy-create-account.json`) forwards to JSON Server
3. JSON Server:
   - Generates new ID
   - Adds to in-memory data
   - **Writes to `/data/salesforce-db.json`**
   - Returns response
4. File on host is updated (through volume mount)

### READ - Get Account

```bash
curl http://localhost:8089/services/data/v59.0/sobjects/Account/001
```

**Flow:**
1. WireMock → Proxy mapping → JSON Server
2. JSON Server reads from memory (originally loaded from file)
3. Returns account data

### UPDATE - Modify Account

```bash
curl -X PATCH http://localhost:8089/services/data/v59.0/sobjects/Account/001 \
  -d '{"Type": "Partner"}'
```

**Flow:**
1. WireMock → Proxy mapping → JSON Server
2. JSON Server:
   - Updates in memory
   - **Writes entire updated file to `/data/salesforce-db.json`**
3. Host file is updated

### DELETE - Remove Account

```bash
curl -X DELETE http://localhost:8089/services/data/v59.0/sobjects/Account/001
```

**Flow:**
1. WireMock → Proxy mapping → JSON Server
2. JSON Server:
   - Removes from memory
   - **Writes updated file without deleted record**
3. Host file is updated

## HTML Dashboard Connection

### Connection Configuration

```javascript
// Line 380: Base URL definition
const API_BASE = 'http://localhost:8082';

// Line 384-391: Fetch all data
async function fetchData() {
    const response = await fetch(`${API_BASE}/db`);  // GET http://localhost:8082/db
    dbData = await response.json();
    updateUI();
}

// Line 488-499: Delete record
async function deleteRecord(type, id) {
    const response = await fetch(`${API_BASE}/${type}/${id}`, {
        method: 'DELETE'
    });
}

// Line 527-538: Create account
const response = await fetch(`${API_BASE}/accounts`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(account)
});

// Line 541: Auto-refresh every second
setInterval(fetchData, 1000);
```

### Dashboard Endpoints Used

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/db` | GET | Fetch entire database |
| `/accounts` | GET | List all accounts |
| `/accounts` | POST | Create new account |
| `/accounts/{id}` | DELETE | Delete specific account |
| `/contacts` | GET | List all contacts |
| `/opportunities` | GET | List all opportunities |

## File Relationships

### Pre-loaded Data Structure

```json
{
  "accounts": [
    {
      "id": "001000000000001",
      "Name": "Acme Corporation",
      "Type": "Customer",
      "Industry": "Technology",
      "AnnualRevenue": 50000000
    },
    {
      "id": "001000000000002",
      "Name": "Global Innovations Inc",
      "Type": "Partner",
      "Industry": "Manufacturing",
      "AnnualRevenue": 75000000
    },
    {
      "id": "001000000000003",
      "Name": "TechStart Solutions",
      "Type": "Prospect",
      "Industry": "Software",
      "AnnualRevenue": 10000000
    }
  ],
  "contacts": [
    {
      "id": "003000000000001",
      "FirstName": "John",
      "LastName": "Doe",
      "AccountId": "001000000000001"
    }
  ],
  "opportunities": [
    {
      "id": "006000000000001",
      "Name": "Acme - Enterprise Deal",
      "AccountId": "001000000000001",
      "Amount": 500000
    }
  ]
}
```

### Data Persistence

- **Location**: `docker/salesforce/json-db/salesforce-db.json`
- **Updates**: Real-time with every CRUD operation
- **Persistence**: Survives container restarts
- **Reset**: `git checkout docker/salesforce/json-db/salesforce-db.json`

## Testing and Verification

### 1. Verify JSON Server is Running

```bash
# Check container status
docker ps | grep salesforce-json-mock

# Test API endpoint
curl http://localhost:8082/accounts

# Check logs
docker logs salesforce-json-mock
```

### 2. Test CRUD Operations

```bash
# CREATE - Add account
curl -X POST http://localhost:8082/accounts \
  -H "Content-Type: application/json" \
  -d '{"Name": "Test Company"}'

# READ - Get all accounts
curl http://localhost:8082/accounts

# UPDATE - Modify account (need ID from create)
curl -X PUT http://localhost:8082/accounts/xyz123 \
  -H "Content-Type: application/json" \
  -d '{"Name": "Updated Company"}'

# DELETE - Remove account
curl -X DELETE http://localhost:8082/accounts/xyz123
```

### 3. Monitor File Changes

```bash
# Watch file size change
while true; do
  clear
  echo "File size: $(wc -c < docker/salesforce/json-db/salesforce-db.json) bytes"
  echo "Accounts: $(cat docker/salesforce/json-db/salesforce-db.json | jq '.accounts | length')"
  sleep 1
done
```

### 4. Use HTML Dashboard

```bash
# Open dashboard
open docker/salesforce/json-db/jsonserver_data.html

# Dashboard auto-refreshes every 1 second
# Shows accounts, contacts, opportunities
# Allows create/delete operations
```

## Troubleshooting

### Common Issues and Solutions

#### 1. JSON Server Won't Start

**Problem**: Container fails to start
```bash
docker logs salesforce-json-mock
# Error: Cannot find module '/data/salesforce-db.json'
```

**Solution**: Ensure json-db folder exists with salesforce-db.json
```bash
ls -la docker/salesforce/json-db/salesforce-db.json
```

#### 2. Dashboard Can't Connect

**Problem**: HTML shows "Error fetching data"

**Solutions**:
- Check JSON Server is running: `docker ps | grep json-mock`
- Verify port mapping: Should be `8082:80`
- Check browser console for CORS errors
- Ensure API_BASE is correct: `http://localhost:8082`

#### 3. Data Not Persisting

**Problem**: Changes lost after restart

**Check**:
- Volume mount is correct: `./json-db:/data`
- File permissions: `ls -la docker/salesforce/json-db/`
- Container has write access

#### 4. Proxy Mappings Not Working

**Problem**: Salesforce API format not translating

**Check**:
- WireMock using correct mappings folder
- Should be: `./wiremock/proxy_mappings:/home/wiremock/mappings:ro`
- JSON Server is accessible from WireMock container

### Reset to Original State

```bash
# Stop containers
docker stop salesforce-json-mock salesforce-api-mock

# Reset data file
git checkout docker/salesforce/json-db/salesforce-db.json

# Restart
docker compose --profile salesforce-dev up -d
```

## Summary

The complete workflow involves:

1. **json-db folder** provides initial data file
2. **Docker volume** mounts folder into container
3. **JSON Server** reads file and creates REST APIs
4. **WireMock proxy mappings** translate Salesforce API to JSON Server
5. **CRUD operations** update both memory and file
6. **HTML dashboard** provides UI by connecting to JSON Server API
7. **Data persists** in salesforce-db.json through volume mount

This creates a fully functional, stateful mock of Salesforce with real data persistence!
