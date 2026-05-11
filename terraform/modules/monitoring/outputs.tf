# =============================================================================
# OUTPUTS - Módulo Monitoring
# =============================================================================

output "sns_topic_arn" {
  description = "ARN del topic SNS de alertas"
  value       = aws_sns_topic.alerts.arn
}

output "sns_topic_name" {
  description = "Nombre del topic SNS"
  value       = aws_sns_topic.alerts.name
}
