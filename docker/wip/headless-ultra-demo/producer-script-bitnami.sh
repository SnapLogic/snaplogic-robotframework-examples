#!/bin/bash
# Producer script for Bitnami Kafka - generates test messages for headless ultra demo

echo "📤 Starting Headless Ultra Producer (Bitnami)"
echo "📡 Connecting to Kafka at: kafka:29092"
echo "📝 Target topic: ultra-events"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Function to handle shutdown gracefully
cleanup() {
    echo "🛑 Shutting down producer..."
    exit 0
}
trap cleanup SIGTERM SIGINT

# Wait for Kafka to be ready
echo "⏳ Checking Kafka connection..."
until kafka-topics.sh --bootstrap-server kafka:29092 --list &>/dev/null; do
    echo "Waiting for Kafka to be ready..."
    sleep 5
done

echo "✅ Kafka is ready!"
echo ""

# Check if topic exists
if kafka-topics.sh --bootstrap-server kafka:29092 --list | grep -q "ultra-events"; then
    echo "✅ Topic 'ultra-events' exists"
    
    # Get partition count
    PARTITIONS=$(kafka-topics.sh --bootstrap-server kafka:29092 --describe --topic ultra-events | grep "PartitionCount" | awk '{print $2}' | cut -d':' -f2)
    echo "📊 Topic has ${PARTITIONS:-4} partitions"
else
    echo "⚠️  Topic 'ultra-events' not found - will be auto-created"
fi

echo ""
echo "🚀 Starting message production..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Message counter
MESSAGE_ID=1

# Production modes
MODE=${PRODUCER_MODE:-continuous}  # continuous, burst, or single
RATE=${PRODUCER_RATE:-1}          # Messages per second
BURST_SIZE=${BURST_SIZE:-100}     # Messages per burst

case $MODE in
    single)
        echo "📨 Sending single test message..."
        MESSAGE="{\"id\": $MESSAGE_ID, \"type\": \"test\", \"timestamp\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\", \"data\": \"Single test message\"}"
        echo $MESSAGE | kafka-console-producer.sh \
            --bootstrap-server kafka:29092 \
            --topic ultra-events
        echo "✅ Sent: $MESSAGE"
        ;;
        
    burst)
        echo "📨 Sending burst of $BURST_SIZE messages..."
        for i in $(seq 1 $BURST_SIZE); do
            MESSAGE="{\"id\": $MESSAGE_ID, \"type\": \"burst\", \"timestamp\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\", \"batch\": 1, \"sequence\": $i, \"data\": \"Burst message $i of $BURST_SIZE\"}"
            echo $MESSAGE | kafka-console-producer.sh \
                --bootstrap-server kafka:29092 \
                --topic ultra-events 2>/dev/null
            
            if [ $((i % 10)) -eq 0 ]; then
                echo "📊 Sent $i/$BURST_SIZE messages..."
            fi
            MESSAGE_ID=$((MESSAGE_ID + 1))
        done
        echo "✅ Burst complete! Sent $BURST_SIZE messages"
        ;;
        
    continuous|*)
        echo "📨 Continuous mode: Sending $RATE message(s) per second"
        echo "   Press Ctrl+C to stop"
        echo ""
        
        while true; do
            # Generate different message types for variety
            MESSAGE_TYPE=$((MESSAGE_ID % 4))
            
            case $MESSAGE_TYPE in
                0)
                    # Order message
                    MESSAGE="{\"id\": $MESSAGE_ID, \"type\": \"order\", \"timestamp\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\", \"orderId\": \"ORD-$MESSAGE_ID\", \"amount\": $((RANDOM % 1000 + 100)), \"status\": \"new\"}"
                    ;;
                1)
                    # User event
                    MESSAGE="{\"id\": $MESSAGE_ID, \"type\": \"user_event\", \"timestamp\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\", \"userId\": \"USR-$((RANDOM % 100))\", \"action\": \"login\", \"ip\": \"192.168.1.$((RANDOM % 255))\"}"
                    ;;
                2)
                    # System metric
                    MESSAGE="{\"id\": $MESSAGE_ID, \"type\": \"metric\", \"timestamp\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\", \"metric\": \"cpu_usage\", \"value\": $((RANDOM % 100)), \"host\": \"node-$((MESSAGE_ID % 2 + 1))\"}"
                    ;;
                3)
                    # Alert message
                    SEVERITY=("info" "warning" "error" "critical")
                    SEV_INDEX=$((RANDOM % 4))
                    MESSAGE="{\"id\": $MESSAGE_ID, \"type\": \"alert\", \"timestamp\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\", \"severity\": \"${SEVERITY[$SEV_INDEX]}\", \"message\": \"Alert $MESSAGE_ID detected\", \"source\": \"monitor-$((RANDOM % 5))\"}"
                    ;;
            esac
            
            # Send the message using Bitnami's kafka-console-producer.sh
            echo $MESSAGE | kafka-console-producer.sh \
                --bootstrap-server kafka:29092 \
                --topic ultra-events 2>/dev/null
            
            # Log every 10th message to avoid spam
            if [ $((MESSAGE_ID % 10)) -eq 0 ]; then
                echo "[$(date '+%H:%M:%S')] 📊 Sent $MESSAGE_ID messages (latest type: $(echo $MESSAGE | grep -o '"type":"[^"]*"' | cut -d'"' -f4))"
            else
                # Show progress indicator
                echo -n "."
            fi
            
            MESSAGE_ID=$((MESSAGE_ID + 1))
            
            # Control rate
            if [ $RATE -gt 0 ]; then
                sleep $(echo "scale=2; 1/$RATE" | bc)
            fi
        done
        ;;
esac

echo ""
echo "🏁 Producer finished"
