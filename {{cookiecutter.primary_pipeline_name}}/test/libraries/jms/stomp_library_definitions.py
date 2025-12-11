"""
Enhanced ActiveMQ Artemis STOMP Library for Robot Framework
Provides comprehensive producer/consumer functionality with validation and error handling
"""

import stomp
import time
import json
import threading
import queue
from datetime import datetime, timedelta
from typing import List, Dict, Any, Optional, Callable
from dataclasses import dataclass
import statistics
import uuid


@dataclass
class ConsumedMessage:
    """Data class for consumed messages"""
    message_id: str
    destination: str
    body: str
    headers: Dict[str, str]
    timestamp: datetime
    processing_time: float = 0.0


@dataclass
class PerformanceMetrics:
    """Data class for performance metrics"""
    total_messages: int
    duration: float
    throughput: float
    avg_latency: float
    min_latency: float
    max_latency: float
    latencies: List[float]


class ArtemisSTOMPListener(stomp.ConnectionListener):
    """STOMP listener for consuming messages"""
    
    def __init__(self, callback: Callable = None):
        self.messages = queue.Queue()
        self.callback = callback
        self.connection_lost = False
        self.error_messages = []
        
    def on_message(self, frame):
        """Handle incoming messages"""
        start_time = time.time()
        
        consumed_msg = ConsumedMessage(
            message_id=frame.headers.get('message-id', 'unknown'),
            destination=frame.headers.get('destination', 'unknown'),
            body=frame.body,
            headers=dict(frame.headers),
            timestamp=datetime.now(),
            processing_time=0.0
        )
        
        if self.callback:
            try:
                self.callback(consumed_msg)
            except Exception as e:
                print(f"Callback error: {e}")
        
        consumed_msg.processing_time = time.time() - start_time
        self.messages.put(consumed_msg)
    
    def on_error(self, frame):
        """Handle STOMP errors"""
        error_msg = f"STOMP Error: {frame.body}"
        self.error_messages.append(error_msg)
        print(error_msg)
    
    def on_disconnected(self):
        """Handle disconnection"""
        self.connection_lost = True
        print("STOMP connection lost")
    
    def get_messages(self, timeout: float = 1.0) -> List[ConsumedMessage]:
        """Get all messages from queue"""
        messages = []
        start_time = time.time()
        
        while time.time() - start_time < timeout:
            try:
                msg = self.messages.get(timeout=0.1)
                messages.append(msg)
            except queue.Empty:
                continue
        
        return messages
    
    def wait_for_messages(self, expected_count: int, timeout: float = 10.0) -> List[ConsumedMessage]:
        """Wait for specific number of messages"""
        messages = []
        start_time = time.time()
        
        while len(messages) < expected_count and time.time() - start_time < timeout:
            try:
                msg = self.messages.get(timeout=0.5)
                messages.append(msg)
            except queue.Empty:
                continue
        
        return messages


