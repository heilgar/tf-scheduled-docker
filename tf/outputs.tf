output "cluster_name" { 
    value = aws_ecs_cluster.scheduled_cluster.name
}

output "task_execution_role" {
    value = aws_iam_role.task_execution_role.arn
}
