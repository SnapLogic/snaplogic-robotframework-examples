# Headless Ultra Demo - Docker Implementation

This demo replicates SnapLogic's Headless Ultra pattern using Docker containers to simulate distributed Kafka consumers without a load balancer.

## Architecture

```
                    Kafka Topic (4 partitions)
                           |
        ┌──────────────────┴──────────────────┐
        |                                      |
    Group A (Node 1)                      Group B (Node 2)
    ├── Instance 1                        ├── Instance 3
    └── Instance 2                        └── Instance 4
```

## What This Simulates

1. **Headless Service Pattern**: Direct Kafka connections without FeedMaster
2. **Consumer Groups**: Two groups processing the same topic
3. **Distributed Processing**: 4 instances across 2 logical nodes
4. **Partition Assignment**: Kafka automatically assigns partitions to instances

## Quick Start

### Prerequisites
```bash
# Ensure Kafka is running
cd ../..  # Go to main project directory
make kafka-start
```

### Run the Demo
```bash
cd docker/headless-ultra-demo

# 1. Start Ultra instances (4 consumers)
make start

# 2. Start producer to generate messages
make producer

# 3. View processing logs
make logs

# 4. Monitor consumer groups (optional)
make monitor
# Open http://localhost:8081
```

## Commands

- `make start` - Start all 4 Ultra instances
- `make producer` - Start message producer
- `make monitor` - Launch Kafka UI on port 8081
- `make status` - Check consumer group status
- `make logs` - View real-time processing logs
- `make partitions` - Show partition assignments
- `make stop` - Stop all containers
- `make clean` - Remove everything

## How It Works

### 1. Consumer Groups
- **Group A** (Instances 1 & 2): Simulates Node 1
- **Group B** (Instances 3 & 4): Simulates Node 2

### 2. Partition Distribution
With 4 partitions and 2 instances per group:
- Group A, Instance 1: Partitions 0, 2
- Group A, Instance 2: Partitions 1, 3
- Group B, Instance 3: Partitions 0, 2
- Group B, Instance 4: Partitions 1, 3

### 3. Message Flow
1. Producer sends messages with keys
2. Kafka assigns messages to partitions based on key hash
3. Each consumer group processes all messages independently
4. Within a group, instances share the partition load

## Monitoring

### View Consumer Groups
```bash
docker exec snaplogic-kafka-kraft kafka-consumer-groups.sh \
  --bootstrap-server localhost:9092 --list

docker exec snaplogic-kafka-kraft kafka-consumer-groups.sh \
  --bootstrap-server localhost:9092 \
  --describe --group snaplogic-group-a
```

### Kafka UI
Access http://localhost:8081 to see:
- Consumer groups
- Partition assignments
- Lag monitoring
- Message flow

## Key Differences from Kubernetes

| Kubernetes Headless | Docker Demo |
|---------------------|-------------|
| `clusterIP: None` | Direct container networking |
| DNS returns Pod IPs | Containers use hostnames |
| Service discovery | Docker network DNS |
| StatefulSets | Individual containers |

## Learning Points

1. **No Load Balancer**: Instances connect directly to Kafka
2. **Consumer Groups**: Kafka handles work distribution
3. **Parallel Processing**: Multiple instances process simultaneously
4. **Fault Tolerance**: If one instance fails, others continue
5. **Scalability**: Easy to add/remove instances

## Customization

### Change Number of Partitions
Edit `setup-headless.sh`:
```bash
--partitions 8  # Increase for more parallelism
```

### Add More Instances
Add to `docker-compose.headless-ultra.yml`:
```yaml
snaplex-instance-5:
  # ... configuration
  environment:
    CONSUMER_GROUP: snaplogic-group-c
    INSTANCE_ID: instance-5
```

### Modify Message Rate
Edit `producer-script.sh`:
```bash
DELAY=0  # For maximum throughput
```

## Troubleshooting

### Instances Not Consuming
```bash
# Check if topic exists
docker exec snaplogic-kafka-kraft \
  kafka-topics.sh --bootstrap-server localhost:9092 --list

# Check consumer group status
make status
```

### View Individual Instance Logs
```bash
docker logs snaplex-ultra-instance-1
docker logs snaplex-ultra-instance-2
```

### Reset Consumer Offsets
```bash
docker exec snaplogic-kafka-kraft kafka-consumer-groups.sh \
  --bootstrap-server localhost:9092 \
  --group snaplogic-group-a \
  --reset-offsets --to-earliest \
  --topic ultra-events --execute
```

## Clean Up
```bash
make clean
```

This removes all containers and data related to the headless ultra demo.