# Kafka Listeners Configuration Guide

## Table of Contents
1. [Overview](#overview)
2. [Understanding Listeners](#understanding-listeners)
3. [Listener Types in Our Configuration](#listener-types-in-our-configuration)
4. [Configuration Parameters Explained](#configuration-parameters-explained)
5. [Network Architecture](#network-architecture)
6. [Common Use Cases](#common-use-cases)
7. [Troubleshooting](#troubleshooting)

---

## Overview

Kafka listeners define how clients and brokers communicate with each other. In a containerized environment, proper listener configuration is crucial for enabling communication between containers, host applications, and external clients.

---

## Understanding Listeners

### What is a Listener?

A listener in Kafka is a combination of:
- **Protocol** (PLAINTEXT, SSL, SASL_SSL, etc.)
- **Host/IP** (where Kafka binds)
- **Port** (which port to listen on)

### Listeners vs Advertised Listeners

| Type | Purpose | Usage |
|------|---------|-------|
| **Listeners** | Where Kafka actually binds and listens | Server-side binding configuration |
| **Advertised Listeners** | What Kafka tells clients to connect to | Client connection information |

---

## Listener Types in Our Configuration

### 1. PLAINTEXT Listener (Internal)
```
PLAINTEXT://:29092
```
- **Port**: 29092
- **Purpose**: Internal container-to-container communication
- **Security**: No encryption (plaintext)
- **Advertised as**: `kafka:29092`
- **Used by**: 
  - Other containers in the same Docker network
  - SnapLogic pipelines
  - Internal microservices

### 2. CONTROLLER Listener (KRaft)
```
CONTROLLER://:9093
```
- **Port**: 9093
- **Purpose**: KRaft controller communication
- **Security**: No encryption (plaintext)
- **Used by**: 
  - Internal Kafka broker consensus
  - Controller quorum voters
  - Metadata management
- **Note**: This replaces ZooKeeper in KRaft mode

### 3. PLAINTEXT_HOST Listener (External)
```
PLAINTEXT_HOST://:9092
```
- **Port**: 9092
- **Purpose**: External access from host machine
- **Security**: No encryption (plaintext)
- **Advertised as**: `localhost:9092`
- **Used by**:
  - Applications running on the host machine
  - Development tools
  - Local testing

---

## Configuration Parameters Explained

### KAFKA_CFG_LISTENERS
```env
KAFKA_CFG_LISTENERS=PLAINTEXT://:29092,CONTROLLER://:9093,PLAINTEXT_HOST://:9092
```
Defines the network endpoints where Kafka broker binds and listens for connections.

**Syntax**: `LISTENER_NAME://host:port`
- Empty host (`//:`) means bind to all available network interfaces (0.0.0.0)

### KAFKA_CFG_ADVERTISED_LISTENERS
```env
KAFKA_CFG_ADVERTISED_LISTENERS=PLAINTEXT://kafka:29092,PLAINTEXT_HOST://localhost:9092
```
Defines the addresses that clients should use to connect to the broker.

**Key Points**:
- `kafka:29092` - Docker service name for internal network
- `localhost:9092` - For host machine access
- Controller listener is not advertised (internal only)

### KAFKA_CFG_LISTENER_SECURITY_PROTOCOL_MAP
```env
KAFKA_CFG_LISTENER_SECURITY_PROTOCOL_MAP=CONTROLLER:PLAINTEXT,PLAINTEXT:PLAINTEXT,PLAINTEXT_HOST:PLAINTEXT
```
Maps each listener name to its security protocol.

| Listener Name | Security Protocol | Description |
|--------------|-------------------|-------------|
| CONTROLLER | PLAINTEXT | No encryption for controller |
| PLAINTEXT | PLAINTEXT | No encryption for internal |
| PLAINTEXT_HOST | PLAINTEXT | No encryption for external |

### KAFKA_CFG_CONTROLLER_LISTENER_NAMES
```env
KAFKA_CFG_CONTROLLER_LISTENER_NAMES=CONTROLLER
```
Identifies which listener is used for controller communication in KRaft mode.

### KAFKA_CFG_INTER_BROKER_LISTENER_NAME
```env
KAFKA_CFG_INTER_BROKER_LISTENER_NAME=PLAINTEXT
```
Specifies which listener brokers use to communicate with each other.

---

## Network Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     Docker Network (snaplogicnet)           │
│                                                             │
│  ┌─────────────────────┐      ┌─────────────────────┐     │
│  │   SnapLogic         │      │   Other Container   │     │
│  │   Container         │      │                     │     │
│  │                     │      │                     │     │
│  │  Connects to:       │      │  Connects to:       │     │
│  │  kafka:29092 ──────┼──────┼──► kafka:29092      │     │
│  └─────────────────────┘      └─────────────────────┘     │
│                                        │                   │
│                                        ▼                   │
│  ┌─────────────────────────────────────────────────────┐  │
│  │            Kafka Broker Container                   │  │
│  │                                                     │  │
│  │  Listeners:                                         │  │
│  │  ┌──────────────────────────────────────────────┐  │  │
│  │  │ PLAINTEXT (Internal)     - *:29092          │◄─┼──┼── Container Access
│  │  │ Advertised as: kafka:29092                  │  │  │
│  │  └──────────────────────────────────────────────┘  │  │
│  │                                                     │  │
│  │  ┌──────────────────────────────────────────────┐  │  │
│  │  │ CONTROLLER (KRaft)       - *:9093           │  │  │
│  │  │ Not advertised (internal only)              │  │  │
│  │  └──────────────────────────────────────────────┘  │  │
│  │                                                     │  │
│  │  ┌──────────────────────────────────────────────┐  │  │
│  │  │ PLAINTEXT_HOST (External) - *:9092          │◄─┼──┼── Host Access
│  │  │ Advertised as: localhost:9092               │  │  │
│  │  └──────────────────────────────────────────────┘  │  │
│  └─────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
                                   ▲
                                   │
┌──────────────────────────────────┼─────────────────────────┐
│              Host Machine        │                         │
│                                  │                         │
│  ┌───────────────────────────────┼──────────────────┐     │
│  │   Development Application     │                  │     │
│  │   Connects to: localhost:9092 ─                  │     │
│  └──────────────────────────────────────────────────┘     │
└─────────────────────────────────────────────────────────────┘
```

---

## Common Use Cases

### Container-to-Container Communication
```python
# Python application in Docker container
from kafka import KafkaProducer

producer = KafkaProducer(
    bootstrap_servers='kafka:29092'  # Internal listener
)
```

### Host Machine to Kafka
```python
# Python application on host machine
from kafka import KafkaProducer

producer = KafkaProducer(
    bootstrap_servers='localhost:9092'  # External listener
)
```

### SnapLogic Configuration
```json
{
  "bootstrap_servers": "kafka:29092",
  "security_protocol": "PLAINTEXT"
}
```

### Robot Framework Tests
```robot
*** Variables ***
${KAFKA_BOOTSTRAP_SERVER}    kafka:29092    # Internal for container tests
```

---

## Port Mapping Summary

| Listener | Container Port | Host Port | Accessible From |
|----------|---------------|-----------|-----------------|
| PLAINTEXT | 29092 | - | Containers only |
| CONTROLLER | 9093 | - | Internal only |
| PLAINTEXT_HOST | 9092 | 9092 | Host machine |

---

## Troubleshooting

### Connection Issues

#### From Container: "Can't connect to localhost:9092"
**Problem**: Container trying to use host listener
**Solution**: Use `kafka:29092` instead

#### From Host: "Can't connect to kafka:29092"
**Problem**: Host trying to use internal listener
**Solution**: Use `localhost:9092` instead

#### "No advertised listeners"
**Problem**: Listener configuration mismatch
**Solution**: Ensure advertised listeners match actual network topology

### Verification Commands

```bash
# Check listeners from inside container
docker exec snaplogic-kafka-kraft kafka-configs.sh \
  --bootstrap-server kafka:29092 \
  --entity-type brokers \
  --entity-name 1 \
  --describe

# Test connection from container
docker exec snaplogic-kafka-kraft kafka-topics.sh \
  --bootstrap-server kafka:29092 \
  --list

# Test connection from host
kafka-topics.sh \
  --bootstrap-server localhost:9092 \
  --list
```

### Common Mistakes

1. **Using wrong address from wrong context**
   - ❌ Container using `localhost:9092`
   - ✅ Container using `kafka:29092`

2. **Port confusion**
   - ❌ Mixing up 9092 and 29092
   - ✅ Remember: 29092 internal, 9092 external

3. **Missing network configuration**
   - ❌ Container not on same network
   - ✅ Ensure all containers are on `snaplogicnet`

---

## Security Considerations

⚠️ **Warning**: Current configuration uses PLAINTEXT for all listeners. In production:

1. Use SSL/TLS for encryption
2. Implement SASL for authentication
3. Use separate networks for different security zones
4. Don't expose internal listeners externally

### Production Example
```env
# Secure production configuration
KAFKA_CFG_LISTENERS=INTERNAL://kafka:29092,EXTERNAL://0.0.0.0:9093
KAFKA_CFG_ADVERTISED_LISTENERS=INTERNAL://kafka:29092,EXTERNAL://broker.example.com:9093
KAFKA_CFG_LISTENER_SECURITY_PROTOCOL_MAP=INTERNAL:SASL_SSL,EXTERNAL:SSL
```

---

## Summary

- **Three listeners** serve different purposes:
  - `PLAINTEXT` (29092): Internal container communication
  - `CONTROLLER` (9093): KRaft consensus
  - `PLAINTEXT_HOST` (9092): Host machine access
- **Advertised listeners** tell clients how to connect
- **Security protocol map** defines encryption/authentication per listener
- **Proper configuration** ensures seamless communication across different network contexts
