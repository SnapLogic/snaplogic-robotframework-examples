"""
Complete Robot Framework Kafka Library - Replacement for robotframework-kafkalibrary
Implements all keywords without dependency on external RF library
"""
from kafka.admin import KafkaAdminClient, NewTopic
from kafka.errors import TopicAlreadyExistsError, KafkaError
from kafka import KafkaConsumer, KafkaProducer, TopicPartition
from robot.api.deco import keyword, library
import time
import json


@library(scope='SUITE', version='2.0.0')
class KafkaLibraryCustom:
    """Complete Robot Framework library for Kafka operations - no external dependencies"""
    
    def __init__(self):
        self.admin_client = None
        self.consumer = None
        self.producer = None
        self.bootstrap_servers = None
    
    # ========== CONNECTION KEYWORDS ==========
    
    @keyword("Connect Consumer")
    def connect_consumer(self, bootstrap_servers="localhost:9092", group_id="robot-test-group",
                        client_id="robot", auto_offset_reset="earliest", 
                        enable_auto_commit=True, **kwargs):
        """Connect to Kafka as a consumer
        
        Examples:
        | Connect Consumer | kafka:29092 | test-group |
        | Connect Consumer | kafka:29092 | test-group | auto_offset_reset=latest |
        """
        if self.consumer:
            self.consumer.close()
        
        self.bootstrap_servers = bootstrap_servers
        self.consumer = KafkaConsumer(
            bootstrap_servers=bootstrap_servers.split(','),
            group_id=group_id,
            client_id=client_id,
            auto_offset_reset=auto_offset_reset,
            enable_auto_commit=enable_auto_commit,
            value_deserializer=lambda m: m.decode('utf-8') if m else None,
            key_deserializer=lambda m: m.decode('utf-8') if m else None,
            **kwargs
        )
        print(f"Consumer connected to {bootstrap_servers} with group {group_id}")
        return True
    
    @keyword("Connect Producer")
    def connect_producer(self, bootstrap_servers="localhost:9092", client_id="robot", **kwargs):
        """Connect to Kafka as a producer
        
        Examples:
        | Connect Producer | kafka:29092 |
        | Connect Producer | kafka:29092 | client_id=my-producer |
        """
        if self.producer:
            self.producer.close()
        
        self.bootstrap_servers = bootstrap_servers
        self.producer = KafkaProducer(
            bootstrap_servers=bootstrap_servers.split(','),
            client_id=client_id,
            value_serializer=lambda v: v.encode('utf-8') if isinstance(v, str) else json.dumps(v).encode('utf-8'),
            key_serializer=lambda k: k.encode('utf-8') if k else None,
            **kwargs
        )
        print(f"Producer connected to {bootstrap_servers}")
        return True
    
    @keyword("Connect To Kafka")
    def connect_to_kafka(self, bootstrap_servers="localhost:9092", **kwargs):
        """Legacy connection method - connects both producer and consumer
        
        Examples:
        | Connect To Kafka | kafka:29092 |
        """
        self.connect_consumer(bootstrap_servers, **kwargs)
        self.connect_producer(bootstrap_servers, **kwargs)
        return True
    
    @keyword("Close")
    def close(self):
        """Close all Kafka connections
        
        Examples:
        | Close |
        """
        if self.consumer:
            self.consumer.close()
            self.consumer = None
            print("Consumer closed")
        
        if self.producer:
            self.producer.close()
            self.producer = None
            print("Producer closed")
        
        if self.admin_client:
            self.admin_client.close()
            self.admin_client = None
            print("Admin client closed")
        
        return True
    
    # ========== PRODUCER KEYWORDS ==========
    
    @keyword("Send")
    def send(self, topic, key=None, message=None, partition=None, **kwargs):
        """Send a message to a Kafka topic
        
        Examples:
        | Send | test-topic | message=Hello World |
        | Send | test-topic | key1 | Hello World |
        | Send | test-topic | key=msg1 | message=Hello |
        """
        if not self.producer:
            raise Exception("Producer not connected. Call 'Connect Producer' first")
        
        # Handle different parameter combinations
        if message is None and key is not None and partition is None:
            # Two args: topic and message (no key)
            message = key
            key = None
        elif message is None and 'message' in kwargs:
            message = kwargs['message']
        
        future = self.producer.send(
            topic,
            value=message,
            key=key,
            partition=partition
        )
        result = future.get(timeout=10)
        print(f"Message sent to {topic}")
        return result
    
    @keyword("Flush")
    def flush(self, timeout=None):
        """Flush all pending messages in the producer
        
        Examples:
        | Flush |
        | Flush | timeout=5 |
        """
        if not self.producer:
            raise Exception("Producer not connected")
        
        self.producer.flush(timeout=timeout)
        print("Producer flushed")
        return True
    
    # ========== CONSUMER KEYWORDS ==========
    
    @keyword("Subscribe Topic")
    def subscribe_topic(self, *topics, **kwargs):
        """Subscribe to one or more Kafka topics
        
        Examples:
        | Subscribe Topic | test-topic |
        | Subscribe Topic | topic1 | topic2 | topic3 |
        """
        if not self.consumer:
            raise Exception("Consumer not connected. Call 'Connect Consumer' first")
        
        topics_list = list(topics)
        self.consumer.subscribe(topics_list, **kwargs)
        print(f"Subscribed to topics: {', '.join(topics_list)}")
        return True
    
    @keyword("Poll")
    def poll(self, max_records=1, timeout=10):
        """Poll for messages from subscribed topics
        
        Examples:
        | ${messages}= | Poll | 10 | 5 |
        | ${messages}= | Poll | max_records=5 | timeout=10 |
        """
        if not self.consumer:
            raise Exception("Consumer not connected")
        
        # Convert to proper types
        max_records = int(max_records) if max_records is not None else None
        timeout_ms = int(timeout) * 1000  # Convert seconds to milliseconds
        
        messages = self.consumer.poll(timeout_ms=timeout_ms, max_records=max_records)
        
        result = []
        for topic_partition, msgs in messages.items():
            for msg in msgs:
                result.append({
                    'topic': msg.topic,
                    'partition': msg.partition,
                    'offset': msg.offset,
                    'key': msg.key,
                    'value': msg.value,
                    'timestamp': msg.timestamp
                })
        return result
    
    @keyword("Commit")
    def commit(self, offsets=None):
        """Commit consumer offsets
        
        Examples:
        | Commit |
        | Commit | ${offsets} |
        """
        if not self.consumer:
            raise Exception("Consumer not connected")
        
        if not self.consumer._group_id:
            raise Exception("Requires group_id")
        
        self.consumer.commit(offsets=offsets)
        print("Offsets committed")
        return True
    
    @keyword("Committed")
    def committed(self, topic_partition):
        """Get the last committed offset for a partition
        
        Examples:
        | ${offset}= | Committed | ${topic_partition} |
        """
        if not self.consumer:
            raise Exception("Consumer not connected")
        
        return self.consumer.committed(topic_partition)
    
    # ========== PARTITION MANAGEMENT KEYWORDS ==========
    
    @keyword("Create Topicpartition")
    def create_topicpartition(self, topic, partition):
        """Create a TopicPartition object
        
        Examples:
        | ${tp}= | Create Topicpartition | test-topic | 0 |
        """
        return TopicPartition(topic, int(partition))
    
    @keyword("Assign To Topic Partition")
    def assign_to_topic_partition(self, *topic_partitions):
        """Manually assign topic partitions to consumer
        
        Examples:
        | ${tp}= | Create Topicpartition | test-topic | 0 |
        | Assign To Topic Partition | ${tp} |
        """
        if not self.consumer:
            raise Exception("Consumer not connected")
        
        self.consumer.assign(list(topic_partitions))
        print(f"Assigned to {len(topic_partitions)} partition(s)")
        return True
    
    @keyword("Get Assigned Partitions")
    def get_assigned_partitions(self):
        """Get list of currently assigned partitions
        
        Examples:
        | ${partitions}= | Get Assigned Partitions |
        """
        if not self.consumer:
            raise Exception("Consumer not connected")
        
        return list(self.consumer.assignment())
    
    @keyword("Get Kafka Partitions For Topic")
    def get_kafka_partitions_for_topic(self, topic):
        """Get all partitions for a specific topic
        
        Examples:
        | ${partitions}= | Get Kafka Partitions For Topic | test-topic |
        """
        if not self.consumer:
            raise Exception("Consumer not connected")
        
        partitions = self.consumer.partitions_for_topic(topic)
        return list(partitions) if partitions else []
    
    # ========== OFFSET MANAGEMENT KEYWORDS ==========
    
    @keyword("Seek")
    def seek(self, topic_partition, offset):
        """Seek to a specific offset in a partition
        
        Examples:
        | ${tp}= | Create Topicpartition | test-topic | 0 |
        | Seek | ${tp} | 100 |
        """
        if not self.consumer:
            raise Exception("Consumer not connected")
        
        self.consumer.seek(topic_partition, int(offset))
        print(f"Seeked to offset {offset}")
        return True
    
    @keyword("Seek To Beginning")
    def seek_to_beginning(self, *topic_partitions):
        """Seek to the beginning of partitions
        
        Examples:
        | ${tp}= | Create Topicpartition | test-topic | 0 |
        | Seek To Beginning | ${tp} |
        """
        if not self.consumer:
            raise Exception("Consumer not connected")
        
        partitions = topic_partitions if topic_partitions else None
        self.consumer.seek_to_beginning(partitions)
        print("Seeked to beginning")
        return True
    
    @keyword("Seek To End")
    def seek_to_end(self, *topic_partitions):
        """Seek to the end of partitions
        
        Examples:
        | ${tp}= | Create Topicpartition | test-topic | 0 |
        | Seek To End | ${tp} |
        """
        if not self.consumer:
            raise Exception("Consumer not connected")
        
        partitions = topic_partitions if topic_partitions else None
        self.consumer.seek_to_end(partitions)
        print("Seeked to end")
        return True
    
    @keyword("Get Position")
    def get_position(self, topic_partition):
        """Get current position in a partition
        
        Examples:
        | ${tp}= | Create Topicpartition | test-topic | 0 |
        | ${position}= | Get Position | ${tp} |
        """
        if not self.consumer:
            raise Exception("Consumer not connected")
        
        return self.consumer.position(topic_partition)
    
    # ========== TOPIC INFORMATION KEYWORDS ==========
    
    @keyword("Get Kafka Topics")
    def get_kafka_topics(self):
        """Get list of all Kafka topics
        
        Examples:
        | ${topics}= | Get Kafka Topics |
        """
        if self.consumer:
            return list(self.consumer.topics())
        elif self.admin_client:
            return list(self.admin_client.list_topics())
        else:
            # Create temporary consumer to get topics
            temp_consumer = KafkaConsumer(
                bootstrap_servers=self.bootstrap_servers.split(',') if self.bootstrap_servers else ['localhost:9092']
            )
            topics = list(temp_consumer.topics())
            temp_consumer.close()
            return topics
    
    @keyword("Get Number Of Messages In Topics")
    def get_number_of_messages_in_topics(self, *topics):
        """Get total number of messages in topics
        
        Examples:
        | ${count}= | Get Number Of Messages In Topics | topic1 | topic2 |
        """
        if not self.consumer:
            raise Exception("Consumer not connected")
        
        total = 0
        for topic in topics:
            partitions = self.consumer.partitions_for_topic(topic)
            if partitions:
                for partition in partitions:
                    tp = TopicPartition(topic, partition)
                    self.consumer.assign([tp])
                    self.consumer.seek_to_beginning(tp)
                    start = self.consumer.position(tp)
                    self.consumer.seek_to_end(tp)
                    end = self.consumer.position(tp)
                    total += (end - start)
        
        return total
    
    @keyword("Get Number Of Messages In Topicpartition")  
    def get_number_of_messages_in_topicpartition(self, topic_partition):
        """Get number of messages in a specific partition
        
        Examples:
        | ${tp}= | Create Topicpartition | test-topic | 0 |
        | ${count}= | Get Number Of Messages In Topicpartition | ${tp} |
        """
        if not self.consumer:
            raise Exception("Consumer not connected")
        
        self.consumer.assign([topic_partition])
        self.consumer.seek_to_beginning(topic_partition)
        start = self.consumer.position(topic_partition)
        self.consumer.seek_to_end(topic_partition)
        end = self.consumer.position(topic_partition)
        
        return end - start
    
    # ========== ADMIN OPERATIONS (BONUS) ==========
    
    @keyword("Connect To Kafka Admin")
    def connect_to_kafka_admin(self, bootstrap_servers="localhost:9092", **kwargs):
        """Connect to Kafka as admin for topic management
        
        Examples:
        | Connect To Kafka Admin | kafka:29092 |
        """
        self.bootstrap_servers = bootstrap_servers
        self.admin_client = KafkaAdminClient(
            bootstrap_servers=bootstrap_servers.split(','),
            **kwargs
        )
        print(f"Admin client connected to {bootstrap_servers}")
        return True
    
    @keyword("Create Topic")
    def create_topic(self, topic_name, num_partitions=1, replication_factor=1):
        """Create a Kafka topic
        
        Examples:
        | Create Topic | test-topic |
        | Create Topic | test-topic | num_partitions=3 |
        """
        if not self.admin_client:
            self.connect_to_kafka_admin(self.bootstrap_servers or "localhost:9092")
        
        topic = NewTopic(
            name=topic_name,
            num_partitions=int(num_partitions),
            replication_factor=int(replication_factor)
        )
        
        try:
            self.admin_client.create_topics([topic])
            time.sleep(2)
            print(f"Topic '{topic_name}' created")
            return True
        except TopicAlreadyExistsError:
            print(f"Topic '{topic_name}' already exists")
            return True
    
    @keyword("Delete Topic")
    def delete_topic(self, topic_name):
        """Delete a Kafka topic
        
        Examples:
        | Delete Topic | test-topic |
        """
        if not self.admin_client:
            self.connect_to_kafka_admin(self.bootstrap_servers or "localhost:9092")
        
        try:
            self.admin_client.delete_topics([topic_name])
            print(f"Topic '{topic_name}' deleted")
            return True
        except Exception as e:
            raise Exception(f"Failed to delete topic: {str(e)}")
    
    @keyword("Delete Topics")
    def delete_topics(self, *topic_names):
        """Delete multiple Kafka topics
        
        Examples:
        | Delete Topics | topic1 | topic2 | topic3 |
        """
        if not self.admin_client:
            self.connect_to_kafka_admin(self.bootstrap_servers or "localhost:9092")
        
        topics_list = list(topic_names)
        self.admin_client.delete_topics(topics_list)
        print(f"Deleted {len(topics_list)} topics")
        return True