class ArtemisSTOMPManager:
    """Enhanced STOMP connection manager with consumer support"""
    
    def __init__(self, host: str = 'activemq', port: int = 61613, 
                 username: str = 'admin', password: str = 'admin'):
        """
        Initialize enhanced STOMP connection manager
        
        Args:
            host: ActiveMQ host (default: 'activemq')
            port: STOMP port (default: 61613) 
            username: Username (default: 'admin')
            password: Password (default: 'admin')
        """
        self.host = host
        self.port = port
        self.username = username
        self.password = password
        self.connection = None
        self.is_connected = False
        self.listener = None
        self.subscriptions = {}
        self.performance_data = []
    
    def connect(self, auto_retry: bool = True, max_retries: int = 3) -> bool:
        """
        Establish STOMP connection with retry logic
        
        Args:
            auto_retry: Enable automatic retry on failure
            max_retries: Maximum number of retry attempts
            
        Returns:
            bool: True if connected successfully, False otherwise
        """
        for attempt in range(max_retries + 1):
            try:
                self.connection = stomp.Connection(
                    [(self.host, self.port)],
                    heartbeats=(4000, 4000),  # Enable heartbeats
                    keepalive=True
                )
                
                # Add listener for consuming messages
                self.listener = ArtemisSTOMPListener()
                self.connection.set_listener('artemis-listener', self.listener)
                
                self.connection.connect(self.username, self.password, wait=True)
                self.is_connected = True
                return True
                
            except Exception as e:
                self.is_connected = False
                if attempt < max_retries and auto_retry:
                    print(f"Connection attempt {attempt + 1} failed: {e}. Retrying...")
                    time.sleep(2 ** attempt)  # Exponential backoff
                else:
                    raise Exception(f"Failed to connect to STOMP after {max_retries + 1} attempts: {e}")
        
        return False
    
    def disconnect(self) -> None:
        """Disconnect from STOMP and cleanup subscriptions"""
        if self.connection and self.is_connected:
            # Unsubscribe from all destinations
            for sub_id in self.subscriptions.keys():
                try:
                    self.connection.unsubscribe(sub_id)
                except:
                    pass
            
            self.connection.disconnect()
            self.is_connected = False
            self.subscriptions.clear()
    
    def send_message(self, destination: str, message: str, 
                    message_id: str = None, **header_kwargs) -> bool:
        """
        Send a single message with performance tracking
        
        Args:
            destination: Destination (use create_destination() for address::queue format)
            message: Message content
            message_id: Optional message ID (auto-generated if not provided)
            **header_kwargs: Additional headers
            
        Returns:
            bool: True if sent successfully
        """
        if not self.is_connected:
            raise Exception("Not connected to STOMP. Call connect() first.")
        
        start_time = time.time()
        
        if message_id is None:
            message_id = f"msg-{int(time.time())}-{uuid.uuid4().hex[:8]}"
        
        headers = self.create_message_headers(message_id, **header_kwargs)
        
        try:
            self.connection.send(
                body=str(message),
                destination=destination,
                headers=headers
            )
            
            # Track performance
            send_time = time.time() - start_time
            self.performance_data.append({
                'operation': 'send',
                'duration': send_time,
                'timestamp': datetime.now(),
                'message_id': message_id,
                'destination': destination
            })
            
            return True
        except Exception as e:
            raise Exception(f"Failed to send message: {e}")
    
    def subscribe_to_queue(self, destination: str, subscription_id: str = None) -> str:
        """
        Subscribe to a queue for consuming messages
        
        Args:
            destination: Queue destination
            subscription_id: Optional subscription ID
            
        Returns:
            str: Subscription ID
        """
        if not self.is_connected:
            raise Exception("Not connected to STOMP. Call connect() first.")
        
        if subscription_id is None:
            subscription_id = f"sub-{uuid.uuid4().hex[:8]}"
        
        headers = {
            'ack': 'client-individual',  # Manual acknowledgment
            'id': subscription_id
        }
        
        self.connection.subscribe(destination, subscription_id, headers=headers)
        self.subscriptions[subscription_id] = destination
        
        return subscription_id
    
    def unsubscribe_from_queue(self, subscription_id: str) -> bool:
        """
        Unsubscribe from a queue
        
        Args:
            subscription_id: Subscription ID to unsubscribe
            
        Returns:
            bool: True if unsubscribed successfully
        """
        if subscription_id in self.subscriptions:
            try:
                self.connection.unsubscribe(subscription_id)
                del self.subscriptions[subscription_id]
                return True
            except Exception as e:
                print(f"Failed to unsubscribe: {e}")
                return False
        return False
    
    def consume_messages(self, timeout: float = 5.0) -> List[ConsumedMessage]:
        """
        Consume all available messages
        
        Args:
            timeout: Timeout for waiting for messages
            
        Returns:
            List[ConsumedMessage]: List of consumed messages
        """
        if not self.listener:
            raise Exception("No listener configured. Call connect() first.")
        
        return self.listener.get_messages(timeout)
    
    def wait_for_messages(self, expected_count: int, timeout: float = 10.0) -> List[ConsumedMessage]:
        """
        Wait for specific number of messages
        
        Args:
            expected_count: Expected number of messages
            timeout: Timeout for waiting
            
        Returns:
            List[ConsumedMessage]: List of consumed messages
        """
        if not self.listener:
            raise Exception("No listener configured. Call connect() first.")
        
        return self.listener.wait_for_messages(expected_count, timeout)
    
    def acknowledge_message(self, message: ConsumedMessage) -> bool:
        """
        Acknowledge a consumed message
        
        Args:
            message: ConsumedMessage to acknowledge
            
        Returns:
            bool: True if acknowledged successfully
        """
        try:
            self.connection.ack(message.message_id)
            return True
        except Exception as e:
            print(f"Failed to acknowledge message: {e}")
            return False
    
    def create_message_headers(self, message_id: str, **kwargs) -> Dict[str, str]:
        """Create standard message headers with enhanced reliability"""
        headers = {
            'persistent': 'true',
            'delivery-mode': '2',
            'JMSDeliveryMode': '2',
            'content-type': 'text/plain',
            'message-id': message_id,
            'timestamp': str(int(time.time())),
            'JMSTimestamp': str(int(time.time() * 1000)),
            'JMSMessageID': message_id,
            'priority': '4'  # Normal priority
        }
        headers.update(kwargs)
        return headers
    
    def create_destination(self, address_name: str, queue_name: str) -> str:
        """Create destination string using address::queue format"""
        return f"{address_name}::{queue_name}"
    
    def simulate_network_failure(self, duration: float = 5.0):
        """Simulate network failure for testing"""
        if self.is_connected:
            self.connection.disconnect()
            self.is_connected = False
            
            def reconnect():
                time.sleep(duration)
                try:
                    self.connect()
                except:
                    pass
            
            threading.Thread(target=reconnect, daemon=True).start()
    
    def get_performance_metrics(self, operation_type: str = None) -> PerformanceMetrics:
        """
        Get performance metrics for operations
        
        Args:
            operation_type: Filter by operation type (send/receive)
            
        Returns:
            PerformanceMetrics: Performance statistics
        """
        data = self.performance_data
        if operation_type:
            data = [d for d in data if d['operation'] == operation_type]
        
        if not data:
            return PerformanceMetrics(0, 0, 0, 0, 0, 0, [])
        
        durations = [d['duration'] for d in data]
        total_duration = max(d['timestamp'] for d in data) - min(d['timestamp'] for d in data)
        total_duration_seconds = total_duration.total_seconds() if total_duration.total_seconds() > 0 else 1
        
        return PerformanceMetrics(
            total_messages=len(data),
            duration=total_duration_seconds,
            throughput=len(data) / total_duration_seconds,
            avg_latency=statistics.mean(durations),
            min_latency=min(durations),
            max_latency=max(durations),
            latencies=durations
        )


