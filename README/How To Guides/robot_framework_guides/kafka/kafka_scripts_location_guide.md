# Kafka Scripts Location and Usage Guide

## Table of Contents
1. [Standard Installation Locations](#standard-installation-locations)
2. [Docker Container Locations](#docker-container-locations)
3. [Common Kafka Scripts](#common-kafka-scripts)
4. [Finding Scripts in Your Environment](#finding-scripts-in-your-environment)
5. [Script Usage Examples](#script-usage-examples)
6. [Troubleshooting](#troubleshooting)

---

## Standard Installation Locations

### Linux Installations
```bash
/opt/kafka/bin/                     # Standard enterprise installation
/usr/local/kafka/bin/               # Manual installation location
/usr/share/kafka/bin/               # Package manager installation
~/kafka_2.13-3.7.0/bin/            # User home directory installation
/etc/kafka/bin/                     # Configuration-centric installation
```

### macOS (Homebrew)
```bash
/usr/local/opt/kafka/bin/           # Intel Macs
/opt/homebrew/opt/kafka/bin/        # Apple Silicon Macs
```

### Windows
```bash
C:\kafka\bin\windows\               # Windows-specific scripts (.bat files)
C:\Program Files\kafka\bin\         # Installation via installer
```

---

## Docker Container Locations

### Important Note: Scripts Included with Docker Images
**Kafka Docker images come with all scripts pre-installed.** You don't need to install Kafka separately when using Docker. The scripts are already available inside the container at the locations listed below.

#### Advantages of Docker Images with Pre-installed Scripts:
- ✅ **No Installation Required** - Scripts are ready to use immediately
- ✅ **Version Consistency** - Scripts match the Kafka broker version
- ✅ **All Dependencies Included** - Java runtime and libraries pre-configured
- ✅ **Platform Independent** - Works the same on Linux, Mac, and Windows
- ✅ **Isolation** - No conflicts with host system installations

```bash
# Example: Running scripts in Docker containers
docker exec <container_name> kafka-topics.sh --list --bootstrap-server localhost:9092

# The scripts are already at these locations inside the container:
# - /opt/kafka/bin/kafka-topics.sh
# - /opt/kafka/bin/kafka-console-producer.sh
# - /opt/kafka/bin/kafka-console-consumer.sh
# etc.
```

#### Common Docker Images with Kafka Scripts:
| Image | Scripts Location | Notes |
|-------|-----------------|-------|
| `confluentinc/cp-kafka` | `/opt/kafka/bin/` | Includes Confluent additions |
| `apache/kafka` | `/opt/kafka/bin/` | Official Apache image |
| `bitnami/kafka` | `/opt/bitnami/kafka/bin/` | Production-ready image |
| `wurstmeister/kafka` | `/opt/kafka/bin/` | Popular community image |

### By Image Provider

#### Apache Kafka Official
```bash
/kafka/bin/                         # Base directory for scripts
/opt/kafka/bin/                     # Alternative location
```

#### Confluent Platform
```bash
/opt/confluent/bin/                 # Confluent-specific tools
/opt/kafka/bin/                     # Standard Kafka scripts
/usr/bin/                           # Symlinked commands
```

#### Bitnami
```bash
/opt/bitnami/kafka/bin/             # Primary location
/opt/bitnami/scripts/               # Helper scripts
```

#### Strimzi
```bash
/opt/kafka/bin/                     # Standard location
/usr/local/bin/                     # Symlinks for easy access
```

---

## Common Kafka Scripts

### Topic Management
| Script | Purpose | Common Usage |
|--------|---------|--------------|
| `kafka-topics.sh` | Create, delete, list, describe topics | `kafka-topics.sh --list --bootstrap-server localhost:9092` |
| `kafka-configs.sh` | Modify topic/broker configurations | `kafka-configs.sh --describe --all --bootstrap-server localhost:9092` |
| `kafka-reassign-partitions.sh` | Reassign partitions between brokers | Used for rebalancing |

### Message Operations
| Script | Purpose | Common Usage |
|--------|---------|--------------|
| `kafka-console-producer.sh` | Send messages to topics | `kafka-console-producer.sh --topic test --bootstrap-server localhost:9092` |
| `kafka-console-consumer.sh` | Read messages from topics | `kafka-console-consumer.sh --topic test --from-beginning --bootstrap-server localhost:9092` |
| `kafka-dump-log.sh` | Examine log segments | Debugging message storage |

### Consumer Management
| Script | Purpose | Common Usage |
|--------|---------|--------------|
| `kafka-consumer-groups.sh` | Manage consumer groups | `kafka-consumer-groups.sh --list --bootstrap-server localhost:9092` |
| `kafka-consumer-perf-test.sh` | Performance testing | Benchmark consumer throughput |

### Cluster Management
| Script | Purpose | Common Usage |
|--------|---------|--------------|
| `kafka-broker-api-versions.sh` | Check API versions | Version compatibility checking |
| `kafka-metadata-shell.sh` | Inspect cluster metadata | KRaft mode metadata inspection |
| `kafka-cluster.sh` | Cluster-wide operations | Cluster ID management |
| `kafka-storage.sh` | Storage formatting (KRaft) | Initialize storage for KRaft mode |

### Performance & Monitoring
| Script | Purpose | Common Usage |
|--------|---------|--------------|
| `kafka-producer-perf-test.sh` | Test producer performance | Benchmark throughput |
| `kafka-log-dirs.sh` | Check log directory usage | Monitor disk usage |
| `kafka-verifiable-producer.sh` | Produce verifiable messages | Testing and validation |

---

## Finding Scripts in Your Environment

### Check Installation Location
```bash
# Find all Kafka scripts
find / -name "kafka-*.sh" 2>/dev/null

# Check if Kafka is in PATH
which kafka-topics.sh

# List all Kafka commands in PATH
compgen -c | grep kafka
```

### Docker Container Inspection
```bash
# Find scripts in a running container
docker exec <container_name> find / -name "kafka-*.sh" 2>/dev/null

# Check specific locations
docker exec <container_name> ls -la /opt/kafka/bin/
docker exec <container_name> ls -la /usr/bin/kafka*

# Get exact path of a script
docker exec <container_name> which kafka-topics.sh
```

### For Your SnapLogic Setup
```bash
# Specific to your kafka-kraft container
docker exec snaplogic-kafka-kraft ls -la /opt/kafka/bin/
docker exec snaplogic-kafka-kraft which kafka-topics.sh
```

---

## Script Usage Examples

### Topic Operations
```bash
# Create a topic
kafka-topics.sh --create \
    --topic my-topic \
    --partitions 3 \
    --replication-factor 1 \
    --bootstrap-server localhost:9092

# List all topics
kafka-topics.sh --list \
    --bootstrap-server localhost:9092

# Describe a topic
kafka-topics.sh --describe \
    --topic my-topic \
    --bootstrap-server localhost:9092

# Delete a topic
kafka-topics.sh --delete \
    --topic my-topic \
    --bootstrap-server localhost:9092
```

### Message Operations
```bash
# Produce messages interactively
kafka-console-producer.sh \
    --topic my-topic \
    --bootstrap-server localhost:9092

# Produce with key-value pairs
kafka-console-producer.sh \
    --topic my-topic \
    --property "parse.key=true" \
    --property "key.separator=:" \
    --bootstrap-server localhost:9092

# Consume from beginning
kafka-console-consumer.sh \
    --topic my-topic \
    --from-beginning \
    --bootstrap-server localhost:9092

# Consume with key and timestamp
kafka-console-consumer.sh \
    --topic my-topic \
    --property print.key=true \
    --property print.timestamp=true \
    --bootstrap-server localhost:9092
```

### Consumer Group Management
```bash
# List consumer groups
kafka-consumer-groups.sh --list \
    --bootstrap-server localhost:9092

# Describe consumer group
kafka-consumer-groups.sh --describe \
    --group my-consumer-group \
    --bootstrap-server localhost:9092

# Reset consumer group offset
kafka-consumer-groups.sh --reset-offsets \
    --group my-consumer-group \
    --topic my-topic \
    --to-earliest \
    --execute \
    --bootstrap-server localhost:9092
```

---

## Troubleshooting

### Script Not Found
```bash
# Issue: kafka-topics.sh: command not found

# Solution 1: Add to PATH
export PATH=$PATH:/opt/kafka/bin

# Solution 2: Use full path
/opt/kafka/bin/kafka-topics.sh --list --bootstrap-server localhost:9092

# Solution 3: Create alias
alias kafka-topics='/opt/kafka/bin/kafka-topics.sh'
```

### Permission Denied
```bash
# Issue: Permission denied when running scripts

# Solution: Make scripts executable
chmod +x /opt/kafka/bin/*.sh

# Or run with explicit shell
sh /opt/kafka/bin/kafka-topics.sh
```

### Docker-Specific Issues
```bash
# Issue: Scripts not working from host

# Solution: Always run inside container
docker exec -it <container_name> kafka-topics.sh --list --bootstrap-server localhost:9092

# Or create wrapper script on host
#!/bin/bash
docker exec -it snaplogic-kafka-kraft kafka-topics.sh "$@"
```

### Version Compatibility
```bash
# Check Kafka version
kafka-topics.sh --version

# Check broker API versions
kafka-broker-api-versions.sh --bootstrap-server localhost:9092
```

---

## Environment-Specific Notes

### KRaft Mode (Your Setup)
In KRaft mode (KIP-500), some scripts have changed:
- `kafka-storage.sh` - Format storage for KRaft
- `kafka-metadata-shell.sh` - Inspect metadata
- No more ZooKeeper-related scripts

### Wrapper Scripts
Many installations provide wrapper scripts in `/usr/bin/`:
```bash
/usr/bin/kafka-topics -> /opt/kafka/bin/kafka-topics.sh
```

### Cloud Distributions
- **AWS MSK**: Scripts accessed through AWS CLI/Console
- **Confluent Cloud**: Web UI and CLI tool (`confluent`)
- **Azure Event Hubs**: Azure CLI and Portal

---

## Quick Reference Card

| Task | Command |
|------|---------|
| List topics | `kafka-topics.sh --list --bootstrap-server kafka:9092` |
| Create topic | `kafka-topics.sh --create --topic test --partitions 3 --bootstrap-server kafka:9092` |
| Send message | `echo "Hello" \| kafka-console-producer.sh --topic test --bootstrap-server kafka:9092` |
| Read messages | `kafka-console-consumer.sh --topic test --from-beginning --bootstrap-server kafka:9092` |
| Delete topic | `kafka-topics.sh --delete --topic test --bootstrap-server kafka:9092` |
| List groups | `kafka-consumer-groups.sh --list --bootstrap-server kafka:9092` |

---

## Additional Resources

- [Apache Kafka Documentation](https://kafka.apache.org/documentation/)
- [Confluent Documentation](https://docs.confluent.io/)
- [Kafka Command Line Tools Reference](https://kafka.apache.org/documentation/#basic_ops)
