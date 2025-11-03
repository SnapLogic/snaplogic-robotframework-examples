#!/bin/bash
# SQL Server entrypoint script to disable forced encryption for pymssql compatibility

# Start SQL Server in the background
/opt/mssql/bin/sqlservr &

# Wait for SQL Server to start
echo "Waiting for SQL Server to start..."
sleep 30

# Disable forced encryption using mssql-conf
echo "Disabling forced encryption for pymssql compatibility..."
/opt/mssql/bin/mssql-conf set network.forceencryption 0

# Restart SQL Server to apply changes
echo "Restarting SQL Server to apply encryption settings..."
pkill sqlservr
sleep 5

# Start SQL Server in foreground
exec /opt/mssql/bin/sqlservr
