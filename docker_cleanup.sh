#!/bin/bash

# Docker Cleanup and Restart Script
# This ensures all containers are properly cleaned before starting

echo "🧹 Performing complete Docker cleanup..."

# List of container names from your docker-compose
CONTAINERS=(
    "sqlserver-db"
    "oracle-db"
    "postgres-db"
    "maildev-test"
    "mysql-db"
    "snaplogic-minio"
    "snaplogic-kafka-kraft"
    "snaplogic-test-example-tools-container"
    "oracle-schema-init"
    "mysql-schema-init"
    "sqlserver-schema-init"
    "snaplogic-minio-setup"
    "snaplogic-kafka-setup"
    "snaplogic-kafka-ui"
)

echo "📦 Stopping and removing specific containers..."
for container in "${CONTAINERS[@]}"; do
    if docker ps -a | grep -q "$container"; then
        echo "  - Removing $container"
        docker rm -f "$container" 2>/dev/null || true
    fi
done

echo "🔧 Running docker compose down with cleanup..."
docker compose down --volumes --remove-orphans 2>/dev/null || true

echo "🗑️ Pruning Docker system..."
docker system prune -f

echo "✅ Cleanup complete!"
echo ""
echo "🚀 Starting services with make clean-start..."
make clean-start
