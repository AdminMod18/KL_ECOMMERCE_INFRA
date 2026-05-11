# =============================================================================
# OUTPUTS - Módulo IAM
# =============================================================================

output "ecs_task_execution_role_arn" {
  description = "ARN del rol de ejecución de tasks ECS"
  value       = aws_iam_role.ecs_task_execution.arn
}

output "ecs_task_execution_role_name" {
  description = "Nombre del rol de ejecución de tasks ECS"
  value       = aws_iam_role.ecs_task_execution.name
}

output "ecs_task_role_arn" {
  description = "ARN del rol de task ECS"
  value       = aws_iam_role.ecs_task.arn
}

output "ecs_task_role_name" {
  description = "Nombre del rol de task ECS"
  value       = aws_iam_role.ecs_task.name
}

output "api_gateway_cloudwatch_role_arn" {
  description = "ARN del rol de API Gateway para CloudWatch"
  value       = aws_iam_role.api_gateway_cloudwatch.arn
}
