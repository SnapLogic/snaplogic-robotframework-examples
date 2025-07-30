#!/usr/bin/env python
"""
Script to upload Robot Framework test results to S3.
Based on the upload_test_results.py from slim-tx-engine.
"""
import glob
import os
import sys
from datetime import datetime

try:
    import boto3
    from botocore.exceptions import ClientError
except ImportError:
    print("boto3 not found. Installing...")
    import subprocess
    subprocess.check_call([sys.executable, "-m", "pip", "install", "boto3"])
    import boto3
    from botocore.exceptions import ClientError





def get_latest_files(local_dir, pattern, count=None):
    """
    Get the latest files matching the pattern.
    If count is specified, return only the latest 'count' files.
    """
    search_pattern = os.path.join(local_dir, pattern)
    files = glob.glob(search_pattern)
    
    if not files:
        return []
    
    # Sort files by modification time (newest first)
    files.sort(key=lambda x: os.path.getmtime(x), reverse=True)
    
    if count:
        return files[:count]
    return files


def main():
    # Read AWS credentials from environment variables
    aws_access_key_id = os.environ.get("AWS_ACCESS_KEY_ID")
    aws_secret_access_key = os.environ.get("AWS_SECRET_ACCESS_KEY")

    if not aws_access_key_id or not aws_secret_access_key:
        print("Error: AWS credentials are not set in the environment variables.")
        print("Please set AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY.")
        sys.exit(1)

    # Use the bucket name from an environment variable if needed, or hard-code it.
    bucket = os.environ.get("S3_BUCKET", "artifacts.slimdev.snaplogic")

    # Use project name from environment or default
    project_name = os.environ.get("PROJECT_NAME", "snaplogic-robotframework-examples")
    
    # Get branch name from environment (useful for CI/CD) or use default
    branch_name = os.environ.get("BRANCH_NAME", "main")
    
    # Option to upload only latest files (useful for development)
    upload_latest_only = os.environ.get("UPLOAD_LATEST_ONLY", "false").lower() == "true"
    latest_count = int(os.environ.get("LATEST_COUNT", "5"))

    # Determine the directory of this script and then set local_dir relative to it.
    script_dir = os.path.dirname(os.path.abspath(__file__))
    local_dir = os.path.join(script_dir, "robot_output")

    if not os.path.exists(local_dir):
        print(f"Error: Robot output directory not found: {local_dir}")
        sys.exit(1)

    # Create the S3 client using boto3
    s3_client = boto3.client(
        "s3", 
        aws_access_key_id=aws_access_key_id, 
        aws_secret_access_key=aws_secret_access_key
    )

    # Add timestamp to make uploads unique
    timestamp = datetime.now().strftime("%Y%m%d-%H%M%S")
    
    # Define the uploads - all files go directly under RF_CommonTests_Results/{timestamp}/
    base_upload_dir = f"RF_CommonTests_Results/{timestamp}"
    
    deployments = [
        {
            "pattern": "output-*.xml",
            "upload_dir": base_upload_dir
        },
        {
            "pattern": "log-*.html",
            "upload_dir": base_upload_dir
        },
        {
            "pattern": "report-*.html",
            "upload_dir": base_upload_dir
        },
    ]

    # Track total files uploaded
    total_files_uploaded = 0
    
    # Upload files for each deployment
    for deploy in deployments:
        if upload_latest_only:
            # Get only the latest files
            latest_files = get_latest_files(local_dir, deploy["pattern"], latest_count)
            if latest_files:
                print(f"\nUploading {len(latest_files)} latest files matching '{deploy['pattern']}':")
                for filepath in latest_files:
                    filename = os.path.basename(filepath)
                    s3_key = f"{deploy['upload_dir'].rstrip('/')}/{filename}"
                    print(f"Uploading {filepath} to s3://{bucket}/{s3_key}")
                    try:
                        s3_client.upload_file(filepath, bucket, s3_key)
                        total_files_uploaded += 1
                    except ClientError as e:
                        print(f"Failed to upload {filepath}: {e}")
                        sys.exit(1)
                print(f"Successfully uploaded {len(latest_files)} files.")
            else:
                print(f"No files found for pattern: {deploy['pattern']}")
        else:
            # Upload all files matching the pattern
            search_pattern = os.path.join(local_dir, deploy["pattern"])
            files = glob.glob(search_pattern)
            
            if files:
                for filepath in files:
                    filename = os.path.basename(filepath)
                    s3_key = f"{deploy['upload_dir'].rstrip('/')}/{filename}"
                    print(f"Uploading {filepath} to s3://{bucket}/{s3_key}")
                    try:
                        s3_client.upload_file(filepath, bucket, s3_key)
                    except ClientError as e:
                        print(f"Failed to upload {filepath}: {e}")
                        sys.exit(1)
                print(f"Successfully uploaded {len(files)} files matching '{deploy['pattern']}'.")
            else:
                print(f"No files found for pattern: {deploy['pattern']} in directory: {local_dir}")
    
    print(f"\nAll uploads completed successfully!")
    print(f"Total files uploaded: {total_files_uploaded}")
    print(f"Files uploaded to S3 bucket: {bucket}")
    print(f"Base path: RF_CommonTests_Results/{timestamp}/")
    print(f"\n" + "="*70)
    print(f"📍 Complete S3 Location:")
    print(f"   s3://{bucket}/RF_CommonTests_Results/{timestamp}/")
    print(f"\n🌐 S3 Console URL:")
    print(f"   https://s3.console.aws.amazon.com/s3/buckets/{bucket}?prefix=RF_CommonTests_Results/{timestamp}/")
    print(f"\n📋 AWS CLI command to list uploaded files:")
    print(f"   aws s3 ls s3://{bucket}/RF_CommonTests_Results/{timestamp}/")
    print(f"\n📥 AWS CLI command to download all files:")
    print(f"   aws s3 sync s3://{bucket}/RF_CommonTests_Results/{timestamp}/ ./downloaded_results/")
    print("="*70)


if __name__ == "__main__":
    main()
