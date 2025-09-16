#!/bin/bash
# Setup script for headless ultra demo (Bitnami version)

echo "🚀 Setting up Headless Ultra Demo (Bitnami)..."

# Wait for Kafka to be ready
echo "⏳ Waiting for Kafka to be ready..."
until kafka-topics.sh --bootstrap-server kafka:29092 --list &>/dev/null; do
    echo "Waiting for Kafka..."
    sleep 5
done

echo "✅ Kafka is ready! Creating topics..."

# Create the main ultra-events topic with 4 partitions
# This matches the 4 consumer instances (2 per node)
kafka-topics.sh --bootstrap-server kafka:29092 \
    --create --if-not-exists \
    --topic ultra-events \
    --partitions 4 \
    --replication-factor 1 \
    --config retention.ms=3600000 \
    --config segment.ms=600000

# Create another topic for testing multiple consumer groups
kafka-topics.sh --bootstrap-server kafka:29092 \
    --create --if-not-exists \
    --topic order-events \
    --partitions 4 \
    --replication-factor 1

# Create a topic for testing single partition scenarios
kafka-topics.sh --bootstrap-server kafka:29092 \
    --create --if-not-exists \
    --topic priority-events \
    --partitions 1 \
    --replication-factor 1

echo ""
echo "📋 Created topics:"
kafka-topics.sh --bootstrap-server kafka:29092 --list | grep -E "ultra-events|order-events|priority-events"

echo ""
echo "📊 Topic details for ultra-events:"
kafka-topics.sh --bootstrap-server kafka:29092 --describe --topic ultra-events

echo ""
echo "🎯 Partition Strategy:"
echo "  - ultra-events: 4 partitions (one per consumer instance)"
echo "  - order-events: 4 partitions (for testing multiple groups)"
echo "  - priority-events: 1 partition (for ordered processing)"

echo ""
echo "✅ Headless Ultra setup complete!"
echo "💡 Topics are ready for consumer instances"
