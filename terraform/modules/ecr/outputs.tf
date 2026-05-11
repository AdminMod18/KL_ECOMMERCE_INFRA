# =============================================================================
# OUTPUTS - Módulo ECR
# =============================================================================

output "repository_urls" {
  description = "Mapa de URLs de repositorios ECR por nombre de microservicio"
  value = {
    for name, repo in aws_ecr_repository.microservices :
    name => repo.repository_url
  }
}

output "repository_arns" {
  description = "Mapa de ARNs de repositorios ECR"
  value = {
    for name, repo in aws_ecr_repository.microservices :
    name => repo.arn
  }
}

output "registry_id" {
  description = "ID del registro ECR (Account ID)"
  value       = data.aws_caller_identity.current.account_id
}

output "repository_names" {
  description = "Mapa de nombres de repositorios ECR"
  value = {
    for name, repo in aws_ecr_repository.microservices :
    name => repo.name
  }
}
