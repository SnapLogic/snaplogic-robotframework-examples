#!/bin/bash
# SQL Server entrypoint script to disable forced encryption for pymssql compatibility

# Start SQL Server in the background
/opt/mssql/bin/sqlservr &

# Wait for SQL Server to be FULLY ready (not just a fixed sleep)
echo "Waiting for SQL Server to start..."
for i in {1..60}; do
    if /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "${MSSQL_SA_PASSWORD:-Snaplogic123!}" -Q "SELECT 1" -b -C > /dev/null 2>&1; then
        echo "SQL Server is ready!"
        break
    fi
    echo "Waiting... ($i/60)"
    sleep 2
done

# Disable forced encryption using mssql-conf
echo "Disabling forced encryption for pymssql compatibility..."
/opt/mssql/bin/mssql-conf set network.forceencryption 0

# Gracefully stop SQL Server (wait for it to finish)
echo "Restarting SQL Server to apply encryption settings..."
pkill -SIGTERM sqlservr
sleep 10

# Start SQL Server in foreground
exec /opt/mssql/bin/sqlservr
