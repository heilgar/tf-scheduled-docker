# Task Execution Role
resource "aws_iam_role" "task_execution_role" {
  name = "task_execution_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}


# Custom policy for Task Execution Role
# Actions to run container
resource "aws_iam_policy" "ecs_task_execution_policy" {
  name        = "CustomECSTaskExecutionPolicy"
  description = "Custom policy for ECS task execution role"
  policy      = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "s3:PutObject",
          "s3:GetObject"
        ],
        Effect   = "Allow",
        Resource = "*"
      }
    ]
  })
}

# Attach the custom policy to the Task Execution Role
resource "aws_iam_role_policy_attachment" "task_execution_role_policy" {
  role       = aws_iam_role.task_execution_role.name
  policy_arn = aws_iam_policy.ecs_task_execution_policy.arn
}

# Attach the managed CloudWatch Logs policy to the Task Execution Role
resource "aws_iam_role_policy_attachment" "cloudwatch_logs_policy_attachment" {
  role       = aws_iam_role.task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchLogsFullAccess"
}

# Task Role
resource "aws_iam_role" "task_role" {
  name = "ecs_task_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

# Custom policy for Task Role
# Actions allowed inside container
resource "aws_iam_policy" "ecs_task_policy" {
  name        = "CustomECSTaskPolicy"
  description = "Custom policy for ECS task role"
  policy      = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:ListBucket",
          "s3:CreateBucket",
          "logs:PutLogEvents",
          "logs:CreateLogStream",
          "logs:DescribeLogGroups",
          "logs:CreateLogGroup"
        ],
        Effect   = "Allow",
        Resource = "*"
      }
    ]
  })
}

# Attach the custom policy to the Task Role
resource "aws_iam_role_policy_attachment" "task_role_policy_attachment" {
  role       = aws_iam_role.task_role.name
  policy_arn = aws_iam_policy.ecs_task_policy.arn
}
