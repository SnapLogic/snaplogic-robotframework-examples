#!/bin/bash
# Kafka topics management script

# Set Kafka bootstrap server
KAFKA_BOOTSTRAP_SERVER="${KAFKA_BOOTSTRAP_SERVER:-localhost:9092}"

# Function to create a topic
create_topic() {
    local TOPIC_NAME=$1
    local PARTITIONS=${2:-3}
    local REPLICATION=${3:-1}
    
    echo "Creating topic: $TOPIC_NAME with $PARTITIONS partitions..."
    docker exec snaplogic-kafka-kraft kafka-topics.sh \
        --bootstrap-server $KAFKA_BOOTSTRAP_SERVER \
        --create \
        --if-not-exists \
        --topic $TOPIC_NAME \
        --partitions $PARTITIONS \
        --replication-factor $REPLICATION
}

# Function to list topics
list_topics() {
    echo "Listing all topics..."
    docker exec snaplogic-kafka-kraft kafka-topics.sh \
        --bootstrap-server $KAFKA_BOOTSTRAP_SERVER \
        --list
}

# Function to describe a topic
describe_topic() {
    local TOPIC_NAME=$1
    echo "Describing topic: $TOPIC_NAME"
    docker exec snaplogic-kafka-kraft kafka-topics.sh \
        --bootstrap-server $KAFKA_BOOTSTRAP_SERVER \
        --describe \
        --topic $TOPIC_NAME
}

# Function to delete a topic
delete_topic() {
    local TOPIC_NAME=$1
    echo "Deleting topic: $TOPIC_NAME"
    docker exec snaplogic-kafka-kraft kafka-topics.sh \
        --bootstrap-server $KAFKA_BOOTSTRAP_SERVER \
        --delete \
        --topic $TOPIC_NAME
}

# Parse command line arguments
case "$1" in
    create)
        create_topic $2 $3 $4
        ;;
    list)
        list_topics
        ;;
    describe)
        describe_topic $2
        ;;
    delete)
        delete_topic $2
        ;;
    *)
        echo "Usage: $0 {create|list|describe|delete} [topic-name] [partitions] [replication-factor]"
        echo "Examples:"
        echo "  $0 create my-topic 3 1"
        echo "  $0 list"
        echo "  $0 describe my-topic"
        echo "  $0 delete my-topic"
        exit 1
        ;;
esac
