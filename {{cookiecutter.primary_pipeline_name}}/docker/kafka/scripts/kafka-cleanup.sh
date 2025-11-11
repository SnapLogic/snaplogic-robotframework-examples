#!/bin/bash
# Kafka cleanup script - removes old topics and data

echo "🧹 Kafka Cleanup Script"
echo "======================="

BOOTSTRAP_SERVER="${KAFKA_BOOTSTRAP_SERVER:-kafka:29092}"

echo "⚠️  WARNING: This will delete test topics!"
echo "Press Ctrl+C to cancel, or wait 5 seconds to continue..."
sleep 5

# List of topics to clean up (add your test topics here)
TEST_TOPICS=(
    "test-topic"
    "test-topic2"
    "test-topic3"
    "test-topic4"
    "test-topic5"
    "robot-test-*"
)

echo "Current topics:"
kafka-topics.sh --bootstrap-server $BOOTSTRAP_SERVER --list

echo ""
echo "Cleaning up test topics..."

for pattern in "${TEST_TOPICS[@]}"; do
    # Get matching topics
    TOPICS=$(kafka-topics.sh --bootstrap-server $BOOTSTRAP_SERVER --list | grep "^$pattern")
    
    if [ ! -z "$TOPICS" ]; then
        while IFS= read -r topic; do
            echo "Deleting topic: $topic"
            kafka-topics.sh --bootstrap-server $BOOTSTRAP_SERVER \
                --delete --topic "$topic" 2>/dev/null || true
        done <<< "$TOPICS"
    fi
done

echo ""
echo "✅ Cleanup complete!"
echo ""
echo "Remaining topics:"
kafka-topics.sh --bootstrap-server $BOOTSTRAP_SERVER --list
