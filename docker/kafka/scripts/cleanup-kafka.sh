#!/bin/bash
# Cleanup script for Kafka containers and volumes

echo "🧹 Cleaning up Kafka containers and volumes..."

# Stop and remove containers
echo "Stopping Kafka containers..."
docker stop snaplogic-kafka-kraft snaplogic-kafka-ui snaplogic-kafka-setup 2>/dev/null || true

echo "Removing Kafka containers..."
docker rm -f snaplogic-kafka-kraft snaplogic-kafka-ui snaplogic-kafka-setup 2>/dev/null || true

# Remove volumes
echo "Removing Kafka volumes..."
docker volume rm docker_kafka-kraft-data docker_kafka-kraft-logs 2>/dev/null || true
docker volume rm snaplogic-robotframework-examples_kafka-kraft-data snaplogic-robotframework-examples_kafka-kraft-logs 2>/dev/null || true

# List remaining containers and volumes for verification
echo ""
echo "Remaining containers with 'kafka' in name:"
docker ps -a | grep kafka || echo "None found"

echo ""
echo "Remaining volumes with 'kafka' in name:"
docker volume ls | grep kafka || echo "None found"

echo ""
echo "✅ Cleanup complete!"
