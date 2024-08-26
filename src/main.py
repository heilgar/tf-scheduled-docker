#!/usr/bin/env python3
import datetime
import json
import os
import time
import urllib3
import boto3
import logging
import watchtower
from botocore.exceptions import ClientError

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# CloudWatch Log Group Name
LOG_GROUP_NAME = "/task/cats"

def ensure_log_group_exists(log_group_name):
    client = boto3.client('logs')
    try:
        # Check if the log group exists
        response = client.describe_log_groups(logGroupNamePrefix=log_group_name)
        if any(group['logGroupName'] == log_group_name for group in response['logGroups']):
            logger.info(f"Log group {log_group_name} already exists.")
        else:
            # Create the log group
            client.create_log_group(logGroupName=log_group_name)
            logger.info(f"Log group {log_group_name} created successfully.")
    except ClientError as e:
        logger.error(f"Failed to create or check log group: {e}")
        raise

def get_cat_fact():
    http = urllib3.PoolManager()
    response = http.request('GET', 'https://catfact.ninja/fact')
    if response.status == 200:
        return json.loads(response.data.decode('utf-8'))
    else:
        return None

def ensure_bucket_exists(bucket_name):
    session = boto3.Session()
    s3 = session.client('s3')
    try:
        s3.head_bucket(Bucket=bucket_name)
    except ClientError as e:
        error_code = int(e.response['Error']['Code'])
        if error_code == 404:
            logger.info(f"Bucket {bucket_name} does not exist. Creating...")
            try:
                region = session.region_name
                if region == 'us-east-1':
                    s3.create_bucket(Bucket=bucket_name)
                else:
                    s3.create_bucket(
                        Bucket=bucket_name,
                        CreateBucketConfiguration={'LocationConstraint': region}
                    )
                logger.info(f"Bucket {bucket_name} created successfully.")
            except ClientError as create_error:
                logger.error(f"Failed to create bucket: {create_error}")
                return False
        else:
            logger.error(f"Error checking bucket: {e}")
            return False
    return True

def upload_to_s3(data, bucket_name, file_name):
    s3 = boto3.client('s3')
    s3.put_object(Bucket=bucket_name, Key=file_name, Body=json.dumps(data))

def main():
    # Ensure the log group exists
    ensure_log_group_exists(LOG_GROUP_NAME)
    
    # Add CloudWatch handler
    logger.addHandler(watchtower.CloudWatchLogHandler(log_group=LOG_GROUP_NAME))

    execution_time = datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S')
    logger.info(f"Executed [{execution_time}]")

    cat_fact = get_cat_fact()
    if cat_fact:
        bucket_name = os.environ.get('S3_BUCKET_NAME')
        if not bucket_name:
            logger.error("S3_BUCKET_NAME environment variable is not set")
            return

        if ensure_bucket_exists(bucket_name):
            file_name = f"cat_fact_{execution_time.replace(' ', '_').replace(':', '-')}.json"
            upload_to_s3(cat_fact, bucket_name, file_name)
            logger.info(f"Cat fact uploaded to S3: {file_name}")
        else:
            logger.error("Failed to ensure bucket exists")
    else:
        logger.error("Failed to get cat fact")

if __name__ == "__main__":
    main()
    time.sleep(120)
    exit(0)
