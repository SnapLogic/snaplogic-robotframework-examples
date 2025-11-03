#!/bin/bash
# Kafka health check script - VERBOSE version for manual testing

echo "🔍 Kafka Health Check - Verbose Mode"
echo "====================================="

# Check if we can list topics (basic connectivity test)
echo -n "Checking Kafka broker connectivity... "
if kafka-topics.sh --bootstrap-server localhost:9092 --list >/dev/null 2>&1; then
    echo "✅ HEALTHY"
    echo ""
    echo "📊 Broker Details:"
    echo "  - Bootstrap server: localhost:9092"
    echo "  - Status: Responding to commands"
    
    # Show topic count
    topic_count=$(kafka-topics.sh --bootstrap-server localhost:9092 --list 2>/dev/null | wc -l)
    echo "  - Topics available: $topic_count"
    
    # Show cluster ID if available
    echo ""
    echo "🎯 Additional Checks:"
    
    # Test broker API
    if kafka-broker-api-versions.sh --bootstrap-server localhost:9092 >/dev/null 2>&1; then
        echo "  ✅ Broker API: Responsive"
    else
        echo "  ⚠️  Broker API: Not responding"
    fi
    
    # Test metadata
    if kafka-metadata.sh --snapshot /bitnami/kafka/data/__cluster_metadata-0/00000000000000000000.log --print-brokers >/dev/null 2>&1; then
        echo "  ✅ KRaft Metadata: Accessible"
    else
        echo "  ⚠️  KRaft Metadata: Not accessible (may be normal)"
    fi
    
    echo ""
    echo "======================================"
    echo "✅ Overall Status: HEALTHY"
    echo "======================================"
    exit 0
else
    echo "❌ UNHEALTHY"
    echo ""
    echo "🔴 Kafka broker is not responding!"
    echo ""
    echo "Possible issues:"
    echo "  - Kafka is still starting up"
    echo "  - Kafka crashed or stopped"
    echo "  - Network connectivity issues"
    echo "  - Wrong port configuration"
    echo ""
    echo "Troubleshooting:"
    echo "  1. Check container status: docker ps | grep kafka"
    echo "  2. Check logs: docker logs snaplogic-kafka-kraft"
    echo "  3. Verify port 9092 is accessible"
    echo ""
    echo "======================================"
    echo "❌ Overall Status: UNHEALTHY"
    echo "======================================"
    exit 1
fi
