"""
Robot Framework Library for Kafka Operations
"""
from kafka.admin import KafkaAdminClient, NewTopic
from kafka import KafkaProducer, KafkaConsumer
from kafka.errors import TopicAlreadyExistsError
import json
import time


class KafkaLibrary:
    """Robot Framework library for Kafka operations"""
    
    def __init__(self):
        self.admin_client = None
        self.producer = None
        self.consumer = None
        self.bootstrap_servers = None
    
    def connect_to_kafka(self, bootstrap_servers="localhost:9092", 
                        security_protocol="PLAINTEXT",
                        sasl_mechanism=None,
                        sasl_username=None,
                        sasl_password=None):
        """
        Connect to Kafka cluster
        
        Args:
            bootstrap_servers: Comma-separated list of broker addresses
            security_protocol: Security protocol (PLAINTEXT, SASL_SSL, etc.)
            sasl_mechanism: SASL mechanism (PLAIN, SCRAM-SHA-256, etc.)
            sasl_username: SASL username
            sasl_password: SASL password
        """
        self.bootstrap_servers = bootstrap_servers
        
        # Build config based on security settings
        config = {
            'bootstrap_servers': bootstrap_servers.split(','),
            'security_protocol': security_protocol
        }
        
        if security_protocol == "SASL_SSL" or security_protocol == "SASL_PLAINTEXT":
            config['sasl_mechanism'] = sasl_mechanism
            config['sasl_plain_username'] = sasl_username
            config['sasl_plain_password'] = sasl_password
        
        try:
            self.admin_client = KafkaAdminClient(**config)
            print(f"Connected to Kafka at {bootstrap_servers}")
            return True
        except Exception as e:
            raise Exception(f"Failed to connect to Kafka: {str(e)}")
    
    def create_topic(self, topic_name, num_partitions=1, replication_factor=1):
        """
        Create a Kafka topic
        
        Args:
            topic_name: Name of the topic
            num_partitions: Number of partitions
            replication_factor: Replication factor
        """
        if not self.admin_client:
            raise Exception("Not connected to Kafka. Call 'Connect To Kafka' first")
        
        topic = NewTopic(
            name=topic_name,
            num_partitions=int(num_partitions),
            replication_factor=int(replication_factor)
        )
        
        try:
            result = self.admin_client.create_topics([topic])
            # Wait for topic creation to complete
            time.sleep(2)
            print(f"Topic '{topic_name}' created successfully")
            return True
        except TopicAlreadyExistsError:
            print(f"Topic '{topic_name}' already exists")
            return True
        except Exception as e:
            raise Exception(f"Failed to create topic: {str(e)}")
    
    def delete_topic(self, topic_name):
        """Delete a Kafka topic"""
        if not self.admin_client:
            raise Exception("Not connected to Kafka. Call 'Connect To Kafka' first")
        
        try:
            result = self.admin_client.delete_topics([topic_name])
            print(f"Topic '{topic_name}' deleted successfully")
            return True
        except Exception as e:
            raise Exception(f"Failed to delete topic: {str(e)}")
    
    def list_topics(self):
        """List all topics in the Kafka cluster"""
        if not self.admin_client:
            raise Exception("Not connected to Kafka. Call 'Connect To Kafka' first")
        
        try:
            metadata = self.admin_client.list_topics()
            return list(metadata)
        except Exception as e:
            raise Exception(f"Failed to list topics: {str(e)}")
    
    def topic_exists(self, topic_name):
        """Check if a topic exists"""
        topics = self.list_topics()
        return topic_name in topics
    
    def send_message(self, topic_name, message, key=None):
        """
        Send a message to a Kafka topic
        
        Args:
            topic_name: Topic to send to
            message: Message content (string or dict)
            key: Optional message key
        """
        if not self.producer:
            self.producer = KafkaProducer(
                bootstrap_servers=self.bootstrap_servers.split(','),
                value_serializer=lambda v: json.dumps(v).encode('utf-8') if isinstance(v, dict) else str(v).encode('utf-8'),
                key_serializer=lambda k: k.encode('utf-8') if k else None
            )
        
        try:
            future = self.producer.send(topic_name, value=message, key=key)
            result = future.get(timeout=10)
            print(f"Message sent to topic '{topic_name}': {message}")
            return True
        except Exception as e:
            raise Exception(f"Failed to send message: {str(e)}")
    
    def consume_messages(self, topic_name, max_messages=1, timeout=5000):
        """
        Consume messages from a Kafka topic
        
        Args:
            topic_name: Topic to consume from
            max_messages: Maximum number of messages to consume
            timeout: Timeout in milliseconds
        """
        consumer = KafkaConsumer(
            topic_name,
            bootstrap_servers=self.bootstrap_servers.split(','),
            auto_offset_reset='earliest',
            enable_auto_commit=True,
            group_id='robot-test-group',
            value_deserializer=lambda m: m.decode('utf-8') if m else None,
            consumer_timeout_ms=timeout
        )
        
        messages = []
        try:
            for message in consumer:
                messages.append({
                    'topic': message.topic,
                    'partition': message.partition,
                    'offset': message.offset,
                    'key': message.key.decode('utf-8') if message.key else None,
                    'value': message.value
                })
                if len(messages) >= max_messages:
                    break
        finally:
            consumer.close()
        
        return messages
    
    def cleanup(self):
        """Clean up Kafka connections"""
        if self.admin_client:
            self.admin_client.close()
        if self.producer:
            self.producer.close()
        if self.consumer:
            self.consumer.close()
