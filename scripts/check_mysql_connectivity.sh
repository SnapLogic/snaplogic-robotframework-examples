#!/bin/bash

echo "=== Checking MySQL Connectivity from Snaplex ==="
echo

# Check if containers are running
echo "1. Checking if containers are running:"
docker ps | grep -E "snaplogic-groundplex|mysql-db" | awk '{print $NF}'
echo

# Check network configuration
echo "2. Checking if both containers are on the same network:"
echo "MySQL networks:"
docker inspect mysql-db --format='{{range .NetworkSettings.Networks}}{{.NetworkID}} {{end}}' 2>/dev/null || echo "MySQL container not found"
echo "Snaplex networks:"
docker inspect snaplogic-groundplex --format='{{range .NetworkSettings.Networks}}{{.NetworkID}} {{end}}' 2>/dev/null || echo "Snaplex container not found"
echo

# Test connectivity from Snaplex to MySQL
echo "3. Testing connectivity from Snaplex to MySQL:"
docker exec snaplogic-groundplex ping -c 3 mysql-db 2>&1 || echo "Ping failed or not available"
echo

# Check if MySQL port is accessible from Snaplex
echo "4. Testing MySQL port accessibility from Snaplex:"
docker exec snaplogic-groundplex bash -c "timeout 2 bash -c '</dev/tcp/mysql-db/3306' && echo 'Port 3306 is accessible' || echo 'Port 3306 is not accessible'" 2>&1
echo

# Check JDBC drivers in Snaplex
echo "5. Checking for MySQL JDBC drivers in Snaplex:"
docker exec snaplogic-groundplex find /opt/snaplogic -name "*mysql*.jar" 2>/dev/null | head -10 || echo "No MySQL JDBC drivers found"
echo

# Check Snaplex Java classpath
echo "6. Checking if MySQL driver is in classpath:"
docker exec snaplogic-groundplex bash -c 'echo $CLASSPATH | grep -o mysql || echo "MySQL not found in CLASSPATH"' 2>&1
echo

# Test MySQL connection using installed tools (if available)
echo "7. Testing direct MySQL connection (if mysql client is available):"
docker exec snaplogic-groundplex bash -c "which mysql && mysql -h mysql-db -P 3306 -u testuser -psnaplogic -e 'SELECT 1' TEST 2>&1 || echo 'MySQL client not available in Snaplex'" 2>&1
