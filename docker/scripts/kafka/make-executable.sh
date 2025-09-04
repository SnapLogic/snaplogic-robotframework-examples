#!/bin/bash
# Script to make all Kafka scripts executable

echo "Setting executable permissions for Kafka scripts..."

chmod +x kafka-topics.sh
chmod +x kafka-setup.sh
chmod +x kafka-healthcheck.sh
chmod +x kafka-test-producer.sh
chmod +x kafka-cleanup.sh

echo "✅ All scripts are now executable"
ls -la
