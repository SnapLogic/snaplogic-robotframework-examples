#!/usr/bin/env python3
"""
Standalone Kafka topic management script
Usage: python kafka_setup.py --env local --action create --topics topic1,topic2
"""
import argparse
from kafka.admin import KafkaAdminClient, NewTopic
from kafka.errors import TopicAlreadyExistsError
import sys

# Environment configurations
ENVIRONMENTS = {
    'local': {
        'bootstrap_servers': ['kafka:29092'],
        'security_protocol': 'PLAINTEXT'
    },
    'docker': {
        'bootstrap_servers': ['localhost:9092'],
        'security_protocol': 'PLAINTEXT'
    },
    'dev': {
        'bootstrap_servers': [
            'ckafka01.nia.snaplogic.com:9092',
            'ckafka02.nia.snaplogic.com:9092',
            'ckafka03.nia.snaplogic.com:9092'
        ],
        'security_protocol': 'PLAINTEXT'
    },
    'dev-sasl': {
        'bootstrap_servers': [
            'ckafka01.nia.snaplogic.com:9091',
            'ckafka02.nia.snaplogic.com:9091',
            'ckafka03.nia.snaplogic.com:9091'
        ],
        'security_protocol': 'SASL_SSL',
        'sasl_mechanism': 'PLAIN',
        'sasl_plain_username': 'admin',
        'sasl_plain_password': 'admin-secret'
    }
}

def create_topics(admin_client, topics, partitions=3, replication_factor=1):
    """Create Kafka topics"""
    new_topics = []
    for topic_name in topics:
        new_topics.append(NewTopic(
            name=topic_name,
            num_partitions=partitions,
            replication_factor=replication_factor
        ))
    
    try:
        result = admin_client.create_topics(new_topics)
        for topic in topics:
            print(f"✅ Created topic: {topic}")
    except TopicAlreadyExistsError as e:
        print(f"⚠️  Some topics already exist: {e}")
    except Exception as e:
        print(f"❌ Error creating topics: {e}")
        sys.exit(1)

def delete_topics(admin_client, topics):
    """Delete Kafka topics"""
    try:
        result = admin_client.delete_topics(topics)
        for topic in topics:
            print(f"✅ Deleted topic: {topic}")
    except Exception as e:
        print(f"❌ Error deleting topics: {e}")
        sys.exit(1)

def list_topics(admin_client):
    """List all Kafka topics"""
    try:
        topics = admin_client.list_topics()
        print("📋 Available topics:")
        for topic in sorted(topics):
            print(f"   - {topic}")
        return topics
    except Exception as e:
        print(f"❌ Error listing topics: {e}")
        sys.exit(1)

def main():
    parser = argparse.ArgumentParser(description='Kafka Topic Management')
    parser.add_argument('--env', choices=ENVIRONMENTS.keys(), default='local',
                       help='Environment to connect to')
    parser.add_argument('--action', choices=['create', 'delete', 'list'], required=True,
                       help='Action to perform')
    parser.add_argument('--topics', type=str,
                       help='Comma-separated list of topics')
    parser.add_argument('--partitions', type=int, default=3,
                       help='Number of partitions (for create)')
    parser.add_argument('--replication', type=int, default=1,
                       help='Replication factor (for create)')
    
    args = parser.parse_args()
    
    # Get environment config
    config = ENVIRONMENTS[args.env].copy()
    
    print(f"🔌 Connecting to {args.env} environment...")
    print(f"   Servers: {config['bootstrap_servers']}")
    
    try:
        admin_client = KafkaAdminClient(**config)
        print("✅ Connected successfully\n")
    except Exception as e:
        print(f"❌ Failed to connect: {e}")
        sys.exit(1)
    
    # Perform action
    if args.action == 'list':
        list_topics(admin_client)
    elif args.action == 'create':
        if not args.topics:
            print("❌ --topics required for create action")
            sys.exit(1)
        topics = [t.strip() for t in args.topics.split(',')]
        create_topics(admin_client, topics, args.partitions, args.replication)
    elif args.action == 'delete':
        if not args.topics:
            print("❌ --topics required for delete action")
            sys.exit(1)
        topics = [t.strip() for t in args.topics.split(',')]
        delete_topics(admin_client, topics)
    
    admin_client.close()
    print("\n✨ Done!")

if __name__ == '__main__':
    main()
