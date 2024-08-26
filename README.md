# tf-scheduled-docker

This project sets up a scheduled Docker container task on AWS ECS using Terraform.

## Table of Contents
- [Prerequisites](#prerequisites)
- [Setup and Deployment](#setup-and-deployment)
  - [Additional commands](#additional-commands)
- [Customization](#customization)
  - [Modifying Container Permissions](#modifying-container-permissions)
  - [Modifying Schedule](#modifying-schedule)
- [Configuring GitHub Actions](#configuring-github-actions)
  - [Workflow Overview](#workflow-overview)
  - [Manual Workflow Dispatch](#manual-workflow-dispatch)
  - [Troubleshooting GitHub Actions](#troubleshooting-github-actions)
- [Troubleshooting](#troubleshooting)
- [Support](#support)

## Prerequisites
- AWS CLI: https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html
- Terraform: https://developer.hashicorp.com/terraform/install

## Setup and Deployment

1. Clone the repository: 
```sh
git clone https://github.com/heilgar/tf-scheduled-docker
cd tf-scheduled-docker
```

2. Configure environment variables:
- Copy `.env.example` to `.env`:
`cp .env.example .env`

- Open `.env` and fill the required values:
    - `AWS_REGION`: Your target AWS region (e.g., us-east-1)
    - `AWS_ACCOUNT_ID`: Your AWS account ID
    - `S3_BUCKET`: A unique name for the S3 bucket to store Terraform state
    - `DYNAMODB_TABLE`: A name for the DynamoDB table for state locking
    - `ECR_REPOSITORY_NAME`: Name for your ECR repository
    - `ECS_CLUSTER_NAME`: Name for your ECS cluster
    - `CRON_EXPRESSION`: Cron expression for task scheduling (e.g., "cron(0 0 * * ? *)" for daily at midnight UTC)
    - `CONTAINER_STOP_TIMEOUT`: Time in seconds to wait before force-stopping the container
    - `CONTAINER_ENVIRONMENT`: JSON array of environment variables for the container

3. Configure AWS CLI: `aws configure`
4. Prepare scripts: `chmod +x cmd/*.sh`
5. Set up Terraform backend `make setup`. This command also will generate `role_arn.txt` required for Github Actions.
6. Initialize Terraform: `make init`
7. Plan the deployment: `make plan` 
8. Apply the changes: `make apply` 

### Additional commands: 
- `make destroy` destory deployed stack
- `make destroy-resources` destroy terraform backend 

## Customization
### Modifying Container Permissions
To configure additional roles or permissions for the container:

1. Open `iam.tf`
2. Locate the `aws_iam_policy` resource named `ecs_task_policy`
3. Modify the `Action` list in the policy to add or remove permissions as needed

Example: 

```hcl
resource "aws_iam_policy" "ecs_task_policy" {
  # ...
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:ListBucket",
          "logs:PutLogEvents",
          "logs:CreateLogStream",
          # Add your additional actions here
        ],
        Effect   = "Allow",
        Resource = "*"
      }
    ]
  })
}
```

### Modifying Schedule

To change the schedule of the task: 

1. Open `.env`
2. Modify the `CRON_EXPRESSION` value
    - Example: `CRON_EXPRESSION=cron(0 12 * * ? *)` for daily at 12:00 PM UTC


## Configuring GitHub Actions

This project includes a GitHub Actions workflow for building, pushing, and deploying your Docker image and Terraform configuration. Follow these steps to set it up:

1. Fork or clone the repository to your own GitHub account 
2. Navigate to the repository setting in GitHub. 
3. Go to Secrets and Variables > action. 
4. Add the following repository secrets:
    - `AWS_REGION`: Your AWS region (e.g., us-east-1)
    - `AWS_ACCOUNT_ID`: Your AWS Account ID
    - `S3_BUCKET`: The name of your S3 bucket for Terraform state
    - `DYNAMODB_TABLE`: The name of your DynamoDB table for state locking
    - `ECR_REPOSITORY_NAME`: The name of your ECR repository
    - `ECS_CLUSTER_NAME`: The name of your ECS cluster
    - `CRON_EXPRESSION`: The cron expression for your scheduled task
    - `CONTAINER_STOP_TIMEOUT`: Time in seconds to wait before force-stopping the container
    - `CONTAINER_ENVIRONMENT`: JSON array of environment variables for the container
    - `ROLE_NAME`: The name of the IAM role for GitHub Actions
    - `OIDC_PROVIDER_URL`: The URL of your OIDC provider
    - `OIDC_PROVIDER_NAME`: The name of your OIDC provider
    - `POLICY_NAME`: The name of the IAM policy for GitHub Actions
    - `AWS_ROLE_ARN`: The ARN of the IAM role for GitHub Actions to assume
    - `AWS_ROLE_ARN`: The ARN of the IAM role for GitHub Actions to assume (`role_arn.txt` should be in the root of your project if you follow steps)
5. Enable GitHub Action in your repository if not already enabled.
6. Customize the workflow (optional): 
    - The workflow file is located at `.github/workflows/build-push-deploy.yml`
    - Modify the triggers or add additional steps as needed 
7. Trigger the workflow: 
    - Pushin to the `main` branch will trigger the workflow 
    - You can also manually trigger the workflow from the Actions tab in GitHub

### Workflow Overview 
The GitHub Actions workflow includes the following jobs: 
- **push-docker**: Builds and pushes the Docker image to ECR
- **terraform**: Runs Terraform command (init, plan, apply)

The workflow can be triggered in three ways: 
1. Push to the `main` branch 
2. Pull request to the `main` branch 
3. Manual trigger with options to plan, push, or apply 

### Manual Workflow Dispatch 

You can manuallly trigger the workflow with specific actions: 

1. Go to the Actions tab in your GitHub repository 
2. Select the "Build, Push, and Deploy" workflow
3. Click "Run workflow" 
4. Choose the action you want to perform: 
    - `plan`: Run Terraform plan
    - `push`: Build and push the Docker image
    - `apply`: Run Terraform apply 

This allows you to control when to push new Docker images or apply Terraform changes separetely from code pushes. 

### Troubleshooting GitHub Acitions

If you encounter issues with the GitHub Actions workflow:

1. Check the workflow run logs in the Actions tab of your GitHub repository
2. Ensure all required secrets are correctly set in your repository settings
3. Verify that the AWS IAM role has the necessary permissions and trust relationships
4. Check that your Terraform configuration and Docker build process work locally before troubleshooting the workflow

Remember to **never commit sensitive information** directly to your repository. Always use GitHub Secrets for sensitive data.


## Troubleshooting

If you encounter any issues during deployment, check the following:

1. Ensure all values in `.env` are correctly set
2. Verify that your AWS CLI is properly configured with the correct credentials
3. Check CloudWatch Logs for any error messages from your ECS tasks

For more detailed logs and debugging, you can modify the log retention period in `ecs.tf` by cahnging the `retention_in_days` value of the `aws_cloudwatch_log_group` resource. 

## Support 

For any question or issues, feel free to reach me out or open an issue in the GitHub repository. 