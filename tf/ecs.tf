resource "aws_ecs_cluster" "scheduled_cluster" {
  name = "${var.ecs_cluster_name}${local.region_suffix}"
}

# Create CloudWatch log group
resource "aws_cloudwatch_log_group" "ecs_logs" {
  name              = "/ecs/tf-command${local.region_suffix}"
  retention_in_days = 30 # Adjust this value as needed
}

resource "aws_ecs_task_definition" "command" {
  family                   = "command${local.region_suffix}"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = aws_iam_role.task_execution_role.arn
  task_role_arn            = aws_iam_role.task_role.arn

  container_definitions = jsonencode([
    {
      name        = "command"
      image       = "${var.aws_account_id}.dkr.ecr.${var.region}.amazonaws.com/${var.ecr_repository_name}:latest"
      essential   = true
      stopTimeout = var.container_stop_timeout
      environment = var.container_environment
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.ecs_logs.name
          awslogs-region        = var.region
          awslogs-stream-prefix = "ecs"
        }
      }
    }
  ])

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }
}

