# =============================================================================
# VARIABLES - Módulo ECS
# =============================================================================

variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "aws_region" {
  type = string
}

variable "vpc_id" {
  description = "ID de la VPC"
  type        = string
}

variable "private_subnet_ids" {
  description = "IDs de subnets privadas para ECS"
  type        = list(string)
}

variable "ecs_security_group_id" {
  description = "ID del Security Group de ECS"
  type        = string
}

variable "microservices" {
  description = "Configuración de microservicios"
  type = map(object({
    port              = number
    path_prefix       = string
    priority          = number
    cpu               = number
    memory            = number
    health_check_path = string
  }))
}

variable "service_image_tags" {
  description = "Tags de imagen Docker por microservicio"
  type        = map(string)
  default     = {}
}

variable "ecr_repository_urls" {
  description = "URLs de repositorios ECR por microservicio"
  type        = map(string)
}

variable "alb_target_group_arns" {
  description = "ARNs de target groups ALB por microservicio"
  type        = map(string)
}

variable "ecs_task_execution_role_arn" {
  description = "ARN del rol de ejecución de tasks ECS"
  type        = string
}

variable "ecs_task_role_arn" {
  description = "ARN del rol de task ECS"
  type        = string
}

variable "cloudwatch_log_group_names" {
  description = "Nombres de log groups CloudWatch por microservicio"
  type        = map(string)
}

variable "rds_endpoint" {
  description = "Endpoint de RDS"
  type        = string
}

variable "rds_port" {
  description = "Puerto de RDS"
  type        = number
}

variable "db_name" {
  description = "Nombre de la base de datos"
  type        = string
}

variable "db_username" {
  description = "Usuario de la base de datos"
  type        = string
  sensitive   = true
}

variable "db_password" {
  description = "Contraseña de la base de datos"
  type        = string
  sensitive   = true
}

variable "desired_count" {
  description = "Número deseado de tasks por servicio"
  type        = number
  default     = 1
}

variable "common_tags" {
  type    = map(string)
  default = {}
}
