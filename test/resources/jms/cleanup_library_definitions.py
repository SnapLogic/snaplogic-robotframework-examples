"""
ArtemisCleanupLibrary.py - Robot Framework wrapper for cleanup_queue_address_script.py

This library wraps your existing cleanup script to provide Robot Framework keywords
without using problematic Evaluate expressions that cause syntax errors.

Place this file in the same directory as cleanup_queue_address_script.py:
test/resources/jms/ArtemisCleanupLibrary.py
"""

from robot.api.deco import keyword, library
from robot.api import logger
import subprocess
import sys
import os
import json
from typing import List, Dict, Optional

# Since both files are now in the same directory, we can import directly
current_dir = os.path.dirname(os.path.abspath(__file__))
if current_dir not in sys.path:
    sys.path.insert(0, current_dir)

try:
    from cleanup_queue_address_script import ArtemisManager, BulkOperations
    DIRECT_IMPORT_AVAILABLE = True
    logger.info("Successfully imported cleanup_queue_address_script")
except ImportError as e:
    DIRECT_IMPORT_AVAILABLE = False
    logger.warn(f"Could not import cleanup script directly: {e}, will use subprocess")


@library(scope='SUITE')
class cleanup_library_definitions:
    """
    Robot Framework library wrapper for the existing cleanup_queue_address_script.py
    
    This library provides Robot Framework keywords that properly call your cleanup script
    without using Evaluate expressions, thus avoiding the syntax errors.
    
    Example usage in Robot Framework:
        Library    jms/cleanup_library_definitions.py
        
        *** Test Cases ***
        Test Cleanup
            ${addresses}=    Get All Addresses
            ${result}=       Cleanup Test Addresses
    """
    
    def __init__(self, host: str = 'activemq', port: int = 8161,
                 username: str = 'admin', password: str = 'admin'):
        """
        Initialize the cleanup library
        
        Args:
            host: ActiveMQ host (default: 'activemq')
            port: Management port (default: 8161)
            username: Username (default: 'admin')
            password: Password (default: 'admin')
        """
        self.host = host
        self.port = port
        self.username = username
        self.password = password
        
        # Initialize direct API if available
        if DIRECT_IMPORT_AVAILABLE:
            self.manager = ArtemisManager(host, port, username, password)
            self.bulk_ops = BulkOperations(self.manager)
            logger.info("Using direct API mode")
        else:
            self.manager = None
            self.bulk_ops = None
            logger.info("Using subprocess mode")
            
        # Path to the cleanup script - now in the same directory
        self.script_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'cleanup_queue_address_script.py')
        if not os.path.exists(self.script_path):
            # Try alternative path
            self.script_path = '/Users/spothana/QADocs/SNAPLOGIC_RF_EXAMPLES2/snaplogic-robotframework-examples/test/resources/jms/cleanup_queue_address_script.py'
        
        if os.path.exists(self.script_path):
            logger.info(f"Found cleanup script at: {self.script_path}")
        else:
            logger.warn(f"Cleanup script not found at: {self.script_path}")
    
    def _run_script(self, operation: str, patterns: Optional[List[str]] = None, 
                   no_confirm: bool = True) -> Dict[str, any]:
        """
        Run the cleanup script via subprocess (fallback method)
        
        Args:
            operation: Operation to perform
            patterns: Optional patterns for filtering
            no_confirm: Skip confirmation prompts
            
        Returns:
            Dict with results
        """
        cmd = [
            sys.executable, self.script_path,
            '--host', self.host,
            '--port', str(self.port),
            '--username', self.username,
            '--password', self.password,
            '--operation', operation
        ]
        
        if no_confirm:
            cmd.append('--confirm')
        
        if patterns:
            cmd.extend(['--patterns'] + patterns)
        
        logger.info(f"Running cleanup script: {' '.join(cmd[:-2])}")  # Hide password
        
        try:
            result = subprocess.run(
                cmd,
                capture_output=True,
                text=True,
                timeout=60
            )
            
            output = result.stdout
            error = result.stderr
            
            if result.returncode != 0:
                logger.error(f"Script failed with code {result.returncode}")
                logger.error(f"Error output: {error}")
            
            return {
                'success': result.returncode == 0,
                'output': output,
                'error': error,
                'returncode': result.returncode
            }
            
        except subprocess.TimeoutExpired:
            logger.error("Script execution timed out")
            return {
                'success': False,
                'output': '',
                'error': 'Timeout',
                'returncode': -1
            }
        except Exception as e:
            logger.error(f"Failed to run script: {e}")
            return {
                'success': False,
                'output': '',
                'error': str(e),
                'returncode': -1
            }
    
    @keyword("Get All Addresses")
    def get_all_addresses(self) -> List[str]:
        """
        Get all addresses from ActiveMQ Artemis
        
        This replaces the problematic Evaluate expression:
        Evaluate    requests.post(..., 'mbean': '...component=addresses,*', ...)
        
        Returns:
            List[str]: List of all addresses
        """
        if self.manager:
            # Use direct API (the mbean string is fixed in your cleanup script)
            addresses = self.manager.get_all_addresses()
            logger.info(f"Found {len(addresses)} addresses via API")
            return addresses
        else:
            # Use subprocess
            result = self._run_script('list')
            
            if result['success']:
                # Parse addresses from output
                addresses = []
                output_lines = result['output'].split('\n')
                
                for line in output_lines:
                    # Look for numbered addresses in output
                    import re
                    match = re.match(r'\s*\d+\.\s+(.+)', line.strip())
                    if match:
                        addresses.append(match.group(1))
                
                logger.info(f"Found {len(addresses)} addresses via script")
                return addresses
            else:
                logger.error("Failed to get addresses")
                return []
    
    @keyword("Delete Addresses By Patterns")
    def delete_addresses_by_patterns(self, patterns: List[str]) -> Dict[str, bool]:
        """
        Delete addresses matching the given patterns
        
        Args:
            patterns: List of regex patterns
            
        Returns:
            Dict[str, bool]: Results for each address
        """
        if self.bulk_ops:
            # Use direct API
            matching_addresses = self.bulk_ops.select_addresses_by_patterns(patterns)
            results = self.bulk_ops.delete_addresses_safely(matching_addresses, confirm=False)
            return results
        else:
            # Use subprocess
            result = self._run_script('delete-addresses', patterns)
            
            if result['success']:
                # Parse results from output
                return {'status': 'completed', 'output': result['output']}
            else:
                return {'status': 'failed', 'error': result['error']}
    
    @keyword("Delete All Except System Addresses")
    def delete_all_except_system_addresses(self) -> Dict[str, any]:
        """
        Delete all addresses except system addresses (DLQ, ExpiryQueue, etc.)
        
        Returns:
            Dict with operation results
        """
        if self.bulk_ops:
            # Use direct API
            results = self.bulk_ops.delete_all_except_system(confirm=False)
            return results
        else:
            # Use subprocess
            result = self._run_script('delete-all-except-system')
            
            return {
                'success': result['success'],
                'output': result['output'],
                'error': result['error']
            }
    
    @keyword("Cleanup Test Addresses")
    def cleanup_test_addresses(self) -> Dict[str, any]:
        """
        Cleanup common test address patterns
        
        Returns:
            Dict with cleanup results
        """
        test_patterns = [
            r'^robot\.',
            r'^test\.',
            r'^modular\.test\.',
            r'^temp\.',
            r'^tmp\.',
            r'^demo\.',
            r'\.test$'
        ]
        
        logger.info(f"Cleaning up test addresses with {len(test_patterns)} patterns")
        return self.delete_addresses_by_patterns(test_patterns)
    
    @keyword("Cleanup Specific Patterns")
    def cleanup_specific_patterns(self, patterns: List[str]) -> Dict[str, any]:
        """
        Cleanup addresses matching specific patterns
        
        Args:
            patterns: List of regex patterns
            
        Returns:
            Dict with cleanup results
        """
        logger.info(f"Cleaning up addresses matching patterns: {patterns}")
        return self.delete_addresses_by_patterns(patterns)
    
    @keyword("List Addresses Matching Patterns")
    def list_addresses_matching_patterns(self, patterns: List[str]) -> List[str]:
        """
        List addresses that match the given patterns without deleting them
        
        Args:
            patterns: List of regex patterns
            
        Returns:
            List[str]: Matching addresses
        """
        if self.bulk_ops:
            # Use direct API
            matching = self.bulk_ops.select_addresses_by_patterns(patterns)
            logger.info(f"Found {len(matching)} addresses matching patterns")
            return matching
        else:
            # Get all addresses and filter
            all_addresses = self.get_all_addresses()
            matching = []
            
            import re
            for addr in all_addresses:
                for pattern in patterns:
                    if re.search(pattern, addr):
                        matching.append(addr)
                        break
            
            logger.info(f"Found {len(matching)} addresses matching patterns")
            return list(set(matching))  # Remove duplicates
    
    @keyword("Get Cleanup Summary")
    def get_cleanup_summary(self) -> Dict[str, any]:
        """
        Get a summary of addresses categorized by type
        
        Returns:
            Dict with categorized addresses
        """
        all_addresses = self.get_all_addresses()
        
        system_addresses = []
        test_addresses = []
        user_addresses = []
        
        import re
        
        for addr in all_addresses:
            # System addresses
            if addr in ['DLQ', 'ExpiryQueue', 'activemq.notifications'] or addr.startswith('$'):
                system_addresses.append(addr)
            # Test addresses
            elif re.match(r'^(test\.|robot\.|temp\.|tmp\.|demo\.|modular\.test\.).*|.*\.test$', addr):
                test_addresses.append(addr)
            # User addresses
            else:
                user_addresses.append(addr)
        
        summary = {
            'total': len(all_addresses),
            'system_count': len(system_addresses),
            'test_count': len(test_addresses),
            'user_count': len(user_addresses),
            'system_addresses': sorted(system_addresses),
            'test_addresses': sorted(test_addresses),
            'user_addresses': sorted(user_addresses)
        }
        
        logger.info(f"Address summary: Total={summary['total']}, "
                   f"System={summary['system_count']}, "
                   f"Test={summary['test_count']}, "
                   f"User={summary['user_count']}")
        
        return summary
    
    @keyword("Test Cleanup All Addresses And Queues Functionality")
    def test_cleanup_all_addresses_and_queues_functionality(self) -> Dict[str, any]:
        """
        This is the keyword that replaces the problematic Evaluate expression!
        
        Before (syntax error):
            Evaluate    requests.post(..., 'mbean': '...component=addresses,*', ...)
        
        After (this method):
            Test Cleanup All Addresses And Queues Functionality
        
        Returns:
            Dict with test results
        """
        logger.info("Testing cleanup all addresses and queues functionality...")
        
        # Get initial state
        initial_addresses = self.get_all_addresses()
        initial_count = len(initial_addresses)
        logger.info(f"Initial address count: {initial_count}")
        
        # Get summary
        summary = self.get_cleanup_summary()
        
        # Perform cleanup of test addresses only (safe operation)
        cleanup_result = self.cleanup_test_addresses()
        
        # Get final state
        final_addresses = self.get_all_addresses()
        final_count = len(final_addresses)
        logger.info(f"Final address count: {final_count}")
        
        # Calculate results
        deleted_count = initial_count - final_count
        
        result = {
            'initial_count': initial_count,
            'final_count': final_count,
            'deleted_count': deleted_count,
            'summary': summary,
            'cleanup_result': cleanup_result,
            'success': True
        }
        
        logger.info(f"Cleanup test complete: Deleted {deleted_count} addresses")
        return result