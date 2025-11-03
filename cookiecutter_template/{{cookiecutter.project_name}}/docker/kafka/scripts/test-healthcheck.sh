#!/bin/bash
# Test health check scripts

echo "======================================"
echo "🧪 Testing Kafka Health Check Scripts"
echo "======================================"
echo ""

# Test the silent health check
echo "1️⃣ Testing Silent Health Check (kafka-healthcheck.sh):"
echo "   Running: docker exec snaplogic-kafka-kraft /scripts/kafka-healthcheck.sh"
docker exec snaplogic-kafka-kraft /scripts/kafka-healthcheck.sh
exit_code=$?
echo "   Exit Code: $exit_code"
if [ $exit_code -eq 0 ]; then
    echo "   Result: ✅ HEALTHY (exit code 0)"
else
    echo "   Result: ❌ UNHEALTHY (exit code $exit_code)"
fi

echo ""
echo "2️⃣ Testing Verbose Health Check (kafka-healthcheck-verbose.sh):"
echo "   Running: docker exec snaplogic-kafka-kraft /scripts/kafka-healthcheck-verbose.sh"
echo "   ---"
docker exec snaplogic-kafka-kraft /scripts/kafka-healthcheck-verbose.sh
echo "   ---"

echo ""
echo "📝 Summary:"
echo "  • Silent version: For Docker health checks (no output)"
echo "  • Verbose version: For manual debugging (detailed output)"
echo ""
echo "💡 Usage:"
echo "  • In docker-compose: Uses silent version"
echo "  • For debugging: chmod +x ./docker/scripts/kafka/test-healthcheck.sh && ./docker/scripts/kafka/test-healthcheck.sh"
