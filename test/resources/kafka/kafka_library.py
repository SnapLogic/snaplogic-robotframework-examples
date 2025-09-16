"""
Robot Framework Library for Kafka Admin Operations
This library provides Kafka admin operations that aren't available in robotframework-kafkalibrary
"""
from kafka.admin import KafkaAdminClient, NewTopic
from kafka.errors import TopicAlreadyExistsError
import time


class KafkaLibrary:
    """Robot Framework library for Kafka admin operations"""
    
    def __init__(self):
        self.admin_client = None
        self.bootstrap_servers = None
    
    def connect_to_kafka_admin(self, bootstrap_servers="localhost:9092", 
                              security_protocol="PLAINTEXT",
                              sasl_mechanism=None,
                              sasl_username=None,
                              sasl_password=None):
        """
        Connect to Kafka cluster as admin
        
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
            print(f"Connected to Kafka admin at {bootstrap_servers}")
            return True
        except Exception as e:
            raise Exception(f"Failed to connect to Kafka admin: {str(e)}")
    
    def create_topic(self, topic_name, num_partitions=1, replication_factor=1):
        """
        Create a Kafka topic
        
        Args:
            topic_name: Name of the topic
            num_partitions: Number of partitions
            replication_factor: Replication factor
        """
        if not self.admin_client:
            raise Exception("Not connected to Kafka. Call 'Connect To Kafka Admin' first")
        
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
            raise Exception("Not connected to Kafka. Call 'Connect To Kafka Admin' first")
        
        try:
            result = self.admin_client.delete_topics([topic_name])
            print(f"Topic '{topic_name}' deleted successfully")
            return True
        except Exception as e:
            raise Exception(f"Failed to delete topic: {str(e)}")
    
    def delete_topics(self, *topic_names):
        """
        Delete multiple Kafka topics
        
        Args:
            *topic_names: Variable number of topic names to delete
        """
        if not self.admin_client:
            raise Exception("Not connected to Kafka. Call 'Connect To Kafka Admin' first")
        
        if not topic_names:
            raise ValueError("No topic names provided")
        
        try:
            # Convert single string or list to list
            topics_list = []
            for item in topic_names:
                if isinstance(item, list):
                    topics_list.extend(item)
                else:
                    topics_list.append(item)
            
            result = self.admin_client.delete_topics(topics_list)
            print(f"Successfully deleted {len(topics_list)} topics: {', '.join(topics_list)}")
            return True
        except Exception as e:
            raise Exception(f"Failed to delete topics: {str(e)}")
    
    def list_topics(self):
        """List all topics in the Kafka cluster"""
        if not self.admin_client:
            raise Exception("Not connected to Kafka. Call 'Connect To Kafka Admin' first")
        
        try:
            metadata = self.admin_client.list_topics()
            return list(metadata)
        except Exception as e:
            raise Exception(f"Failed to list topics: {str(e)}")
    
    def topic_exists(self, topic_name):
        """Check if a topic exists"""
        topics = self.list_topics()
        return topic_name in topics
    
    def cleanup_admin(self):
        """Clean up Kafka admin connection"""
        if self.admin_client:
            self.admin_client.close()
            self.admin_client = None
            print("Kafka admin connection closed")
