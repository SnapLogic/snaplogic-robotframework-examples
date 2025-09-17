#!/usr/bin/env python3
"""
Initialize JSON-DB with test data using POST actions
Run this before your test suite
"""

import requests
import json
import sys
import os
import urllib3
from typing import Dict, List, Optional

# Disable SSL warnings for self-signed certificates
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

class SalesforceTestDataInitializer:
    def __init__(self, base_url: str = None):
        # Use Docker container name for inter-container communication
        # Or environment variable for flexibility
        self.base_url = base_url or os.getenv(
            'SALESFORCE_MOCK_URL', 
            'https://salesforce-api-mock:8443'
        )
        self.token = None
        self.instance_url = None
        # Disable SSL verification for self-signed certificates
        self.verify_ssl = False
        
    def authenticate(self) -> str:
        """Get OAuth token"""
        response = requests.post(
            f"{self.base_url}/services/oauth2/token",
            data={
                "grant_type": "password",
                "username": "test@example.com",
                "password": "test123"
            },
            verify=self.verify_ssl
        )
        
        if response.status_code == 200:
            auth_data = response.json()
            self.token = auth_data['access_token']
            self.instance_url = auth_data.get('instance_url', self.base_url)
            print(f"✓ Authenticated successfully with token: {self.token[:20]}...")
            print(f"  Using instance URL: {self.instance_url}")
            return self.token
        else:
            raise Exception(f"Authentication failed: {response.status_code}")
    
    def clear_existing_accounts(self) -> None:
        """Optional: Clear all existing accounts"""
        headers = {"Authorization": f"Bearer {self.token}"}
        
        # Query existing accounts
        response = requests.get(
            f"{self.base_url}/services/data/v59.0/query",
            params={"q": "SELECT Id, Name FROM Account"},
            headers=headers,
            verify=self.verify_ssl
        )
        
        if response.status_code == 200:
            accounts = response.json().get('records', [])
            print(f"Found {len(accounts)} existing accounts to clear")
            
            for account in accounts:
                delete_resp = requests.delete(
                    f"{self.base_url}/services/data/v59.0/sobjects/Account/{account['Id']}",
                    headers=headers,
                    verify=self.verify_ssl
                )
                if delete_resp.status_code == 204:
                    print(f"  ✓ Deleted: {account['Name']} ({account['Id']})")
                else:
                    print(f"  ✗ Failed to delete: {account['Name']}")
    
    def create_account(self, account_data: Dict) -> str:
        """Create a single account"""
        headers = {
            "Authorization": f"Bearer {self.token}",
            "Content-Type": "application/json"
        }
        
        response = requests.post(
            f"{self.base_url}/services/data/v59.0/sobjects/Account",
            json=account_data,
            headers=headers,
            verify=self.verify_ssl
        )
        
        if response.status_code == 201:
            account_id = response.json()['id']
            print(f"✓ Created account: {account_data['Name']} (ID: {account_id})")
            return account_id
        else:
            print(f"✗ Failed to create account: {account_data['Name']}")
            print(f"  Response: {response.text}")
            return None
    
    def initialize_test_accounts(self) -> List[str]:
        """Create the initial test accounts"""
        test_accounts = [
            {
                "Name": "Acme Corporation",
                "Type": "Customer",
                "Industry": "Technology",
                "AnnualRevenue": 50000000,
                "Phone": "(555) 123-4567",
                "Website": "https://www.acme-corp.com",
                "BillingCity": "San Francisco",
                "BillingState": "CA",
                "BillingCountry": "USA"
            },
            {
                "Name": "Global Innovations Inc",
                "Type": "Partner",
                "Industry": "Manufacturing",
                "AnnualRevenue": 75000000,
                "Phone": "(555) 987-6543",
                "Website": "https://www.globalinnovations.com",
                "BillingCity": "New York",
                "BillingState": "NY",
                "BillingCountry": "USA"
            },
            {
                "Name": "TechStart Solutions",
                "Type": "Prospect",
                "Industry": "Software",
                "AnnualRevenue": 10000000,
                "Phone": "(555) 555-5555",
                "Website": "https://www.techstart.io",
                "BillingCity": "Austin",
                "BillingState": "TX",
                "BillingCountry": "USA"
            }
        ]
        
        created_ids = []
        print("\nInitializing test accounts...")
        
        for account in test_accounts:
            account_id = self.create_account(account)
            if account_id:
                created_ids.append(account_id)
        
        return created_ids
    
    def verify_initialization(self) -> bool:
        """Verify accounts were created successfully"""
        headers = {"Authorization": f"Bearer {self.token}"}
        
        response = requests.get(
            f"{self.base_url}/services/data/v59.0/query",
            params={"q": "SELECT Id, Name, Type, Industry FROM Account ORDER BY Name"},
            headers=headers,
            verify=self.verify_ssl
        )
        
        if response.status_code == 200:
            accounts = response.json().get('records', [])
            print(f"\n✓ Verification: Found {len(accounts)} accounts in JSON-DB:")
            for acc in accounts:
                print(f"  - {acc['Name']} ({acc['Type']}) - {acc['Industry']}")
            return len(accounts) >= 3
        else:
            print(f"✗ Verification failed: {response.status_code}")
            return False
    
    def initialize_related_data(self, account_ids: List[str]) -> None:
        """Optional: Create related contacts and opportunities"""
        headers = {
            "Authorization": f"Bearer {self.token}",
            "Content-Type": "application/json"
        }
        
        # Create sample contacts
        contacts = [
            {"FirstName": "John", "LastName": "Doe", "AccountId": account_ids[0], "Email": "john@acme.com"},
            {"FirstName": "Jane", "LastName": "Smith", "AccountId": account_ids[1], "Email": "jane@global.com"}
        ]
        
        for contact in contacts:
            response = requests.post(
                f"{self.base_url}/services/data/v59.0/sobjects/Contact",
                json=contact,
                headers=headers,
                verify=self.verify_ssl
            )
            if response.status_code == 201:
                print(f"✓ Created contact: {contact['FirstName']} {contact['LastName']}")
        
        # Create sample opportunities
        opportunities = [
            {
                "Name": "Acme Big Deal",
                "AccountId": account_ids[0],
                "Amount": 100000,
                "StageName": "Prospecting",
                "CloseDate": "2024-12-31"
            }
        ]
        
        for opp in opportunities:
            response = requests.post(
                f"{self.base_url}/services/data/v59.0/sobjects/Opportunity",
                json=opp,
                headers=headers,
                verify=self.verify_ssl
            )
            if response.status_code == 201:
                print(f"✓ Created opportunity: {opp['Name']}")

def main():
    """Main initialization flow"""
    print("=" * 60)
    print("Salesforce JSON-DB Test Data Initializer")
    print("=" * 60)
    
    # Initialize the setup class
    # Can override URL via environment variable or command line
    base_url = None
    if len(sys.argv) > 1:
        base_url = sys.argv[1]
    
    initializer = SalesforceTestDataInitializer(base_url)
    print(f"Using Salesforce Mock URL: {initializer.base_url}")
    
    try:
        # Step 1: Authenticate
        initializer.authenticate()
        
        # Step 2: Clear existing data (optional)
        # Uncomment if you want to start fresh each time
        # initializer.clear_existing_accounts()
        
        # Step 3: Create initial accounts
        account_ids = initializer.initialize_test_accounts()
        
        # Step 4: Create related data (optional)
        # initializer.initialize_related_data(account_ids)
        
        # Step 5: Verify setup
        if initializer.verify_initialization():
            print("\n✅ Test data initialization completed successfully!")
            return 0
        else:
            print("\n❌ Test data initialization verification failed!")
            return 1
            
    except Exception as e:
        print(f"\n❌ Error during initialization: {str(e)}")
        return 1

if __name__ == "__main__":
    sys.exit(main())