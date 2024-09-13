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

# Function to create S3 bucket if it doesn't exist
create_s3_bucket() {
    if aws s3api head-bucket --bucket "$1" 2>/dev/null; then
        echo "S3 bucket $1 already exists."
    else
        echo "Creating S3 bucket $1..."
        aws s3api create-bucket --bucket "$1" --region "$AWS_REGION" \
            --create-bucket-configuration LocationConstraint="$AWS_REGION"
        echo "S3 bucket $1 created successfully."
    fi
}

# Function to create DynamoDB table if it doesn't exist
create_dynamodb_table() {
    if aws dynamodb describe-table --table-name "$1" &>/dev/null; then
        echo "DynamoDB table $1 already exists."
    else
        echo "Creating DynamoDB table $1..."
        aws dynamodb create-table \
            --table-name "$1" \
            --attribute-definitions AttributeName=LockID,AttributeType=S \
            --key-schema AttributeName=LockID,KeyType=HASH \
            --billing-mode PAY_PER_REQUEST \
            --region "$AWS_REGION"
        echo "DynamoDB table $1 created successfully."
    fi
}

# Create or check S3 bucket
create_s3_bucket "$S3_BUCKET"

# Create or check DynamoDB table
create_dynamodb_table "$DYNAMODB_TABLE"

echo "Backend setup complete."