class ArtemisMessageBuilder:
    """Helper class for building different types of messages"""
    
    @staticmethod
    def create_text_message(content: str, timestamp: bool = True) -> str:
        """Create a simple text message"""
        if timestamp:
            current_time = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
            return f"TEXT: {content} (sent at {current_time})"
        return f"TEXT: {content}"
    
    @staticmethod
    def create_json_message(data: Dict[str, Any], pretty: bool = True) -> str:
        """Create a JSON message"""
        if pretty:
            return json.dumps(data, indent=2)
        return json.dumps(data)
    
    @staticmethod
    def create_order_message(order_id: str, customer: str, 
                           amount: float, items: List[str] = None) -> str:
        """Create an order JSON message"""
        order_data = {
            "order_id": order_id,
            "customer": customer,
            "amount": amount,
            "currency": "USD",
            "timestamp": datetime.now().isoformat(),
            "status": "processing"
        }
        if items:
            order_data["items"] = items
        
        return ArtemisMessageBuilder.create_json_message(order_data)


class ArtemisTestUtilities:
    """Utility functions for testing"""
    
    @staticmethod
    def create_test_destinations(base_name: str, count: int) -> List[str]:
        """
        Create multiple test destinations
        
        Args:
            base_name: Base name for destinations
            count: Number of destinations to create
            
        Returns:
            List[str]: List of destination strings
        """
        destinations = []
        for i in range(1, count + 1):
            address = f"{base_name}.address.{i}"
            queue = f"{base_name}.queue.{i}"
            destinations.append(f"{address}::{queue}")
        return destinations
    
    @staticmethod
    def create_test_messages(message_type: str, count: int) -> List[str]:
        """
        Create multiple test messages
        
        Args:
            message_type: Type of messages to create
            count: Number of messages
            
        Returns:
            List[str]: List of test messages
        """
        messages = []
        current_time = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        
        for i in range(1, count + 1):
            if message_type.lower() == "text":
                messages.append(f"Test message {i} sent at {current_time}")
            elif message_type.lower() == "json":
                data = {
                    "test_id": i,
                    "timestamp": current_time,
                    "type": "automated_test",
                    "data": f"test_data_{i}"
                }
                messages.append(json.dumps(data, indent=2))
            elif message_type.lower() == "order":
                messages.append(ArtemisMessageBuilder.create_order_message(
                    f"ORD-{i:03d}", f"Customer {i}", 99.99 + i, 
                    [f"Item {i}A", f"Item {i}B"]
                ))
        
        return messages


