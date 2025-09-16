# Makefile for Headless Ultra Demo - Bitnami Kafka
# Uses Bitnami images for consistency with main Kafka setup

KAFKA_CONTAINER = snaplogic-kafka-kraft
COMPOSE_FILE = docker-compose.headless-ultra-bitnami.yml

.PHONY: help start stop status producer monitor logs clean partitions test-consumer health send-test

help:
	@echo "🚀 Headless Ultra Demo Commands (Bitnami)"
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@echo "  make start         - Start Ultra instances"
	@echo "  make producer      - Start message producer"
	@echo "  make monitor       - Open Kafka UI (port 8081)"
	@echo "  make status        - Check consumer group status"
	@echo "  make partitions    - Show partition assignments"
	@echo "  make logs          - View all instance logs"
	@echo "  make test-consumer - Test single consumer"
	@echo "  make send-test     - Send test messages manually"
	@echo "  make health        - Health check"
	@echo "  make stop          - Stop all containers"
	@echo "  make clean         - Stop and remove everything"
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Start the headless ultra demo
start:
	@echo "🚀 Starting Headless Ultra Demo (Bitnami)..."
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@echo "📝 Prerequisites: Kafka must be running"
	@echo ""
	@echo "🔧 Making scripts executable..."
	@chmod +x *.sh 2>/dev/null || true
	@docker-compose -f $(COMPOSE_FILE) up -d
	@echo ""
	@echo "⏳ Waiting for instances to start..."
	@sleep 10
	@echo "✅ Ultra instances are running!"
	@echo ""
	@echo "📊 Active Consumer Groups:"
	@docker exec $(KAFKA_CONTAINER) kafka-consumer-groups.sh \
		--bootstrap-server localhost:9092 --list 2>/dev/null | grep snaplogic || echo "No groups active yet"
	@echo ""
	@echo "💡 Next steps:"
	@echo "   1. Run 'make producer' to start sending messages"
	@echo "   2. Run 'make monitor' to view Kafka UI"
	@echo "   3. Run 'make logs' to see instances processing"

# Start the producer
producer:
	@echo "📤 Starting message producer..."
	@docker-compose -f $(COMPOSE_FILE) --profile producer up -d kafka-producer-headless
	@echo "✅ Producer started!"
	@echo "📊 Check logs with: docker logs -f kafka-producer-headless"

# Start monitoring UI
monitor:
	@echo "🖥️  Starting Kafka UI..."
	@docker-compose -f $(COMPOSE_FILE) --profile monitoring up -d kafka-ui-headless
	@echo "✅ Kafka UI available at: http://localhost:8081"
	@echo "   View consumer groups and partition assignments"
	@sleep 2
	@command -v open >/dev/null 2>&1 && open http://localhost:8081 || echo ""

# Check consumer group status
status:
	@echo "📊 Consumer Group Status"
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@echo ""
	@echo "📋 All Consumer Groups:"
	@docker exec $(KAFKA_CONTAINER) kafka-consumer-groups.sh \
		--bootstrap-server localhost:9092 --list 2>/dev/null || echo "No groups found"
	@echo ""
	@echo "🔵 Group A Details (Node 1 - Instances 1 & 2):"
	@docker exec $(KAFKA_CONTAINER) kafka-consumer-groups.sh \
		--bootstrap-server localhost:9092 \
		--describe --group snaplogic-group-a 2>/dev/null || echo "Group not active yet"
	@echo ""
	@echo "🟢 Group B Details (Node 2 - Instances 3 & 4):"
	@docker exec $(KAFKA_CONTAINER) kafka-consumer-groups.sh \
		--bootstrap-server localhost:9092 \
		--describe --group snaplogic-group-b 2>/dev/null || echo "Group not active yet"
	@echo ""
	@echo "📦 Container Status:"
	@docker ps --format "table {{.Names}}\t{{.Status}}\t{{.State}}" | grep -E "(snaplex-instance|NAMES)" || true

# Show partition assignments
partitions:
	@echo "📊 Partition Assignments for ultra-events topic"
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@docker exec $(KAFKA_CONTAINER) kafka-topics.sh \
		--bootstrap-server localhost:9092 \
		--describe --topic ultra-events 2>/dev/null || echo "Topic not found. Run 'make start' first."

# Test a single consumer interactively
test-consumer:
	@echo "🧪 Starting test consumer for ultra-events topic..."
	@echo "   Press Ctrl+C to stop"
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@docker exec -it $(KAFKA_CONTAINER) kafka-console-consumer.sh \
		--bootstrap-server localhost:9092 \
		--topic ultra-events \
		--group test-consumer-group \
		--from-beginning

# View logs from all instances
logs:
	@echo "📜 Viewing logs from all Ultra instances..."
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@docker-compose -f $(COMPOSE_FILE) logs -f --tail=20

# View logs for specific instance
logs-instance:
	@echo "Select instance (1-4):"
	@read INSTANCE && docker logs -f snaplex-ultra-instance-$$INSTANCE

# Stop all containers
stop:
	@echo "⛔ Stopping Headless Ultra Demo..."
	@docker-compose -f $(COMPOSE_FILE) down
	@echo "✅ All instances stopped"

# Clean up everything
clean:
	@echo "🧹 Cleaning up Headless Ultra Demo..."
	@docker-compose -f $(COMPOSE_FILE) down -v
	@docker rm -f kafka-producer-headless kafka-setup-headless 2>/dev/null || true
	@echo "✅ Cleanup complete"

# Send test messages manually
send-test:
	@echo "📨 Sending test messages to ultra-events..."
	@for i in 1 2 3 4 5; do \
		echo "{\"id\": $$i, \"message\": \"Test message $$i\", \"timestamp\": \"$$(date -u +%Y-%m-%dT%H:%M:%SZ)\"}" | \
		docker exec -i $(KAFKA_CONTAINER) kafka-console-producer.sh \
			--bootstrap-server localhost:9092 \
			--topic ultra-events; \
	done
	@echo "✅ Sent 5 test messages"

# Health check
health:
	@echo "🏥 Health Check"
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@echo "Kafka Broker:"
	@docker exec $(KAFKA_CONTAINER) kafka-broker-api-versions.sh \
		--bootstrap-server localhost:9092 >/dev/null 2>&1 \
		&& echo "  ✅ Kafka is healthy" || echo "  ❌ Kafka is not responding"
	@echo ""
	@echo "Consumer Instances:"
	@for i in 1 2 3 4; do \
		if docker ps | grep -q snaplex-ultra-instance-$$i; then \
			echo "  ✅ Instance $$i is running"; \
		else \
			echo "  ❌ Instance $$i is not running"; \
		fi \
	done
	@echo ""
	@echo "Topics:"
	@docker exec $(KAFKA_CONTAINER) kafka-topics.sh \
		--bootstrap-server localhost:9092 --list 2>/dev/null | grep -E "ultra-events|order-events" | \
		while read topic; do echo "  ✅ $$topic exists"; done || echo "  ❌ No topics found"

# Quick info about the setup
info:
	@echo "📋 Headless Ultra Demo Info"
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@echo "Image: bitnami/kafka:3.7"
	@echo "Consumer Groups: snaplogic-group-a, snaplogic-group-b"
	@echo "Instances: 4 (2 per node)"
	@echo "Topic: ultra-events (4 partitions)"
	@echo "Kafka UI: http://localhost:8081"
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

.DEFAULT_GOAL := help
