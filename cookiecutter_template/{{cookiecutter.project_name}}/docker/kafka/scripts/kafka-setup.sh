#!/bin/bash
# Kafka setup script - creates initial topics

echo "🚀 Setting up Kafka topics..."

# Wait for Kafka to be ready
echo "⏳ Waiting for Kafka to be ready..."
until kafka-topics.sh --bootstrap-server kafka:29092 --list &>/dev/null; do
    echo "Kafka is not ready yet. Waiting..."
    sleep 5
done

echo "✅ Kafka is ready! Creating topics..."

# Create SnapLogic-related topics
kafka-topics.sh --bootstrap-server kafka:29092 \
    --create --if-not-exists \
    --topic snaplogic-events \
    --partitions 3 \
    --replication-factor 1 \
    --config retention.ms=604800000 \
    --config compression.type=snappy

kafka-topics.sh --bootstrap-server kafka:29092 \
    --create --if-not-exists \
    --topic snaplogic-logs \
    --partitions 2 \
    --replication-factor 1 \
    --config retention.ms=259200000 \
    --config compression.type=gzip

kafka-topics.sh --bootstrap-server kafka:29092 \
    --create --if-not-exists \
    --topic snaplogic-metrics \
    --partitions 1 \
    --replication-factor 1 \
    --config retention.ms=86400000

kafka-topics.sh --bootstrap-server kafka:29092 \
    --create --if-not-exists \
    --topic dead-letter-queue \
    --partitions 1 \
    --replication-factor 1 \
    --config retention.ms=1209600000

kafka-topics.sh --bootstrap-server kafka:29092 \
    --create --if-not-exists \
    --topic test-topic \
    --partitions 3 \
    --replication-factor 1

echo "📋 Created topics:"
kafka-topics.sh --bootstrap-server kafka:29092 --list

echo "✅ Kafka setup complete!"
