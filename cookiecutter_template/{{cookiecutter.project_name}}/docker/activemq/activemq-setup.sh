#!/bin/sh
# ActiveMQ Artemis Setup Script
# This script runs after ActiveMQ is healthy to display connection information

echo 'Starting ActiveMQ setup...'
sleep 10
set -x

echo 'ActiveMQ Artemis is ready!'
echo 'Checking broker status...'

# Test connection to web console
response_code=$(curl -s -o /dev/null -w '%{http_code}' -u admin:admin http://activemq:8161/console/)
echo "Web console response code: $response_code"

if [ $response_code -eq 200 ]; then
    echo 'Web console is accessible!'
else
    echo 'Warning: Web console may not be fully ready yet'
fi

echo 'Creating setup info...'
setup_info='{
  "setup_date": "'$(date -Iseconds)'",
  "broker_url": "tcp://activemq:61616",
  "web_console": "http://localhost:8161/console",
  "credentials": {
    "username": "admin",
    "password": "admin"
  },
  "queues": {
    "test_queue": "queue://test.queue",
    "demo_queue": "queue://demo.queue",
    "sap_idoc_queue": "queue://sap.idoc.queue"
  },
  "topics": {
    "test_topic": "topic://test.topic",
    "notifications": "topic://notifications",
    "price_updates": "topic://price.updates"
  },
  "routing_types": {
    "default_address": "BOTH",
    "default_queue": "ANYCAST",
    "info": "Addresses support both ANYCAST (queue) and MULTICAST (topic) routing"
  },
  "connection_examples": {
    "java_url": "tcp://localhost:61616",
    "python_url": "stomp+ssl://localhost:61613",
    "stomp_anycast": "/queue/destination",
    "stomp_multicast": "/topic/destination"
  },
  "status": "ready"
}'

echo 'Setup configuration:'
echo $setup_info | sed 's/,/,\n  /g' | sed 's/{/\n  {\n    /g' | sed 's/}/\n  }\n/g'

set +x
echo 'ActiveMQ setup completed successfully!'
echo ''
echo '=== ActiveMQ Connection Details ==='
echo 'Web Console: http://localhost:8161/console'
echo 'Username: admin'
echo 'Password: admin'
echo ''
echo 'JMS Connection URL: tcp://localhost:61616'
echo 'STOMP Connection URL: tcp://localhost:61613'
echo 'Broker Name: activemq'
echo ''
echo '=== Routing Types ==='
echo 'Default Address Routing: BOTH (supports ANYCAST and MULTICAST)'
echo 'Default Queue Routing: ANYCAST'
echo ''
echo 'To create ANYCAST (queue): Use /queue/ prefix in STOMP'
echo 'To create MULTICAST (topic): Use /topic/ prefix in STOMP'
echo ''
echo 'Suggested Queue Names (ANYCAST):'
echo '  - test.queue (for testing)'
echo '  - demo.queue (for demos)'
echo '  - sap.idoc.queue (for SAP IDOC messages)'
echo ''
echo 'Suggested Topic Names (MULTICAST):'
echo '  - test.topic (for testing)'
echo '  - notifications (for system notifications)'
echo '  - price.updates (for price broadcasts)'
echo ''
echo 'Queues/Topics are created automatically when first accessed.'
