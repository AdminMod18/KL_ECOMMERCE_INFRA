# =============================================================================
# OUTPUTS GLOBALES
# Proyecto: KL Ecommerce - Infraestructura Enterprise AWS
# Descripción: Expone los valores clave de la infraestructura desplegada
# =============================================================================

# -----------------------------------------------------------------------------
# Networking Outputs
# -----------------------------------------------------------------------------
output "vpc_id" {
  description = "ID de la VPC principal"
  value       = module.networking.vpc_id
}

output "vpc_cidr" {
  description = "CIDR block de la VPC"
  value       = module.networking.vpc_cidr
}

output "public_subnet_ids" {
  description = "IDs de las subnets públicas"
  value       = module.networking.public_subnet_ids
}

output "private_subnet_ids" {
  description = "IDs de las subnets privadas"
  value       = module.networking.private_subnet_ids
}

output "nat_gateway_ip" {
  description = "IP pública del NAT Gateway"
  value       = module.networking.nat_gateway_ip
}

# -----------------------------------------------------------------------------
# ECR Outputs
# -----------------------------------------------------------------------------
output "ecr_repository_urls" {
  description = "URLs de todos los repositorios ECR por microservicio"
  value       = module.ecr.repository_urls
}

output "ecr_registry_id" {
  description = "ID del registro ECR"
  value       = module.ecr.registry_id
}

# -----------------------------------------------------------------------------
# ECS Outputs
# -----------------------------------------------------------------------------
output "ecs_cluster_name" {
  description = "Nombre del cluster ECS"
  value       = module.ecs.cluster_name
}

output "ecs_cluster_arn" {
  description = "ARN del cluster ECS"
  value       = module.ecs.cluster_arn
}

output "ecs_service_names" {
  description = "Nombres de todos los servicios ECS desplegados"
  value       = module.ecs.service_names
}

# -----------------------------------------------------------------------------
# ALB Outputs
# -----------------------------------------------------------------------------
output "alb_dns_name" {
  description = "DNS del Application Load Balancer (punto de entrada backend)"
  value       = module.alb.alb_dns_name
}

output "alb_arn" {
  description = "ARN del Application Load Balancer"
  value       = module.alb.alb_arn
}

output "alb_zone_id" {
  description = "Zone ID del ALB para Route53"
  value       = module.alb.alb_zone_id
}

# -----------------------------------------------------------------------------
# API Gateway Outputs
# -----------------------------------------------------------------------------
output "api_gateway_url" {
  description = "URL del API Gateway (endpoint de invocación)"
  value       = module.api_gateway.api_url
}

output "api_gateway_url_with_path" {
  description = "URL del API Gateway con path /api. Usar como VITE_API_URL en el build del frontend."
  value       = module.api_gateway.api_url_with_path
}

output "api_gateway_id" {
  description = "ID del API Gateway REST API"
  value       = module.api_gateway.api_id
}

# -----------------------------------------------------------------------------
# CloudFront Outputs
# -----------------------------------------------------------------------------
output "cloudfront_url" {
  description = "URL del dominio CloudFront (punto de entrada principal del frontend)"
  value       = "https://${module.cloudfront.cloudfront_domain_name}"
}

output "cloudfront_api_url" {
  description = "URL pública de la API via CloudFront. Usar como VITE_API_URL en el build del frontend. Formato: https://<domain>/api"
  value       = module.cloudfront.cloudfront_api_url
}

output "cloudfront_domain_name" {
  description = "Nombre de dominio CloudFront"
  value       = module.cloudfront.cloudfront_domain_name
}

output "cloudfront_distribution_id" {
  description = "ID de la distribución CloudFront (necesario para invalidar cache tras deploy)"
  value       = module.cloudfront.distribution_id
}

# -----------------------------------------------------------------------------
# S3 Outputs
# -----------------------------------------------------------------------------
output "frontend_bucket_name" {
  description = "Nombre del bucket S3 del frontend"
  value       = module.s3.frontend_bucket_name
}

output "frontend_bucket_arn" {
  description = "ARN del bucket S3 del frontend"
  value       = module.s3.frontend_bucket_arn
}

output "frontend_bucket_regional_domain" {
  description = "Dominio regional del bucket S3 para CloudFront"
  value       = module.s3.frontend_bucket_regional_domain
}

# -----------------------------------------------------------------------------
# RDS Outputs
# -----------------------------------------------------------------------------
output "rds_endpoint" {
  description = "Endpoint de conexión a RDS PostgreSQL"
  value       = module.rds.db_endpoint
  sensitive   = false
}

output "rds_port" {
  description = "Puerto de RDS PostgreSQL"
  value       = module.rds.db_port
}

output "rds_database_name" {
  description = "Nombre de la base de datos"
  value       = module.rds.db_name
}

# -----------------------------------------------------------------------------
# IAM Outputs
# -----------------------------------------------------------------------------
output "ecs_task_execution_role_arn" {
  description = "ARN del rol de ejecución de tasks ECS"
  value       = module.iam.ecs_task_execution_role_arn
}

output "ecs_task_role_arn" {
  description = "ARN del rol de task ECS"
  value       = module.iam.ecs_task_role_arn
}

# -----------------------------------------------------------------------------
# CloudWatch Outputs
# -----------------------------------------------------------------------------
output "cloudwatch_log_group_names" {
  description = "Nombres de los log groups de CloudWatch por microservicio"
  value       = module.cloudwatch.log_group_names
}

# -----------------------------------------------------------------------------
# Security Groups Outputs
# -----------------------------------------------------------------------------
output "alb_security_group_id" {
  description = "ID del Security Group del ALB"
  value       = module.networking.alb_security_group_id
}

output "ecs_security_group_id" {
  description = "ID del Security Group de ECS"
  value       = module.networking.ecs_security_group_id
}

output "rds_security_group_id" {
  description = "ID del Security Group de RDS"
  value       = module.networking.rds_security_group_id
}

# -----------------------------------------------------------------------------
# Resumen de Acceso
# -----------------------------------------------------------------------------
output "access_summary" {
  description = "Resumen de URLs de acceso a la infraestructura"
  value = {
    frontend_url        = "https://${module.cloudfront.cloudfront_domain_name}"
    # VITE_API_URL para el build del frontend (CloudFront proxea /api/* a API Gateway → ALB)
    frontend_api_url    = module.cloudfront.cloudfront_api_url
    api_gateway_url     = module.api_gateway.api_url
    alb_dns_name        = module.alb.alb_dns_name
    alb_url             = "http://${module.alb.alb_dns_name}"
    rds_endpoint        = module.rds.db_endpoint
    ecs_cluster         = module.ecs.cluster_name
    cloudfront_dist_id  = module.cloudfront.distribution_id
  }
}
