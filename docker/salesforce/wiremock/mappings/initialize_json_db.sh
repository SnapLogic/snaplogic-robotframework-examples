#!/bin/bash

# Initialize JSON-DB with test data using POST actions
# Usage: ./initialize_json_db.sh

# Use Docker container name for inter-container communication
# Can be overridden by environment variable
BASE_URL="${SALESFORCE_MOCK_URL:-https://salesforce-api-mock:8443}"
TOKEN=""

# Disable SSL verification for self-signed certificates
CURL_OPTS="-k"  # -k flag disables SSL certificate verification

echo "========================================"
echo "Initializing Salesforce JSON-DB Test Data"
echo "========================================"
echo "Using URL: $BASE_URL"

# Step 1: Authenticate
echo "1. Authenticating..."
AUTH_RESPONSE=$(curl $CURL_OPTS -s -X POST "$BASE_URL/services/oauth2/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=password&username=test&password=test")

TOKEN=$(echo $AUTH_RESPONSE | grep -o '"access_token":"[^"]*' | cut -d'"' -f4)

if [ -z "$TOKEN" ]; then
  echo "❌ Authentication failed"
  exit 1
fi

echo "✓ Authenticated with token: ${TOKEN:0:20}..."

# Step 2: Function to create account
create_account() {
  local name="$1"
  local type="$2"
  local industry="$3"
  local revenue="$4"
  
  echo "Creating account: $name"
  
  RESPONSE=$(curl $CURL_OPTS -s -X POST "$BASE_URL/services/data/v59.0/sobjects/Account" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -d "{
      \"Name\": \"$name\",
      \"Type\": \"$type\",
      \"Industry\": \"$industry\",
      \"AnnualRevenue\": $revenue
    }")
  
  ACCOUNT_ID=$(echo $RESPONSE | grep -o '"id":"[^"]*' | cut -d'"' -f4)
  
  if [ ! -z "$ACCOUNT_ID" ]; then
    echo "  ✓ Created with ID: $ACCOUNT_ID"
    return 0
  else
    echo "  ✗ Failed to create account"
    echo "  Response: $RESPONSE"
    return 1
  fi
}

# Step 3: Clear existing accounts (optional)
clear_accounts() {
  echo "2. Clearing existing accounts..."
  
  # Query existing accounts
  ACCOUNTS=$(curl $CURL_OPTS -s -X GET "$BASE_URL/services/data/v59.0/query?q=SELECT+Id,Name+FROM+Account" \
    -H "Authorization: Bearer $TOKEN")
  
  # Parse account IDs (this is simplified - you might need jq for proper JSON parsing)
  ACCOUNT_IDS=$(echo $ACCOUNTS | grep -o '"Id":"[^"]*' | cut -d'"' -f4)
  
  if [ ! -z "$ACCOUNT_IDS" ]; then
    while IFS= read -r id; do
      echo "  Deleting account: $id"
      curl $CURL_OPTS -s -X DELETE "$BASE_URL/services/data/v59.0/sobjects/Account/$id" \
        -H "Authorization: Bearer $TOKEN"
      echo "  ✓ Deleted"
    done <<< "$ACCOUNT_IDS"
  else
    echo "  No existing accounts found"
  fi
}

# Optional: Clear existing data
# clear_accounts

# Step 4: Create initial test accounts
echo "3. Creating test accounts..."
create_account "Acme Corporation" "Customer" "Technology" 50000000
create_account "Global Innovations Inc" "Partner" "Manufacturing" 75000000
create_account "TechStart Solutions" "Prospect" "Software" 10000000

# Step 5: Verify initialization
echo ""
echo "4. Verifying initialization..."
VERIFY_RESPONSE=$(curl $CURL_OPTS -s -X GET "$BASE_URL/services/data/v59.0/query?q=SELECT+Name,Type+FROM+Account" \
  -H "Authorization: Bearer $TOKEN")

echo "Current accounts in JSON-DB:"
echo "$VERIFY_RESPONSE" | grep -o '"Name":"[^"]*' | cut -d'"' -f4 | while read name; do
  echo "  - $name"
done

echo ""
echo "✅ Test data initialization completed!"