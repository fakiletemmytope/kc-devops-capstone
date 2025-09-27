#!/bin/env python3
import os
import boto3
from dotenv import load_dotenv
import sys

load_dotenv()

# Get filename from command line argument
if len(sys.argv) < 2:
    print("Usage: python3 save_to_s3.py <file_path>")
    sys.exit(1)

file_path = sys.argv[1]
folder = "dream-db-backup/"
filename = os.path.basename(file_path)  # Get just the filename, not full path
bucket = "terraformstatesbackend"
# Initialize S3 client
client = boto3.client(
    "s3",
    aws_access_key_id=os.getenv("AWS_ACCESS_KEY_ID"),
    aws_secret_access_key=os.getenv("AWS_SECRET_ACCESS_KEY"),
    region_name=os.getenv("AWS_REGION"),
)

# Upload to S3
try:
    client.upload_file(file_path, bucket, f"{folder}{filename}")
    print(f"Successfully uploaded {filename} to S3")
except Exception as e:
    print(f"Error uploading to S3: {e}")
    sys.exit(1)
