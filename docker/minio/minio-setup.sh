#!/bin/sh
# MinIO Setup Script
# This script initializes MinIO with buckets and policies for testing

set -e

echo "========================================="
echo "MinIO Setup Script"
echo "========================================="

# MinIO connection details
MINIO_ALIAS="myminio"
MINIO_HOST="http://minio:9000"
MINIO_ROOT_USER="${MINIO_ROOT_USER:-minioadmin}"
MINIO_ROOT_PASSWORD="${MINIO_ROOT_PASSWORD:-minioadmin}"

echo "Configuring MinIO client..."
mc alias set $MINIO_ALIAS $MINIO_HOST $MINIO_ROOT_USER $MINIO_ROOT_PASSWORD

echo "Creating test buckets..."

# Create standard test buckets
mc mb $MINIO_ALIAS/snaplogic-test --ignore-existing
mc mb $MINIO_ALIAS/data-input --ignore-existing
mc mb $MINIO_ALIAS/data-output --ignore-existing
mc mb $MINIO_ALIAS/temp-storage --ignore-existing
mc mb $MINIO_ALIAS/backup --ignore-existing

echo "Setting bucket policies..."

# Make snaplogic-test bucket publicly readable for testing
cat > /tmp/public-read-policy.json << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {"AWS": ["*"]},
      "Action": ["s3:GetObject"],
      "Resource": ["arn:aws:s3:::snaplogic-test/*"]
    }
  ]
}
EOF

# Apply the public read policy to snaplogic-test bucket
mc anonymous set-json /tmp/public-read-policy.json $MINIO_ALIAS/snaplogic-test

# Create test files
echo "Creating sample test files..."

# Create a test JSON file
echo '{"test": "data", "timestamp": "'$(date -u +"%Y-%m-%dT%H:%M:%SZ")'"}'  > /tmp/test.json
mc cp /tmp/test.json $MINIO_ALIAS/snaplogic-test/test.json

# Create a test CSV file
cat > /tmp/test.csv << EOF
id,name,value,created_date
1,Test Item 1,100,2024-01-01
2,Test Item 2,200,2024-01-02
3,Test Item 3,300,2024-01-03
EOF
mc cp /tmp/test.csv $MINIO_ALIAS/data-input/test.csv

# Create a test text file
echo "This is a test file for SnapLogic S3 integration testing" > /tmp/test.txt
mc cp /tmp/test.txt $MINIO_ALIAS/snaplogic-test/test.txt

echo "Setting up bucket versioning..."
# Enable versioning on important buckets
mc version enable $MINIO_ALIAS/data-output
mc version enable $MINIO_ALIAS/backup

echo "Creating service account for SnapLogic..."
# Create a dedicated service account for SnapLogic with specific permissions
cat > /tmp/snaplogic-policy.json << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject",
        "s3:ListBucket",
        "s3:GetBucketLocation"
      ],
      "Resource": [
        "arn:aws:s3:::snaplogic-test/*",
        "arn:aws:s3:::data-input/*",
        "arn:aws:s3:::data-output/*",
        "arn:aws:s3:::temp-storage/*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "s3:ListAllMyBuckets",
        "s3:GetBucketLocation"
      ],
      "Resource": ["arn:aws:s3:::*"]
    }
  ]
}
EOF

# Create the policy in MinIO
mc admin policy create $MINIO_ALIAS snaplogic-policy /tmp/snaplogic-policy.json || true

# Create a user for SnapLogic
mc admin user add $MINIO_ALIAS snaplogic-user snaplogic-pass || true

# Attach policy to user
mc admin policy attach $MINIO_ALIAS snaplogic-policy --user snaplogic-user || true

echo ""
echo "========================================="
echo "MinIO Setup Complete!"
echo "========================================="
echo ""
echo "Buckets created:"
echo "  - snaplogic-test (public read)"
echo "  - data-input"
echo "  - data-output (versioned)"
echo "  - temp-storage"
echo "  - backup (versioned)"
echo ""
echo "Test files created:"
echo "  - snaplogic-test/test.json"
echo "  - snaplogic-test/test.txt"
echo "  - data-input/test.csv"
echo ""
echo "Service Account:"
echo "  Access Key: snaplogic-user"
echo "  Secret Key: snaplogic-pass"
echo ""
echo "MinIO Console: http://localhost:9011"
echo "API Endpoint: http://localhost:9010"
echo ""
