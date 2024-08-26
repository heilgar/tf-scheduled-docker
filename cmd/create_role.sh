#!/bin/bash
set -e

# Source .env file if it exists
if [ -f ../.env ]; then
    source ../.env
fi

# Check for required environment variables
required_vars=("AWS_ACCOUNT_ID" "ROLE_NAME" "OIDC_PROVIDER_NAME" "ORG_NAME" "ECR_REPOSITORY_NAME" "BRANCH_NAME" "POLICY_NAME")
for var in "${required_vars[@]}"; do
    if [ -z "${!var}" ]; then
        echo "Error: $var is not set"
        exit 1
    fi
done

echo "Creating IAM role ${ROLE_NAME}..."

# Use Python to generate and escape the JSON
policy_document=$(python3 -c "
import json
import os

policy = {
    'Version': '2012-10-17',
    'Statement': [{
        'Effect': 'Allow',
        'Principal': {
            'Federated': f'arn:aws:iam::{os.environ['AWS_ACCOUNT_ID']}:oidc-provider/{os.environ['OIDC_PROVIDER_NAME']}'
        },
        'Action': 'sts:AssumeRoleWithWebIdentity',
        'Condition': {
            'StringLike': {
                'token.actions.githubusercontent.com:sub': f'repo:{os.environ['ORG_NAME']}/{os.environ['ECR_REPOSITORY_NAME']}:ref:refs/heads/{os.environ['BRANCH_NAME']}'
            },
            'StringEquals': {
                'token.actions.githubusercontent.com:aud': 'sts.amazonaws.com'
            }
        }
    }]
}

print(json.dumps(policy))
")

echo "Policy document:"
echo "$policy_document"

echo "Attempting to create role..."
aws iam create-role \
    --role-name "${ROLE_NAME}" \
    --assume-role-policy-document "$policy_document" \
    --query 'Role.Arn' \
    --output text > role_arn.txt

echo "IAM role created and ARN saved to role_arn.txt."

echo "Attaching policy to role ${ROLE_NAME}..."
aws iam attach-role-policy \
    --role-name "${ROLE_NAME}" \
    --policy-arn "arn:aws:iam::${AWS_ACCOUNT_ID}:policy/${POLICY_NAME}"
echo "Policy ${POLICY_NAME} attached to role ${ROLE_NAME}."