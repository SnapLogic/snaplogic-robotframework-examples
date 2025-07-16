#!/bin/bash

# Start Salesforce mock services
echo "Starting Salesforce API mock services..."

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    echo "Docker is not running. Please start Docker first."
    exit 1
fi

# Navigate to the parent directory (wip)
cd "$(dirname "$0")/.."

# Start services with Salesforce configuration
export OPENAPI_SPEC="salesforce/salesforce-openapi.yaml"
export JSON_DB="salesforce/salesforce-db.json"
export MOCKOON_ENV="salesforce-env.json"

docker-compose -f docker-compose-api-mocks.yml up -d prism-mock wiremock json-server mockoon

# Wait for services to be healthy
echo "Waiting for services to be ready..."
sleep 5

# Test endpoints
echo "Testing mock endpoints..."

# Test Prism
echo -n "Prism (OpenAPI mock): "
curl -s http://localhost:8080/services/data/v59.0 > /dev/null 2>&1 && echo "✓ Ready" || echo "✗ Not ready"

# Test WireMock
echo -n "WireMock: "
curl -s http://localhost:8081/__admin/ > /dev/null 2>&1 && echo "✓ Ready" || echo "✗ Not ready"

# Test JSON Server
echo -n "JSON Server: "
curl -s http://localhost:8082/accounts > /dev/null 2>&1 && echo "✓ Ready" || echo "✗ Not ready"

echo ""
echo "Salesforce mock services are running!"
echo ""
echo "Available endpoints:"
echo "  - Prism Mock: http://localhost:8080"
echo "  - WireMock: http://localhost:8081"
echo "  - JSON Server: http://localhost:8082"
echo "  - Mockoon: http://localhost:8083"
echo ""
echo "To stop services: docker-compose -f docker-compose-api-mocks.yml down"
