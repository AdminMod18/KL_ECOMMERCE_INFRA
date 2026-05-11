# =============================================================================
# OUTPUTS - Módulo CloudWatch
# =============================================================================

output "log_group_names" {
  description = "Mapa de nombres de log groups por microservicio"
  value = {
    for name, lg in aws_cloudwatch_log_group.microservices :
    name => lg.name
  }
}

output "log_group_arns" {
  description = "Mapa de ARNs de log groups por microservicio"
  value = {
    for name, lg in aws_cloudwatch_log_group.microservices :
    name => lg.arn
  }
}

output "api_gateway_log_group_arn" {
  description = "ARN del log group de API Gateway"
  value       = aws_cloudwatch_log_group.api_gateway.arn
}

output "api_gateway_log_group_name" {
  description = "Nombre del log group de API Gateway"
  value       = aws_cloudwatch_log_group.api_gateway.name
}

output "dashboard_name" {
  description = "Nombre del dashboard CloudWatch"
  value       = aws_cloudwatch_dashboard.main.dashboard_name
}