class MessageValidator:
    """Utility class for validating messages and headers"""
    
    @staticmethod
    def validate_message_headers(message: ConsumedMessage, expected_headers: Dict[str, str]) -> Dict[str, bool]:
        """
        Validate message headers
        
        Args:
            message: ConsumedMessage to validate
            expected_headers: Expected header key-value pairs
            
        Returns:
            Dict[str, bool]: Validation results for each header
        """
        results = {}
        for header_key, expected_value in expected_headers.items():
            actual_value = message.headers.get(header_key)
            results[header_key] = actual_value == expected_value
        
        return results
    
    @staticmethod
    def validate_json_message(message: ConsumedMessage, expected_schema: Dict[str, type]) -> Dict[str, bool]:
        """
        Validate JSON message structure
        
        Args:
            message: ConsumedMessage to validate
            expected_schema: Expected JSON schema (field_name: type)
            
        Returns:
            Dict[str, bool]: Validation results for each field
        """
        results = {}
        
        try:
            json_data = json.loads(message.body)
        except json.JSONDecodeError:
            return {'json_valid': False}
        
        results['json_valid'] = True
        
        for field_name, expected_type in expected_schema.items():
            if field_name in json_data:
                actual_type = type(json_data[field_name])
                results[field_name] = actual_type == expected_type
            else:
                results[field_name] = False
        
        return results
    
    @staticmethod
    def validate_message_content(message: ConsumedMessage, pattern: str = None, 
                               contains: str = None, min_length: int = None) -> Dict[str, bool]:
        """
        Validate message content
        
        Args:
            message: ConsumedMessage to validate
            pattern: Regex pattern to match
            contains: String that should be contained
            min_length: Minimum message length
            
        Returns:
            Dict[str, bool]: Content validation results
        """
        results = {}
        
        if pattern:
            import re
            results['pattern_match'] = bool(re.search(pattern, message.body))
        
        if contains:
            results['contains_text'] = contains in message.body
        
        if min_length:
            results['min_length'] = len(message.body) >= min_length
        
        return results


class DeadLetterQueueManager:
    """Manager for Dead Letter Queue operations"""
    
    def __init__(self, stomp_manager: ArtemisSTOMPManager):
        self.stomp_manager = stomp_manager
        self.dlq_prefix = "DLQ."
    
    def create_dlq_destination(self, original_destination: str) -> str:
        """
        Create DLQ destination from original destination
        
        Args:
            original_destination: Original queue destination
            
        Returns:
            str: DLQ destination
        """
        if "::" in original_destination:
            address, queue = original_destination.split("::", 1)
            dlq_address = f"{self.dlq_prefix}{address}"
            dlq_queue = f"{self.dlq_prefix}{queue}"
            return f"{dlq_address}::{dlq_queue}"
        else:
            return f"{self.dlq_prefix}{original_destination}"
    
    def send_to_dlq(self, original_message: ConsumedMessage, failure_reason: str) -> bool:
        """
        Send message to Dead Letter Queue
        
        Args:
            original_message: Original failed message
            failure_reason: Reason for failure
            
        Returns:
            bool: True if sent to DLQ successfully
        """
        dlq_destination = self.create_dlq_destination(original_message.destination)
        
        dlq_headers = {
            'original-destination': original_message.destination,
            'original-message-id': original_message.message_id,
            'failure-reason': failure_reason,
            'failure-timestamp': datetime.now().isoformat(),
            'dlq-redelivery-count': '1'
        }
        
        return self.stomp_manager.send_message(
            dlq_destination, 
            original_message.body, 
            f"dlq-{original_message.message_id}",
            **dlq_headers
        )
    
    def process_dlq_messages(self, dlq_destination: str, 
                           retry_original: bool = False) -> List[ConsumedMessage]:
        """
        Process messages from Dead Letter Queue
        
        Args:
            dlq_destination: DLQ destination to process
            retry_original: Whether to retry sending to original destination
            
        Returns:
            List[ConsumedMessage]: Processed DLQ messages
        """
        # Subscribe to DLQ
        sub_id = self.stomp_manager.subscribe_to_queue(dlq_destination)
        
        try:
            # Consume DLQ messages
            dlq_messages = self.stomp_manager.consume_messages(timeout=5.0)
            
            if retry_original:
                for msg in dlq_messages:
                    original_dest = msg.headers.get('original-destination')
                    if original_dest:
                        # Retry sending to original destination
                        self.stomp_manager.send_message(
                            original_dest, 
                            msg.body,
                            f"retry-{msg.headers.get('original-message-id', 'unknown')}"
                        )
            
            return dlq_messages
            
        finally:
            self.stomp_manager.unsubscribe_from_queue(sub_id)


