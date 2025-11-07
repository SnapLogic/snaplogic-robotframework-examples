#!/usr/bin/env python
"""
Script to upload Robot Framework test results to S3.
Based on the upload_test_results.py from slim-tx-engine.
"""
import glob
import os
import sys
import zipfile
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
    
    # Option to create and upload a zip file
    create_zip = os.environ.get("CREATE_ZIP", "true").lower() == "true"
    
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
                files_uploaded = 0
                for filepath in files:
                    filename = os.path.basename(filepath)
                    s3_key = f"{deploy['upload_dir'].rstrip('/')}/{filename}"
                    print(f"Uploading {filepath} to s3://{bucket}/{s3_key}")
                    try:
                        s3_client.upload_file(filepath, bucket, s3_key)
                        total_files_uploaded += 1
                        files_uploaded += 1
                    except ClientError as e:
                        print(f"Failed to upload {filepath}: {e}")
                        sys.exit(1)
                print(f"Successfully uploaded {files_uploaded} files matching '{deploy['pattern']}'.")
            else:
                print(f"No files found for pattern: {deploy['pattern']} in directory: {local_dir}")
    
    # Debug output
    print(f"\nDebug: CREATE_ZIP = {create_zip}")
    print(f"Debug: total_files_uploaded = {total_files_uploaded}")
    
    # Create and upload zip file if requested
    if create_zip and total_files_uploaded > 0:
        print(f"\n📦 Creating zip file with all test results...")
        print(f"Total files to zip: {total_files_uploaded}")
        zip_filename = f"test_results_{timestamp}.zip"
        zip_filepath = os.path.join(local_dir, zip_filename)
        
        try:
            with zipfile.ZipFile(zip_filepath, 'w', zipfile.ZIP_DEFLATED) as zipf:
                # Add all test result files to the zip
                for pattern in ["*.xml", "log-*.html", "report-*.html"]:
                    files = glob.glob(os.path.join(local_dir, pattern))
                    for file in files:
                        arcname = os.path.basename(file)
                        zipf.write(file, arcname)
                        print(f"   Added to zip: {arcname}")
            
            # Get zip file size
            zip_size_mb = os.path.getsize(zip_filepath) / (1024 * 1024)
            print(f"\n📦 Zip file created: {zip_filename} ({zip_size_mb:.2f} MB)")
            print(f"   Contains {total_files_uploaded} files")
            
            # Upload the zip file
            s3_zip_key = f"{base_upload_dir}/{zip_filename}"
            print(f"Uploading zip file to s3://{bucket}/{s3_zip_key}")
            
            s3_client.upload_file(zip_filepath, bucket, s3_zip_key)
            print(f"✅ Zip file uploaded successfully!")
            
            # Clean up local zip file
            os.remove(zip_filepath)
            print(f"\n🧿 Cleaned up local zip file")
            
        except Exception as e:
            print(f"\n⚠️  Warning: Failed to create/upload zip file: {e}")
            import traceback
            traceback.print_exc()
            # Don't fail the entire upload if zip creation fails
            if os.path.exists(zip_filepath):
                os.remove(zip_filepath)
    elif not create_zip:
        print(f"\n📦 Zip file creation skipped (CREATE_ZIP=false)")
    elif total_files_uploaded == 0:
        print(f"\n📦 Zip file creation skipped (no files uploaded)")
    
    print(f"\nAll uploads completed successfully!")
    print(f"Total files uploaded: {total_files_uploaded}")
    if create_zip and total_files_uploaded > 0:
        print(f"Zip file uploaded: test_results_{timestamp}.zip")
    print(f"Files uploaded to S3 bucket: {bucket}")
    print(f"Base path: RF_CommonTests_Results/{timestamp}/")
    print(f"\n" + "="*70)
    print(f"📍 Complete S3 Location:")
    print(f"   s3://{bucket}/RF_CommonTests_Results/{timestamp}/")
    if create_zip and total_files_uploaded > 0:
        print(f"\n📦 Zip file location:")
        print(f"   s3://{bucket}/RF_CommonTests_Results/{timestamp}/test_results_{timestamp}.zip")
        print(f"\n📥 AWS CLI command to download zip file:")
        print(f"   aws s3 cp s3://{bucket}/RF_CommonTests_Results/{timestamp}/test_results_{timestamp}.zip ./")
    print(f"\n🌐 S3 Console URL:")
    print(f"   https://s3.console.aws.amazon.com/s3/buckets/{bucket}?prefix=RF_CommonTests_Results/{timestamp}/")
    print(f"\n📋 AWS CLI command to list uploaded files:")
    print(f"   aws s3 ls s3://{bucket}/RF_CommonTests_Results/{timestamp}/")
    print(f"\n📥 AWS CLI command to download all files:")
    print(f"   aws s3 sync s3://{bucket}/RF_CommonTests_Results/{timestamp}/ ./downloaded_results/")
    print("="*70)


if __name__ == "__main__":
    main()
