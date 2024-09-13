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

# Check and update OIDC Provider
echo "Checking OIDC Provider..."
OIDC_ARN="arn:aws:iam::${AWS_ACCOUNT_ID}:oidc-provider/token.actions.githubusercontent.com"
if aws iam get-open-id-connect-provider --open-id-connect-provider-arn "$OIDC_ARN" &>/dev/null; then
    echo "OIDC Provider exists. Updating thumbprint..."
    THUMBPRINT=$(fetch_thumbprint)
    aws iam update-open-id-connect-provider-thumbprint \
        --open-id-connect-provider-arn "$OIDC_ARN" \
        --thumbprint-list "$THUMBPRINT"
    echo "OIDC Provider thumbprint updated."
else
    echo "OIDC Provider does not exist. Creating..."
    THUMBPRINT=$(fetch_thumbprint)
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
                "Federated": "${OIDC_ARN}"
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
    echo "Role ${ROLE_NAME} exists. Updating assume role policy..."
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
fi

echo "$role_arn" > role_arn.txt
echo "Role ARN saved to role_arn.txt: $role_arn"

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

# Create or update main policy
main_policy_document=$(cat <<EOF
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
                "dynamodb:GetItem",
                "dynamodb:PutItem",
                "dynamodb:DeleteItem",
                "dynamodb:Scan",
                "dynamodb:Query",
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
            "Resource": "*"
        }
    ]
}
EOF
)

create_or_update_policy "${POLICY_NAME}" "$main_policy_document"

# Create or update Terraform policy
terraform_policy_document=$(cat <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
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

create_or_update_policy "${POLICY_NAME}_terraform" "$terraform_policy_document"

# Attach policies to role
echo "Attaching policies to role ${ROLE_NAME}..."
aws iam attach-role-policy \
    --role-name "${ROLE_NAME}" \
    --policy-arn "arn:aws:iam::${AWS_ACCOUNT_ID}:policy/${POLICY_NAME}"
aws iam attach-role-policy \
    --role-name "${ROLE_NAME}" \
    --policy-arn "arn:aws:iam::${AWS_ACCOUNT_ID}:policy/${POLICY_NAME}_terraform"
echo "Policies attached to role ${ROLE_NAME}."

echo "Setup complete."

