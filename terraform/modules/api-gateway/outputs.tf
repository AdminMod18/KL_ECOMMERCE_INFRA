# =============================================================================
# OUTPUTS - Módulo API Gateway
# =============================================================================

output "api_id" {
  description = "ID del REST API"
  value       = aws_api_gateway_rest_api.main.id
}

output "api_arn" {
  description = "ARN del REST API"
  value       = aws_api_gateway_rest_api.main.arn
}

output "api_url" {
  description = "URL de invocación del API Gateway"
  value       = aws_api_gateway_stage.main.invoke_url
}

output "api_execution_arn" {
  description = "ARN de ejecución del API Gateway"
  value       = aws_api_gateway_rest_api.main.execution_arn
}

output "stage_name" {
  description = "Nombre del stage desplegado"
  value       = aws_api_gateway_stage.main.stage_name
}

output "deployment_id" {
  description = "ID del deployment"
  value       = aws_api_gateway_deployment.main.id
}
