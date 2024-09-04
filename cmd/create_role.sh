#!/bin/bash
set -e

# Source .env file if it exists
if [ -f ../.env ]; then
    source ../.env
fi

# Check for required environment variables
required_vars=("AWS_ACCOUNT_ID" "ROLE_NAME" "GITHUB_USERNAME" "GITHUB_REPO" "BRANCH_NAME" "POLICY_NAME")
for var in "${required_vars[@]}"; do
    if [ -z "${!var}" ]; then
        echo "Error: $var is not set"
        exit 1
    fi
done

# Function to fetch the thumbprint with retries
fetch_thumbprint() {
    local thumbprint
    local max_attempts=3
    local attempt=1

    while [ $attempt -le $max_attempts ]; do
        thumbprint=$(echo | openssl s_client -servername token.actions.githubusercontent.com -showcerts -connect token.actions.githubusercontent.com:443 2>/dev/null | openssl x509 -in /dev/stdin -noout -fingerprint -sha1 | cut -d'=' -f2 | tr -d ':')
        if [ -n "$thumbprint" ]; then
            echo "$thumbprint"
            return 0
        fi
        echo "Attempt $attempt failed. Retrying..."
        attempt=$((attempt + 1))
        sleep 2
    done

    echo "Failed to fetch thumbprint after $max_attempts attempts." >&2
    return 1
}

# Check OIDC Provider
echo "Checking OIDC Provider..."
if aws iam get-open-id-connect-provider --open-id-connect-provider-arn "arn:aws:iam::${AWS_ACCOUNT_ID}:oidc-provider/token.actions.githubusercontent.com" &>/dev/null; then
    echo "OIDC Provider already exists. Skipping creation."
else
    echo "OIDC Provider does not exist. Creating..."
    # Fetch the thumbprint
    echo "Fetching current thumbprint for GitHub OIDC provider..."
    if ! THUMBPRINT=$(fetch_thumbprint); then
        echo "Error: Unable to fetch thumbprint. Exiting."
        exit 1
    fi
    echo "Fetched thumbprint: $THUMBPRINT"

    echo "Creating OIDC Provider..."
    aws iam create-open-id-connect-provider \
        --url https://token.actions.githubusercontent.com \
        --client-id-list sts.amazonaws.com \
        --thumbprint-list "$THUMBPRINT"
    echo "OIDC Provider created successfully."
fi

# Generate the IAM role policy document
echo "Generating IAM role policy document..."
policy_document=$(cat <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "Federated": "arn:aws:iam::${AWS_ACCOUNT_ID}:oidc-provider/token.actions.githubusercontent.com"
            },
            "Action": "sts:AssumeRoleWithWebIdentity",
            "Condition": {
                "StringLike": {
                    "token.actions.githubusercontent.com:sub": "repo:${GITHUB_USERNAME}/${GITHUB_REPO}:ref:refs/heads/${BRANCH_NAME}"
                },
                "StringEquals": {
                    "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
                }
            }
        }
    ]
}
EOF
)

# Create or update IAM role
echo "Checking IAM role ${ROLE_NAME}..."
if aws iam get-role --role-name "${ROLE_NAME}" &>/dev/null; then
    echo "Role ${ROLE_NAME} already exists. Updating assume role policy..."
    aws iam update-assume-role-policy \
        --role-name "${ROLE_NAME}" \
        --policy-document "$policy_document"
    role_arn=$(aws iam get-role --role-name "${ROLE_NAME}" --query 'Role.Arn' --output text)
else
    echo "Creating IAM role ${ROLE_NAME}..."
    role_arn=$(aws iam create-role \
        --role-name "${ROLE_NAME}" \
        --assume-role-policy-document "$policy_document" \
        --query 'Role.Arn' \
        --output text)
    echo "IAM role created."
fi

echo "$role_arn" > role_arn.txt
echo "Role ARN saved to role_arn.txt: $role_arn"

# Create a new policy for Terraform operations
echo "Creating policy for Terraform operations..."
terraform_policy_document=$(cat <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "ecs:DescribeClusters",
                "logs:DescribeLogGroups",
                "iam:GetRole",
                "iam:GetPolicy",
                "ec2:DescribeVpcs",
                "events:DescribeRule",
                "ecs:*",
                "logs:*",
                "iam:*",
                "ec2:*",
                "events:*",
                "s3:*",
                "dynamodb:*",
                "cloudwatch:*",
                "elasticloadbalancing:*",
                "application-autoscaling:*",
                "ssm:*"
            ],
            "Resource": "*"
        }
    ]
}
EOF
)

# Create or update the Terraform policy
echo "Creating or updating Terraform policy..."
if aws iam get-policy --policy-arn "arn:aws:iam::${AWS_ACCOUNT_ID}:policy/${POLICY_NAME}_terraform" &>/dev/null; then
    echo "Terraform policy already exists. Updating..."
    policy_version=$(aws iam create-policy-version \
        --policy-arn "arn:aws:iam::${AWS_ACCOUNT_ID}:policy/${POLICY_NAME}_terraform" \
        --policy-document "$terraform_policy_document" \
        --set-as-default \
        --query 'PolicyVersion.VersionId' \
        --output text)
    echo "Terraform policy updated to version $policy_version"
else
    echo "Creating new Terraform policy..."
    aws iam create-policy \
        --policy-name "${POLICY_NAME}_terraform" \
        --policy-document "$terraform_policy_document"
    echo "Terraform policy created."
fi

# Attach policy to role
echo "Attaching policy to role ${ROLE_NAME}..."
aws iam attach-role-policy \
    --role-name "${ROLE_NAME}" \
    --policy-arn "arn:aws:iam::${AWS_ACCOUNT_ID}:policy/${POLICY_NAME}"
echo "Policy ${POLICY_NAME} attached to role ${ROLE_NAME}."

echo "Setup complete."