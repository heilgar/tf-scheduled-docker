#!/bin/bash
set -e

# Source .env file if it exists
if [ -f ../.env ]; then
    source ../.env
fi

# Check for required environment variables
required_vars=("AWS_REGION" "S3_BUCKET" "DYNAMODB_TABLE")
for var in "${required_vars[@]}"; do
    if [ -z "${!var}" ]; then
        echo "Error: $var is not set"
        exit 1
    fi
done

echo "Checking if S3 bucket ${S3_BUCKET} exists..."
if ! aws s3 ls "s3://${S3_BUCKET}" > /dev/null 2>&1; then
    echo "S3 bucket does not exist. Creating..."
    aws s3api create-bucket --bucket "${S3_BUCKET}" --region "${AWS_REGION}" --create-bucket-configuration LocationConstraint="${AWS_REGION}"
else
    echo "S3 bucket exists."
fi

echo "Checking if DynamoDB table ${DYNAMODB_TABLE} exists..."
if ! aws dynamodb describe-table --table-name "${DYNAMODB_TABLE}" > /dev/null 2>&1; then
    echo "DynamoDB table does not exist. Creating..."
    aws dynamodb create-table --table-name "${DYNAMODB_TABLE}" \
        --attribute-definitions AttributeName=LockID,AttributeType=S \
        --key-schema AttributeName=LockID,KeyType=HASH \
        --billing-mode PAY_PER_REQUEST
else
    echo "DynamoDB table exists."
fi