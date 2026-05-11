# =============================================================================
# OUTPUTS - Módulo Security
# =============================================================================

output "app_secrets_arn" {
  description = "ARN del secreto en Secrets Manager"
  value       = aws_secretsmanager_secret.app_secrets.arn
}

output "jwt_secret_ssm_arn" {
  description = "ARN del parámetro SSM del JWT secret"
  value       = aws_ssm_parameter.jwt_secret.arn
}
