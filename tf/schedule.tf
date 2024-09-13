
resource "aws_cloudwatch_event_rule" "schedule_rule" {
  name                = "run-container-schedule${local.region_suffix}"
  description         = "Run Docker container every 5 minutes"
  schedule_expression = var.cron_expression
}

resource "aws_cloudwatch_event_target" "run_task_target" {
  rule      = aws_cloudwatch_event_rule.schedule_rule.name
  target_id = "RunECSTask"
  arn       = aws_ecs_cluster.scheduled_cluster.arn
  role_arn  = aws_iam_role.ecs_events_role.arn

  ecs_target {
    task_count          = 1
    task_definition_arn = aws_ecs_task_definition.command.arn
    launch_type         = "FARGATE"
    network_configuration {
      subnets          = [aws_subnet.ecs_public_subnet.id]
      assign_public_ip = true
      security_groups  = [aws_security_group.ecs_tasks.id]
    }
    enable_execute_command = false
  }
}


resource "aws_iam_role" "ecs_events_role" {
  name = "ecs_events_role${local.region_suffix}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "events.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_events_role_policy" {
  role       = aws_iam_role.ecs_events_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceEventsRole"
}

# Update the security group to use the new VPC
resource "aws_security_group" "ecs_tasks" {
  name        = "ecs-tasks-sg${local.region_suffix}"
  description = "Security group for ECS tasks"
  vpc_id      = aws_vpc.ecs_vpc.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "ecs-tasks-sg"
  }
}

