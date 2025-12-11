#!/usr/bin/env python3
"""
Enhanced Artemis Manager with multiple pattern support and delete-all-except-system functionality
This version is integrated with the robot_stomp_wrapper and stomp_library_definitions modules
"""

import requests
import json
import re
import argparse
from typing import List, Dict, Tuple
import getpass
import sys
import os

# Add the current directory to Python path to import local modules
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

try:
    from stomp_library_definitions import ArtemisManagementClient
    INTEGRATED_MODE = True
except ImportError:
    INTEGRATED_MODE = False


class ArtemisManager:
    """Legacy ArtemisManager for backward compatibility"""
    
    def __init__(self, host='localhost', port=8161, username='admin', password='admin'):
        self.host = host
        self.port = port
        self.username = username
        self.password = password
        self.base_url = f"http://{host}:{port}/console/jolokia"
        self.session = requests.Session()
        self.session.auth = (username, password)
        
        # Try to use integrated management client if available
        if INTEGRATED_MODE:
            try:
                self.management_client = ArtemisManagementClient(host, port, username, password)
            except Exception:
                self.management_client = None
        else:
            self.management_client = None
        
    def get_all_addresses(self) -> List[str]:
        """Get addresses by extracting from Jolokia error messages"""
        if self.management_client:
            return self.management_client.get_all_addresses()
            
        try:
            request_data = {
                "type": "read",
                "mbean": "org.apache.activemq.artemis:broker=\"0.0.0.0\",component=addresses,*",
                "attribute": "*"
            }
            
            print(f"🔍 Fetching addresses using Jolokia READ...")
            response = self.session.post(self.base_url, json=request_data)
            print(f"📡 Response status: {response.status_code}")
            
            if response.status_code != 200:
                print(f"❌ HTTP Error: {response.text}")
                return []
            
            data = response.json()
            error_message = data.get('error', '')
            
            if error_message and 'address=' in error_message:
                print(f"📊 Extracting addresses from API response...")
                address_matches = re.findall(r'address="([^"]*)"', error_message)
                addresses = set()
                for addr in address_matches:
                    # Include all addresses, even system ones starting with $
                    addresses.add(addr)
                
                result = sorted(list(addresses))
                print(f"✅ Found {len(result)} unique addresses")
                
                if result:
                    print("📋 Addresses found:")
                    for i, addr in enumerate(result, 1):
                        print(f"   {i:2d}. {addr}")
                
                return result
            else:
                print("❌ Could not extract addresses from response")
                return []
            
        except Exception as e:
            print(f"❌ Error getting addresses: {e}")
            return []
    
    def delete_address(self, address: str) -> bool:
        """Delete an address using correct method signature"""
        if self.management_client:
            return self.management_client.delete_address(address, True)
            
        try:
            request_data = {
                "type": "exec",
                "mbean": f'org.apache.activemq.artemis:broker="0.0.0.0"',
                "operation": "deleteAddress(java.lang.String)",
                "arguments": [address]
            }
            
            response = self.session.post(self.base_url, json=request_data)
            
            if response.status_code == 200:
                data = response.json()
                
                if 'error' not in data:
                    return data.get('value', False)
                
                # If single-arg fails, try with force parameter
                print(f"      Trying force deletion...")
                request_data = {
                    "type": "exec",
                    "mbean": f'org.apache.activemq.artemis:broker="0.0.0.0"',
                    "operation": "deleteAddress(java.lang.String,boolean)",
                    "arguments": [address, True]  # force=True
                }
                
                response = self.session.post(self.base_url, json=request_data)
                
                if response.status_code == 200:
                    data = response.json()
                    
                    if 'error' in data:
                        error_msg = data['error']
                        print(f"      API Error: {error_msg}")
                        return False
                    
                    return data.get('value', False)
            
            return False
            
        except Exception as e:
            print(f"      Exception: {e}")
            return False


