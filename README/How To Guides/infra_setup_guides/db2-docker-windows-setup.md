# DB2 Docker Setup on Windows

This guide provides instructions for setting up IBM DB2 in Docker on Windows and configuring Windows Defender Firewall to allow external connections.

## Prerequisites

- Docker Desktop for Windows installed and running
- Windows 10/11 with administrative privileges
- At least 4GB of available RAM for DB2 container

## Starting DB2 Docker Container

1. Navigate to the docker directory:
   ```powershell
   cd path\to\snaplogic-robotframework-examples\docker
   ```

2. Start the DB2 container:
   ```powershell
   docker-compose -f docker-compose.db2.yml up -d
   ```

3. Verify the container is running:
   ```powershell
   docker ps
   ```
   You should see the `db2-db` container running on port 50000.

## Windows Defender Firewall Configuration

By default, Windows Defender Firewall blocks incoming connections to Docker containers. Follow these steps to allow connections to DB2 on port 50000.

### ✅ Steps to Open Windows Defender Firewall (Advanced Settings)

#### 🪟 Option 1: Using Start Menu (Easiest)

1. Click **Start** (Windows key)
2. Type: `Windows Defender Firewall with Advanced Security`
3. Click to open it

#### 🪟 Option 2: Using Control Panel

1. Open **Control Panel**
2. Go to **System and Security**
3. Click **Windows Defender Firewall**
4. In the left pane, click **Advanced Settings**

### 🔐 Add an Inbound Rule for Port 50000

1. In the **left panel**, click **Inbound Rules**
2. In the **right panel**, click **New Rule…**
3. In the wizard:
   - **Rule Type**: Select `Port`, click **Next**
   - **Protocol**: Select `TCP`
   - **Specific local ports**: Enter `50000`, click **Next**
   - **Action**: Choose `Allow the connection`, click **Next**
   - **Profile**: Select as needed (Private is usually fine), click **Next**
   - **Name**: Enter something like `Allow DB2 Docker`
4. Click **Finish**

✅ Now port 50000 is open for incoming connections — SnapLogic should be able to reach your local DB2 Docker container.

## Connection Details

Once the firewall is configured, you can connect to DB2 using these details:

- **Host**: `localhost` or your machine's IP address
- **Port**: `50000`
- **Database**: `TESTDB`
- **Schema**: `SNAPTEST`
- **Username**: `db2inst1`
- **Password**: `snaplogic`
- **JDBC URL**: `jdbc:db2://localhost:50000/TESTDB`

## Testing the Connection

### From Windows Command Prompt
```powershell
# Get your machine's IP address
ipconfig

# Test if port is accessible
telnet localhost 50000
```

### From Another Machine on the Network
Replace `YOUR_WINDOWS_IP` with your actual IP address:
```bash
telnet YOUR_WINDOWS_IP 50000
```

## Extracting DB2 JDBC Driver

If you need the DB2 JDBC driver (db2jcc4.jar) from the container:

```powershell
# Copy the jar file from container to local directory
docker cp db2-db:/opt/ibm/db2/V11.5/java/db2jcc4.jar ./db2jcc4.jar

# Verify the file
dir db2jcc4.jar
```

## Troubleshooting

### Container Won't Start
- Ensure Docker Desktop is running
- Check Docker has enough resources allocated (Settings > Resources)
- Review container logs: `docker logs db2-db`

### Cannot Connect from External Machine
1. Verify the firewall rule is enabled:
   - Go back to Windows Defender Firewall with Advanced Security
   - Check Inbound Rules for "Allow DB2 Docker"
   - Ensure it's enabled (green checkmark)

2. Check Docker port mapping:
   ```powershell
   docker port db2-db
   ```
   Should show: `50000/tcp -> 0.0.0.0:50000`

3. Ensure Docker Desktop is configured to expose ports:
   - Docker Desktop > Settings > General
   - Ensure "Expose daemon on tcp://localhost:2375 without TLS" is appropriate for your security needs

### Performance Issues
- DB2 requires significant resources. Ensure Docker Desktop has at least:
  - 4GB RAM allocated
  - 2 CPU cores
  - Sufficient disk space (10GB+ recommended)

## Security Considerations

⚠️ **Important**: Opening firewall ports can expose your system to security risks. Consider:

- Only enable the firewall rule when needed for testing
- Restrict the rule to specific IP addresses if possible
- Use Private network profile instead of Public
- Disable the rule when not in use
- Consider using VPN for remote connections

## Additional Notes

- The DB2 container may take several minutes to fully initialize on first run
- Data is persisted in the `db2_database_v2` Docker volume
- To completely reset DB2, remove the volume: `docker volume rm db2_database_v2`
- For production use, consider IBM DB2 on Cloud or a dedicated DB2 server

## Platform Compatibility

- ✅ Windows (x86_64): Works seamlessly with native performance
- ✅ Linux (x86_64): Works seamlessly with native performance  
- ✅ macOS Intel (x86_64): Works seamlessly with native performance
- ❌ macOS Apple Silicon (M1/M2/M3): Does NOT work due to architecture incompatibility

For Apple Silicon users, see the docker-compose.db2.yml file for alternative solutions.
