#!/bin/bash
# Consumer script for Bitnami Kafka - simulating SnapLogic Ultra Task Instance

echo "🔵 Starting Ultra Instance: $INSTANCE_ID on $NODE_ID"
echo "📡 Connecting to Kafka at: $KAFKA_BROKER"
echo "👥 Consumer Group: $CONSUMER_GROUP"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Function to handle shutdown gracefully
cleanup() {
    echo "🛑 Shutting down $INSTANCE_ID..."
    exit 0
}
trap cleanup SIGTERM SIGINT

# Create a unique client ID
CLIENT_ID="${CONSUMER_GROUP}-${INSTANCE_ID}"

# Start consuming messages
echo "📥 Starting consumer for topic: ultra-events"

# Note: Bitnami Kafka uses kafka-console-consumer.sh in /opt/bitnami/kafka/bin/
# But it's already in PATH, so we can call it directly

# Start consuming and processing messages
while true; do
    echo "[$INSTANCE_ID] Waiting for messages..."
    
    # Consume messages with timeout
    # Using Bitnami's kafka-console-consumer.sh
    timeout 10 kafka-console-consumer.sh \
        --bootstrap-server ${KAFKA_BROKER} \
        --topic ultra-events \
        --group ${CONSUMER_GROUP} \
        --consumer-property client.id=${CLIENT_ID} \
        --from-beginning \
        --max-messages 1 2>/dev/null | while read message; do
        
        # Simulate processing
        TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
        echo "[$TIMESTAMP] [$INSTANCE_ID@$NODE_ID] Processing: $message"
        
        # Simulate some work (transform, enrich, etc.)
        sleep 0.5
        
        echo "[$TIMESTAMP] [$INSTANCE_ID@$NODE_ID] ✅ Processed successfully"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    done
    
    # Small delay between polling cycles
    sleep 2
done