class BulkOperations:
    """Bulk operations for address management"""
    
    def __init__(self, manager: ArtemisManager):
        self.manager = manager
    
    def select_addresses_by_patterns(self, patterns: List[str]) -> List[str]:
        """Select addresses matching multiple patterns"""
        print(f"🔍 Searching for addresses matching {len(patterns)} pattern(s)")
        all_addresses = self.manager.get_all_addresses()
        
        matches = set()  # Use set to avoid duplicates
        
        for i, pattern in enumerate(patterns, 1):
            print(f"   [{i}/{len(patterns)}] Testing pattern: '{pattern}'")
            pattern_matches = [addr for addr in all_addresses if re.search(pattern, addr)]
            matches.update(pattern_matches)
            print(f"      📋 Found {len(pattern_matches)} matches")
            
            # Show first few matches for this pattern
            if pattern_matches:
                for addr in pattern_matches[:3]:
                    print(f"         - {addr}")
                if len(pattern_matches) > 3:
                    print(f"         ... and {len(pattern_matches) - 3} more")
        
        result = sorted(list(matches))
        print(f"\n🎯 Total unique addresses found: {len(result)}")
        
        if result:
            print("📋 All matching addresses:")
            for i, addr in enumerate(result, 1):
                print(f"   {i:2d}. {addr}")
        else:
            print(f"ℹ️  No addresses match any of the patterns")
            if all_addresses:
                print("💡 Available addresses (sample):")
                for addr in all_addresses[:5]:
                    print(f"   - {addr}")
                if len(all_addresses) > 5:
                    print(f"   ... and {len(all_addresses) - 5} more")
        
        return result
    
    def select_addresses_by_pattern(self, pattern: str) -> List[str]:
        """Select addresses matching a single pattern"""
        return self.select_addresses_by_patterns([pattern])
    
    def delete_all_except_system(self, confirm=True) -> Dict[str, bool]:
        """Delete all addresses except system addresses (DLQ, ExpiryQueue, $sys.mqtt.sessions)"""
        # System addresses to preserve
        SYSTEM_ADDRESSES = {
            'DLQ',
            'ExpiryQueue',
            '$sys.mqtt.sessions',
            'activemq.notifications'  # Also preserve this system address
        }
        
        # Get all addresses
        all_addresses = self.manager.get_all_addresses()
        
        # Filter out system addresses
        addresses_to_delete = []
        preserved_addresses = []
        
        for addr in all_addresses:
            # Check if it's a system address or starts with $
            if addr in SYSTEM_ADDRESSES or addr.startswith('$'):
                preserved_addresses.append(addr)
            else:
                addresses_to_delete.append(addr)
        
        print("\n🔍 Address Analysis:")
        print(f"   Total addresses found: {len(all_addresses)}")
        print(f"   System addresses to preserve: {len(preserved_addresses)}")
        print(f"   User addresses to delete: {len(addresses_to_delete)}")
        
        if preserved_addresses:
            print("\n🛡️  Preserving system addresses:")
            for addr in sorted(preserved_addresses):
                print(f"   ✓ {addr}")
        
        if not addresses_to_delete:
            print("\n✅ No user addresses to delete. Only system addresses exist.")
            return {}
        
        # Delete the non-system addresses
        return self.delete_addresses_safely(addresses_to_delete, confirm)
    
    def delete_addresses_safely(self, addresses: List[str], confirm=True) -> Dict[str, bool]:
        """Delete addresses safely"""
        results = {}
        
        if not addresses:
            print("❌ No addresses to delete")
            return results
        
        if confirm:
            print(f"\n📝 Deletion Summary:")
            print(f"   🎯 Addresses to delete: {len(addresses)}")
            
            print(f"\n📋 Addresses to be deleted:")
            for i, addr in enumerate(addresses, 1):
                print(f"   {i:2d}. {addr}")
            
            confirmation = input(f"\n❓ Delete {len(addresses)} addresses? (yes/no): ").lower()
            if confirmation != 'yes':
                print("❌ Operation cancelled.")
                return {}
        
        print(f"\n🗑️  Deleting {len(addresses)} addresses...")
        successful = 0
        failed = 0
        
        for i, address in enumerate(addresses, 1):
            print(f"  [{i:2d}/{len(addresses)}] 🗑️  {address}", end=" ... ")
            success = self.manager.delete_address(address)
            results[address] = success
            
            if success:
                print("✅")
                successful += 1
            else:
                print("❌")
                failed += 1
        
        print(f"\n📊 Final Results:")
        print(f"   Addresses: {successful:3d} ✅  {failed:3d} ❌")
        
        success_rate = (successful / len(addresses)) * 100 if addresses else 0
        print(f"   Success Rate: {success_rate:.1f}%")
        
        return results


