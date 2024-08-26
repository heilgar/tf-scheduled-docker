variable "region" {
  type        = string
  description = "The AWS region to deploy resources in"
}

variable "aws_account_id" {
  type        = string
  description = "The AWS account ID"
}

variable "s3_bucket" {
  type        = string
  description = "The S3 bucket name for Terraform state"
}

variable "dynamodb_table" {
  type        = string
  description = "The DynamoDB table name for Terraform state locking"
}

variable "ecr_repository_name" {
  type        = string
  description = "The name of the ECR repository"
}

variable "ecs_cluster_name" {
  type        = string
  description = "The name of the ECS cluster"
}

variable "cron_expression" {
  type        = string
  description = "The cron expression for the CloudWatch Event Rule"
  default     = "cron(0 0 * * ? *)"  # Daily at midnight UTC
}

variable "container_stop_timeout" {
  type        = number
  description = "The time duration (in seconds) to wait before the container is forcefully killed if it doesn't exit gracefully"
  default     = 120
}

variable "container_environment" {
  type = list(object({
    name  = string
    value = string
  }))
  description = "The environment variables to pass to the container"
  default     = []
}