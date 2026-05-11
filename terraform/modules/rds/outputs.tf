# =============================================================================
# OUTPUTS - Módulo RDS
# =============================================================================

output "db_endpoint" {
  description = "Endpoint de conexión RDS (host:port)"
  value       = aws_db_instance.main.endpoint
}

output "db_host" {
  description = "Host de RDS (sin puerto)"
  value       = aws_db_instance.main.address
}

output "db_port" {
  description = "Puerto de RDS"
  value       = aws_db_instance.main.port
}

output "db_name" {
  description = "Nombre de la base de datos"
  value       = aws_db_instance.main.db_name
}

output "db_instance_id" {
  description = "ID de la instancia RDS"
  value       = aws_db_instance.main.id
}

output "db_instance_arn" {
  description = "ARN de la instancia RDS"
  value       = aws_db_instance.main.arn
}

output "db_subnet_group_name" {
  description = "Nombre del subnet group de RDS"
  value       = aws_db_subnet_group.main.name
}

output "ssm_db_password_arn" {
  description = "ARN del parámetro SSM con la contraseña de BD"
  value       = aws_ssm_parameter.db_password.arn
}
