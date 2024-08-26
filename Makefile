# Variables (replace with your values or load from .env)
ifneq (,$(wildcard ./.env))
    include .env
    export
else
    ifndef AWS_REGION
        $(error AWS_REGION is not set)
    endif
    ifndef S3_BUCKET
        $(error S3_BUCKET is not set)
    endif
    ifndef DYNAMODB_TABLE
        $(error DYNAMODB_TABLE is not set)
    endif
    ifndef AWS_ACCOUNT_ID
        $(error AWS_ACCOUNT_ID is not set)
    endif
    ifndef ROLE_NAME
        $(error ROLE_NAME is not set)
    endif
    ifndef OIDC_PROVIDER_URL
        $(error OIDC_PROVIDER_URL is not set)
    endif
    ifndef OIDC_PROVIDER_NAME
        $(error OIDC_PROVIDER_NAME is not set)
    endif
    ifndef POLICY_NAME
        $(error POLICY_NAME is not set)
    endif
	ifndef ECR_REPOSITORY_NAME
		$(error ECR_REPOSITORY_NAME is not set)
	endif
endif

# Helper function to escape JSON for command line
define escape_json
$(subst ','\'',$(subst ",\",$(1)))
endef

.PHONY: create-policy create-role setup create-backend init plan apply destroy destroy-resources help

# Help command
help:
	@echo "Available commands:"
	@echo "  help                 : Show this help message"
	@echo "  setup                : Run create-policy, create-role, and create-backend"
	@echo "  init                 : Initialize Terraform"
	@echo "  plan                 : Plan terraform -chdir=tf changes"
	@echo "  apply                : Apply terraform -chdir=tf changes"
	@echo "  destroy              : Destroy Terraform-managed infrastructure"
	@echo "  destroy-resources    : Destroy IAM role, policy, S3 bucket, and DynamoDB table (with confirmation)"
	@echo ""

# Set help as the default target
.DEFAULT_GOAL := help

# Command to create the IAM policy for GitHub Actions OIDC
create-policy:
	@bash ./cmd/create_policy.sh

create-role:
	@bash ./cmd/create_role.sh

create-ecr:
	@aws ecr create-repository --repository-name $(ECR_REPOSITORY_NAME) --region $(AWS_REGION)

create-backend:
	@bash ./cmd/create_backend.sh

build:
	@docker build -t $(ECR_REPOSITORY_NAME) .

push: build
	@aws ecr get-login-password --region $(AWS_REGION) | docker login --username AWS --password-stdin $(AWS_ACCOUNT_ID).dkr.ecr.$(AWS_REGION).amazonaws.com
	@docker tag $(ECR_REPOSITORY_NAME):latest $(AWS_ACCOUNT_ID).dkr.ecr.$(AWS_REGION).amazonaws.com/$(ECR_REPOSITORY_NAME):latest
	@docker push $(AWS_ACCOUNT_ID).dkr.ecr.$(AWS_REGION).amazonaws.com/$(ECR_REPOSITORY_NAME):latest

run:
	docker run -v ~/.aws:/root/.aws:ro -e S3_BUCKET_NAME=test-cat-cbb29f94-fe3c-4a6b-9a96-c62cb10637f5 $(ECR_REPOSITORY_NAME):latest 

setup: create-policy create-role create-backend create-ecr push
	@echo "Setup complete. Role ARN is: "
	@cat role_arn.txt


# Initialize Terraform
init:
	terraform -chdir=tf init \
		-backend-config="bucket=$(S3_BUCKET)" \
		-backend-config="key=terraform.tfstate" \
		-backend-config="region=$(AWS_REGION)" \
		-backend-config="dynamodb_table=$(DYNAMODB_TABLE)" \
		-backend-config="encrypt=true"

# Plan terraform -chdir=tf changes
plan:
	terraform -chdir=tf plan \
		-var="region=$(AWS_REGION)" \
		-var="aws_account_id=$(AWS_ACCOUNT_ID)" \
		-var="s3_bucket=$(S3_BUCKET)" \
		-var="dynamodb_table=$(DYNAMODB_TABLE)" \
		-var="ecr_repository_name=$(ECR_REPOSITORY_NAME)" \
		-var="ecs_cluster_name=$(ECS_CLUSTER_NAME)" \
		-var="cron_expression=$(CRON_EXPRESSION)" \
		-var="container_stop_timeout=$(CONTAINER_STOP_TIMEOUT)" \
		-var="container_environment=$(call escape_json,$(CONTAINER_ENVIRONMENT))"

# Apply terraform -chdir=tf configuration
apply:
	terraform -chdir=tf apply -auto-approve \
		-var="region=$(AWS_REGION)" \
		-var="aws_account_id=$(AWS_ACCOUNT_ID)" \
		-var="s3_bucket=$(S3_BUCKET)" \
		-var="dynamodb_table=$(DYNAMODB_TABLE)" \
		-var="ecr_repository_name=$(ECR_REPOSITORY_NAME)" \
		-var="ecs_cluster_name=$(ECS_CLUSTER_NAME)" \
		-var="cron_expression=$(CRON_EXPRESSION)" \
		-var="container_stop_timeout=$(CONTAINER_STOP_TIMEOUT)" \
		-var="container_environment=$(call escape_json,$(CONTAINER_ENVIRONMENT))"

# Destroy Terraform-managed infrastructure
destroy:
	terraform -chdir=tf destroy -auto-approve \
		-var="region=$(AWS_REGION)" \
		-var="aws_account_id=$(AWS_ACCOUNT_ID)" \
		-var="s3_bucket=$(S3_BUCKET)" \
		-var="dynamodb_table=$(DYNAMODB_TABLE)" \
		-var="ecr_repository_name=$(ECR_REPOSITORY_NAME)" \
		-var="ecs_cluster_name=$(ECS_CLUSTER_NAME)" \
		-var="cron_expression=$(CRON_EXPRESSION)" \
		-var="container_stop_timeout=$(CONTAINER_STOP_TIMEOUT)" \
		-var="container_environment=$(call escape_json,$(CONTAINER_ENVIRONMENT))"

# Command to destroy IAM role, policy, and backend resources
destroy-resources:
	@echo "This will destroy the IAM role, policy, and backend resources (S3 bucket and DynamoDB table)."
	@echo "Are you sure you want to proceed? This action cannot be undone."
	@read -p "Type 'yes' to continue: " confirm && [ "$$confirm" = "yes" ] || exit 1
	@echo "Proceeding with resource destruction..."

	@echo "Detaching policy from role $(ROLE_NAME)..."
	@read -p "Continue? (y/n) " confirm && [ "$$confirm" = "y" ] && \
	aws iam detach-role-policy --role-name $(ROLE_NAME) --policy-arn arn:aws:iam::$(AWS_ACCOUNT_ID):policy/$(POLICY_NAME) || echo "Skipped."

	@echo "Deleting IAM role $(ROLE_NAME)..."
	@read -p "Continue? (y/n) " confirm && [ "$$confirm" = "y" ] && \
	aws iam delete-role --role-name $(ROLE_NAME) || echo "Skipped."

	@echo "Deleting IAM policy $(POLICY_NAME)..."
	@read -p "Continue? (y/n) " confirm && [ "$$confirm" = "y" ] && \
	aws iam delete-policy --policy-arn arn:aws:iam::$(AWS_ACCOUNT_ID):policy/$(POLICY_NAME) || echo "Skipped."

	@echo "Deleting S3 bucket $(S3_BUCKET)..."
	@read -p "Continue? (y/n) " confirm && [ "$$confirm" = "y" ] && \
	aws s3 rb s3://$(S3_BUCKET) --force || echo "Skipped."

	@echo "Deleting DynamoDB table $(DYNAMODB_TABLE)..."
	@read -p "Continue? (y/n) " confirm && [ "$$confirm" = "y" ] && \
	aws dynamodb delete-table --table-name $(DYNAMODB_TABLE) || echo "Skipped."

	@echo "Deleting ECR repository $(ECR_REPOSITORY_NAME)..."
	@read -p "Continue? (y/n) " confirm && [ "$$confirm" = "y" ] && \
	aws ecr delete-repository --repository-name $(ECR_REPOSITORY_NAME) --force || echo "Skipped."

	@echo "Resource destruction complete."