class PerformanceTester:
    """Performance testing utilities"""
    
    def __init__(self, stomp_manager: ArtemisSTOMPManager):
        self.stomp_manager = stomp_manager
    
    def throughput_test(self, destination: str, message_count: int, 
                       message_size: int = 1024) -> PerformanceMetrics:
        """
        Run throughput test
        
        Args:
            destination: Destination for test messages
            message_count: Number of messages to send
            message_size: Size of each message in bytes
            
        Returns:
            PerformanceMetrics: Test results
        """
        # Create test message of specified size
        test_message = "X" * message_size
        
        start_time = time.time()
        sent_count = 0
        latencies = []
        
        for i in range(message_count):
            msg_start = time.time()
            
            if self.stomp_manager.send_message(destination, test_message, f"perf-{i}"):
                sent_count += 1
            
            latencies.append(time.time() - msg_start)
        
        total_duration = time.time() - start_time
        
        return PerformanceMetrics(
            total_messages=sent_count,
            duration=total_duration,
            throughput=sent_count / total_duration if total_duration > 0 else 0,
            avg_latency=statistics.mean(latencies) if latencies else 0,
            min_latency=min(latencies) if latencies else 0,
            max_latency=max(latencies) if latencies else 0,
            latencies=latencies
        )
    
    def latency_test(self, destination: str, test_duration: float = 60.0) -> PerformanceMetrics:
        """
        Run latency test for specified duration
        
        Args:
            destination: Destination for test messages
            test_duration: Test duration in seconds
            
        Returns:
            PerformanceMetrics: Test results
        """
        start_time = time.time()
        sent_count = 0
        latencies = []
        
        while time.time() - start_time < test_duration:
            msg_start = time.time()
            
            if self.stomp_manager.send_message(destination, f"Latency test message {sent_count}"):
                sent_count += 1
            
            latencies.append(time.time() - msg_start)
            time.sleep(0.01)  # Small delay between messages
        
        total_duration = time.time() - start_time
        
        return PerformanceMetrics(
            total_messages=sent_count,
            duration=total_duration,
            throughput=sent_count / total_duration if total_duration > 0 else 0,
            avg_latency=statistics.mean(latencies) if latencies else 0,
            min_latency=min(latencies) if latencies else 0,
            max_latency=max(latencies) if latencies else 0,
            latencies=latencies
        )
    
    def end_to_end_latency_test(self, destination: str, message_count: int = 100) -> Dict[str, float]:
        """
        Test end-to-end latency (send -> receive)
        
        Args:
            destination: Destination for test
            message_count: Number of test messages
            
        Returns:
            Dict[str, float]: Latency statistics
        """
        # Subscribe to destination
        sub_id = self.stomp_manager.subscribe_to_queue(destination)
        
        latencies = []
        
        try:
            for i in range(message_count):
                send_start = time.time()
                message_id = f"e2e-{i}-{int(send_start * 1000)}"
                
                # Send message with timestamp
                test_message = json.dumps({
                    'test_id': i,
                    'send_timestamp': send_start,
                    'message_id': message_id
                })
                
                self.stomp_manager.send_message(destination, test_message, message_id)
                
                # Wait for message to be received
                received_messages = self.stomp_manager.wait_for_messages(1, timeout=5.0)
                
                if received_messages:
                    receive_time = time.time()
                    latency = receive_time - send_start
                    latencies.append(latency)
                
                time.sleep(0.1)  # Small delay between tests
        
        finally:
            self.stomp_manager.unsubscribe_from_queue(sub_id)
        
        if latencies:
            return {
                'avg_latency': statistics.mean(latencies),
                'min_latency': min(latencies),
                'max_latency': max(latencies),
                'median_latency': statistics.median(latencies),
                'p95_latency': sorted(latencies)[int(len(latencies) * 0.95)] if len(latencies) > 1 else latencies[0],
                'total_messages': len(latencies)
            }
        else:
            return {'error': 'No messages received for latency calculation'}


# Context manager for automatic connection handling
class ArtemisSTOMPConnection:
    """Enhanced context manager for STOMP connections"""
    
    def __init__(self, host: str = 'activemq', port: int = 61613,
                 username: str = 'admin', password: str = 'admin'):
        self.manager = ArtemisSTOMPManager(host, port, username, password)
        self.dlq_manager = DeadLetterQueueManager(self.manager)
        self.performance_tester = PerformanceTester(self.manager)
        self.validator = MessageValidator()
    
    def __enter__(self):
        self.manager.connect()
        return self
    
    def __exit__(self, exc_type, exc_val, exc_tb):
        self.manager.disconnect()