def main():
    parser = argparse.ArgumentParser(
        description='ActiveMQ Artemis Bulk Management Tool (Enhanced)',
        epilog="""
Examples:
  # Single pattern
  %(prog)s --operation delete-addresses --pattern "xml.*"
  
  # Multiple patterns (comma-separated)
  %(prog)s --operation delete-addresses --pattern "xml.*,robot.*,test.*"
  
  # Multiple patterns (space-separated)
  %(prog)s --operation delete-addresses --patterns "xml.*" "robot.*" "test.*"
  
  # Complex patterns
  %(prog)s --operation delete-addresses --pattern "^(xml|robot)\\."
  %(prog)s --operation delete-addresses --patterns "xml.*" "^robot\\." ".*\\.address$"
  
  # Delete all except system addresses
  %(prog)s --operation delete-all-except-system
  
  # Use with Robot Framework library
  %(prog)s --operation test-integration
        """,
        formatter_class=argparse.RawDescriptionHelpFormatter
    )
    
    parser.add_argument('--host', default='localhost', help='Artemis host')
    parser.add_argument('--port', type=int, default=8161, help='Artemis web port')
    parser.add_argument('--username', default='admin', help='Username')
    parser.add_argument('--password', help='Password (will prompt if not provided)')
    parser.add_argument('--operation', choices=['list', 'delete-addresses', 'cleanup', 'delete-all-except-system', 'test-integration'], 
                       help='Operation to perform')
    parser.add_argument('--pattern', help='Pattern for selection (regex). Use comma-separated for multiple patterns')
    parser.add_argument('--patterns', nargs='+', help='Multiple patterns for selection (space-separated)')
    parser.add_argument('--confirm', action='store_true', help='Skip confirmation prompts')
    
    args = parser.parse_args()
    
    # Get password if not provided
    password = args.password or getpass.getpass("Password: ")
    
    # Check integration mode
    if args.operation == 'test-integration':
        print("🔧 Testing Integration with Robot Framework Library")
        print("=" * 50)
        
        if INTEGRATED_MODE:
            print("✅ Integration mode is ACTIVE")
            print("   - stomp_library_definitions module found")
            print("   - ArtemisManagementClient available")
            
            # Test creating management client
            try:
                test_client = ArtemisManagementClient(args.host, args.port, args.username, password)
                print("   - Successfully created ArtemisManagementClient")
                
                # Test getting addresses
                addresses = test_client.get_all_addresses()
                print(f"   - Retrieved {len(addresses)} addresses")
                
            except Exception as e:
                print(f"   ❌ Error testing integration: {e}")
        else:
            print("❌ Integration mode is INACTIVE")
            print("   - stomp_library_definitions module not found")
            print("   - Using standalone mode")
        
        # Test with robot framework if available
        try:
            from robot_stomp_wrapper import robot_stomp_wrapper
            print("\n✅ robot_stomp_wrapper is available")
            
            # Create instance
            wrapper = robot_stomp_wrapper(host=args.host, username=args.username, password=password)
            print("   - Successfully created robot_stomp_wrapper instance")
            
            # Check if management features are available
            info = wrapper.get_library_info()
            if 'queue_address_management' in info.get('available_features', []):
                print("   - Queue/Address management features are available")
            else:
                print("   - Queue/Address management features are NOT available")
                
        except ImportError:
            print("\n❌ robot_stomp_wrapper not available")
            print("   - Robot Framework library not found in path")
        except Exception as e:
            print(f"\n❌ Error testing Robot Framework integration: {e}")
        
        return
    
    # Initialize manager
    manager = ArtemisManager(args.host, args.port, args.username, password)
    bulk_ops = BulkOperations(manager)
    
    if args.operation == 'list':
        print("📋 Listing All Addresses:")
        print("=" * 50)
        manager.get_all_addresses()
    
    elif args.operation == 'delete-addresses':
        patterns = []
        
        # Handle multiple pattern input methods
        if args.patterns:
            patterns = args.patterns
            print(f"🎯 Using space-separated patterns: {patterns}")
        elif args.pattern:
            # Support comma-separated patterns in --pattern
            if ',' in args.pattern:
                patterns = [p.strip() for p in args.pattern.split(',')]
                print(f"🎯 Using comma-separated patterns: {patterns}")
            else:
                patterns = [args.pattern]
                print(f"🎯 Using single pattern: {patterns}")
        
        if patterns:
            addresses = bulk_ops.select_addresses_by_patterns(patterns)
            if addresses:
                bulk_ops.delete_addresses_safely(addresses, confirm=not args.confirm)
            else:
                print("❌ No addresses matched any of the patterns")
        else:
            print("❌ --pattern or --patterns is required for delete-addresses operation")
            print("\n💡 Examples:")
            print("   Single pattern:")
            print("     --pattern 'xml.*'")
            print("   Multiple patterns (comma-separated):")
            print("     --pattern 'xml.*,robot.*,test.*'")
            print("   Multiple patterns (space-separated):")
            print("     --patterns 'xml.*' 'robot.*' 'test.*'")
            print("   Complex patterns:")
            print("     --pattern '^(xml|robot)\\.'")
            print("     --patterns 'xml.*' '^robot\\.' '.*\\.address$'")
    
    elif args.operation == 'cleanup':
        print("🧹 Cleaning up test data...")
        test_patterns = [r'^robot\.', r'^test\.', r'^modular\.test\.']
        
        test_addresses = bulk_ops.select_addresses_by_patterns(test_patterns)
        if test_addresses:
            print(f"\n🎯 Found {len(test_addresses)} test addresses")
            bulk_ops.delete_addresses_safely(test_addresses, confirm=not args.confirm)
        else:
            print("✅ No test data found to cleanup")
    
    elif args.operation == 'delete-all-except-system':
        print("🗑️  Delete All Addresses Except System")
        print("=" * 50)
        print("This will delete ALL user-created addresses and queues,")
        print("preserving only system addresses:")
        print("  - DLQ")
        print("  - ExpiryQueue")
        print("  - $sys.mqtt.sessions")
        print("  - activemq.notifications")
        print("  - Any address starting with $")
        print("\n⚠️  This is a destructive operation!\n")
        
        bulk_ops.delete_all_except_system(confirm=not args.confirm)
    
    else:
        # Default: list addresses
        print("🔧 Default operation: listing addresses")
        manager.get_all_addresses()


if __name__ == "__main__":
    main()
