#!/bin/bash

echo "=== Adding MySQL JDBC Driver to Snaplex ==="
echo

# Download MySQL Connector/J 8.0.33 (compatible with MySQL 8.0)
MYSQL_CONNECTOR_VERSION="8.0.33"
MYSQL_CONNECTOR_URL="https://repo1.maven.org/maven2/mysql/mysql-connector-java/${MYSQL_CONNECTOR_VERSION}/mysql-connector-java-${MYSQL_CONNECTOR_VERSION}.jar"

echo "Downloading MySQL Connector/J ${MYSQL_CONNECTOR_VERSION}..."
wget -q "${MYSQL_CONNECTOR_URL}" -O mysql-connector-java-${MYSQL_CONNECTOR_VERSION}.jar

if [ $? -eq 0 ]; then
    echo "Download successful!"
    
    # Copy to Snaplex container
    echo "Copying JDBC driver to Snaplex container..."
    docker cp mysql-connector-java-${MYSQL_CONNECTOR_VERSION}.jar snaplogic-groundplex:/opt/snaplogic/snap/jdbc/mysql-connector-java-${MYSQL_CONNECTOR_VERSION}.jar
    
    if [ $? -eq 0 ]; then
        echo "JDBC driver copied successfully!"
        echo
        echo "Restarting Snaplex to load the new driver..."
        docker restart snaplogic-groundplex
        echo "Snaplex restarted. Please wait a moment for it to fully start."
        
        # Clean up local file
        rm mysql-connector-java-${MYSQL_CONNECTOR_VERSION}.jar
    else
        echo "Failed to copy JDBC driver to container"
    fi
else
    echo "Failed to download MySQL Connector/J"
fi
