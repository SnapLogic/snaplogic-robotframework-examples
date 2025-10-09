#!/bin/sh
# MinIO (S3 Emulator) Setup Script
# This script runs after MinIO is healthy to configure buckets and users

echo 'Starting MinIO setup...'
sleep 5
set -x

# Configure MinIO client
mc alias set local http://minio:9000 minioadmin minioadmin
echo 'MinIO client configured'

# Create demo user
mc admin user add local demouser demopassword
echo 'User demouser created'

# Attach read/write policy to demo user
mc admin policy attach local readwrite --user demouser
echo 'Policy attached to demouser'

# Create buckets
mc ls local/demo-bucket || mc mb local/demo-bucket
mc ls local/test-bucket || mc mb local/test-bucket
echo 'Buckets created: demo-bucket, test-bucket'

# Create test files
echo 'Hello from MinIO! This is a test file created during setup.' > /tmp/test-file.txt
echo 'Created: '$(date) >> /tmp/test-file.txt
echo 'MinIO Server: http://localhost:9000' >> /tmp/test-file.txt

# Upload test files
mc cp /tmp/test-file.txt local/demo-bucket/welcome.txt
mc cp /tmp/test-file.txt local/test-bucket/setup-info.txt
echo 'Test files uploaded'

# Create setup configuration JSON
echo '{"setup_date":"'$(date -Iseconds)'","buckets":["demo-bucket","test-bucket"],"users":["demouser"],"status":"completed"}' > /tmp/setup-config.json

mc cp /tmp/setup-config.json local/demo-bucket/config.json

echo '=== demo-bucket contents ==='
mc ls local/demo-bucket
echo '=== test-bucket contents ==='
mc ls local/test-bucket

set +x
echo ''
echo 'MinIO setup completed successfully!'
echo ''
echo '=== MinIO (S3 Emulator) Connection Details ==='
echo 'Endpoint: http://localhost:9000'
echo 'Console: http://localhost:9001'
echo ''
echo '=== Credentials ==='
echo 'Root User:'
echo '  Access Key: minioadmin'
echo '  Secret Key: minioadmin'
echo ''
echo 'Demo User:'
echo '  Access Key: demouser'
echo '  Secret Key: demopassword'
echo '  Policy: readwrite'
echo ''
echo '=== Created Buckets ==='
echo '- demo-bucket (contains: welcome.txt, config.json)'
echo '- test-bucket (contains: setup-info.txt)'
echo ''
echo '=== S3 Client Configuration Examples ==='
echo 'AWS CLI:'
echo '  aws configure set aws_access_key_id demouser'
echo '  aws configure set aws_secret_access_key demopassword'
echo '  aws --endpoint-url http://localhost:9000 s3 ls'
echo ''
echo 'Python boto3:'
echo '  s3 = boto3.client("s3",'
echo '      endpoint_url="http://localhost:9000",'
echo '      aws_access_key_id="demouser",'
echo '      aws_secret_access_key="demopassword")'
echo ''
echo 'MinIO Console Access:'
echo '  URL: http://localhost:9001'
echo '  Username: minioadmin or demouser'
echo '  Password: minioadmin or demopassword'
