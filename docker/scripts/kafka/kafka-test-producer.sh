#!/bin/bash
# Kafka test producer - sends test messages to topics

echo "📤 Kafka Test Producer"
echo "====================="

# Configuration
BOOTSTRAP_SERVER="${KAFKA_BOOTSTRAP_SERVER:-localhost:9092}"
TOPIC="${TOPIC:-test-topic}"
MESSAGE_COUNT="${MESSAGE_COUNT:-10}"

echo "Configuration:"
echo "  Bootstrap Server: $BOOTSTRAP_SERVER"
echo "  Topic: $TOPIC"
echo "  Message Count: $MESSAGE_COUNT"
echo ""

# Check if topic exists, create if it doesn't
kafka-topics.sh --bootstrap-server $BOOTSTRAP_SERVER --describe --topic $TOPIC >/dev/null 2>&1
if [ $? -ne 0 ]; then
    echo "Topic $TOPIC doesn't exist. Creating..."
    kafka-topics.sh --bootstrap-server $BOOTSTRAP_SERVER \
        --create --topic $TOPIC \
        --partitions 3 \
        --replication-factor 1
fi

echo "Sending test messages to topic: $TOPIC"

# Send messages with different patterns
for i in $(seq 1 $MESSAGE_COUNT); do
    TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    
    # Create JSON message
    MESSAGE=$(cat <<EOF
{
  "id": $i,
  "timestamp": "$TIMESTAMP",
  "type": "test",
  "data": {
    "value": $((RANDOM % 100)),
    "status": "active",
    "message": "Test message number $i"
  }
}
EOF
)
    
    echo "$MESSAGE" | kafka-console-producer.sh \
        --bootstrap-server $BOOTSTRAP_SERVER \
        --topic $TOPIC \
        --property "parse.key=true" \
        --property "key.separator=:" \
        <<< "key-$i:$MESSAGE"
    
    echo "✅ Sent message $i"
done

echo ""
echo "✅ Successfully sent $MESSAGE_COUNT messages to topic: $TOPIC"
echo ""
echo "To consume messages, run:"
echo "docker exec snaplogic-kafka-kraft kafka-console-consumer.sh \\"
echo "  --bootstrap-server $BOOTSTRAP_SERVER \\"
echo "  --topic $TOPIC \\"
echo "  --from-beginning"
