#!/bin/bash
# set_travis_permissions.sh
# Set permissions for SnapLogic test data directories after containers are running

echo "Setting permissions for SnapLogic test data directories..."

# Set permissions on groundplex container (where SnapLogic writes files)
docker exec -u root snaplogic-groundplex-container chmod -R 777 /opt/snaplogic/test_data 2>/dev/null || echo "Warning: Could not set permissions on groundplex container"

# Set permissions on tools container (where tests read files)  
docker exec -u root snaplogic-test-example-tools-container chmod -R 777 /app/test/suite/test_data 2>/dev/null || echo "Warning: Could not set permissions on tools container"

echo "Permission setup complete!"
