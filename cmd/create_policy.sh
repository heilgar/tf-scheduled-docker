#!/bin/bash
set -e

# Source .env file if it exists
if [ -f ../.env ]; then
    source ../.env
fi

# Check for required environment variables
required_vars=("AWS_REGION" "S3_BUCKET" "DYNAMODB_TABLE" "AWS_ACCOUNT_ID" "POLICY_NAME")
for var in "${required_vars[@]}"; do
    if [ -z "${!var}" ]; then
        echo "Error: $var is not set"
        exit 1
    fi
done

# Function to create or update policy
create_or_update_policy() {
    local policy_name="$1"
    local policy_document="$2"
    local policy_arn="arn:aws:iam::${AWS_ACCOUNT_ID}:policy/${policy_name}"

    if aws iam get-policy --policy-arn "$policy_arn" &>/dev/null; then
        echo "Policy ${policy_name} exists. Updating..."
        policy_version=$(aws iam create-policy-version \
            --policy-arn "$policy_arn" \
            --policy-document "$policy_document" \
            --set-as-default \
            --query 'PolicyVersion.VersionId' \
            --output text)
        echo "Policy ${policy_name} updated to version $policy_version"
    else
        echo "Creating new policy ${policy_name}..."
        aws iam create-policy \
            --policy-name "${policy_name}" \
            --policy-document "$policy_document"
        echo "Policy ${policy_name} created."
    fi
}

echo "Creating or updating IAM policy ${POLICY_NAME}..."
policy_document='{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "s3:GetObject",
                "s3:PutObject",
                "s3:DeleteObject",
                "s3:ListBucket"
            ],
            "Resource": [
                "arn:aws:s3:::'"${S3_BUCKET}"'",
                "arn:aws:s3:::'"${S3_BUCKET}"'/*"
            ]
        },
        {
            "Effect": "Allow",
            "Action": [
                "dynamodb:GetItem",
                "dynamodb:PutItem",
                "dynamodb:DeleteItem",
                "dynamodb:Scan",
                "dynamodb:Query"
            ],
            "Resource": "arn:aws:dynamodb:'"${AWS_REGION}"':'"${AWS_ACCOUNT_ID}"':table/'"${DYNAMODB_TABLE}"'"
        },
        {
            "Effect": "Allow",
            "Action": [
                "ecr:GetAuthorizationToken",
                "ecr:BatchCheckLayerAvailability",
                "ecr:GetDownloadUrlForLayer",
                "ecr:GetRepositoryPolicy",
                "ecr:DescribeRepositories",
                "ecr:ListImages",
                "ecr:DescribeImages",
                "ecr:BatchGetImage",
                "ecr:InitiateLayerUpload",
                "ecr:UploadLayerPart",
                "ecr:CompleteLayerUpload",
                "ecr:PutImage"
            ],
            "Resource": "arn:aws:ecr:'"${AWS_REGION}"':'"${AWS_ACCOUNT_ID}"':repository/*"
        },
        {
            "Effect": "Allow",
            "Action": "ecr:GetAuthorizationToken",
            "Resource": "*"
        }
    ]
}'

create_or_update_policy "${POLICY_NAME}" "$policy_document"

echo "Policy setup complete."

