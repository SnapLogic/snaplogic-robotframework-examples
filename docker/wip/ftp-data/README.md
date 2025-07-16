# FTP/SFTP Testing with SnapLogic

This directory provides mock FTP and SFTP servers for testing SnapLogic file transfer pipelines.

## 🚀 Quick Start

```bash
# Start FTP and SFTP servers
docker-compose -f ../docker-compose-api-mocks.yml up -d ftp-mock sftp-mock

# Check if services are running
docker-compose -f ../docker-compose-api-mocks.yml ps ftp-mock sftp-mock
```

## 📋 Server Details

### FTP Server
- **Host**: localhost
- **Port**: 2121
- **Username**: testuser
- **Password**: testpass
- **Root Directory**: /home/vsftpd

### SFTP Server
- **Host**: localhost
- **Port**: 2222
- **Username**: testuser
- **Password**: testpass
- **Root Directory**: /home/testuser

## 📁 Directory Structure

```
ftp-data/
├── upload/      # Place files here from SnapLogic
└── download/    # Pre-loaded with sample files
    ├── sample-data.txt
    ├── orders.json
    └── orders.csv

sftp-data/
├── upload/      # Place files here from SnapLogic
└── download/    # Pre-loaded with sample files
    └── sample-data.txt
```

## 🔧 SnapLogic Configuration

### File Reader Snap (FTP)
```
Settings:
- Protocol: FTP
- Server: localhost
- Port: 2121
- Username: testuser
- Password: testpass
- Directory: /download
- File: orders.csv
```

### File Writer Snap (FTP)
```
Settings:
- Protocol: FTP
- Server: localhost
- Port: 2121
- Username: testuser
- Password: testpass
- Directory: /upload
- File: output_${Date.now()}.csv
```

### File Reader Snap (SFTP)
```
Settings:
- Protocol: SFTP
- Server: localhost
- Port: 2222
- Username: testuser
- Password: testpass
- Directory: /download
- File: sample-data.txt
```

## 🧪 Testing Commands

### Test FTP Connection
```bash
# List files
curl -u testuser:testpass ftp://localhost:2121/download/

# Download file
curl -u testuser:testpass ftp://localhost:2121/download/orders.csv -o orders.csv

# Upload file
echo "test data" > test.txt
curl -T test.txt -u testuser:testpass ftp://localhost:2121/upload/
```

### Test SFTP Connection
```bash
# Interactive SFTP
sftp -P 2222 testuser@localhost

# Non-interactive download
scp -P 2222 testuser@localhost:/download/sample-data.txt ./

# Non-interactive upload
scp -P 2222 ./myfile.txt testuser@localhost:/upload/
```

## 📝 Sample Use Cases

1. **Batch File Processing**
   - Read CSV files from FTP
   - Transform data
   - Write results back to FTP

2. **Secure File Transfer**
   - Read sensitive data via SFTP
   - Process in SnapLogic
   - Store results securely

3. **File Polling**
   - Monitor FTP directory for new files
   - Process files as they arrive
   - Move processed files to archive

## 🔍 Troubleshooting

### FTP Connection Issues
```bash
# Check FTP server logs
docker logs ftp-mock-server

# Test basic connectivity
telnet localhost 2121
```

### SFTP Connection Issues
```bash
# Check SFTP server logs
docker logs sftp-mock-server

# Test with verbose mode
sftp -vvv -P 2222 testuser@localhost
```

### Permission Issues
- Ensure upload directories have write permissions
- Check file ownership inside containers

## 🛠️ Advanced Configuration

### Custom Users
```bash
# FTP: Set environment variables
FTP_USER=myuser FTP_PASS=mypass docker-compose up -d ftp-mock

# SFTP: Multiple users
SFTP_USERS="user1:pass1:1001:100:upload,download;user2:pass2:1002:100:download" docker-compose up -d sftp-mock
```

### Passive Mode (FTP)
Already configured with ports 21000-21010 for passive transfers.

### SSH Keys (SFTP)
Place public keys in `sftp-keys/` directory for key-based authentication.
