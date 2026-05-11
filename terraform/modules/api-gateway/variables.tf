# =============================================================================
# VARIABLES - Módulo API Gateway
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

variable "alb_dns_name" {
  description = "DNS del ALB para integración HTTP_PROXY"
  type        = string
}

variable "alb_listener_arn" {
  description = "ARN del listener del ALB"
  type        = string
}

variable "vpc_id" {
  description = "ID de la VPC"
  type        = string
}

variable "private_subnet_ids" {
  description = "IDs de subnets privadas"
  type        = list(string)
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

variable "api_gateway_stage_name" {
  description = "Nombre del stage de API Gateway"
  type        = string
  default     = "dev"
}

variable "api_gateway_logging_level" {
  description = "Nivel de logging (OFF, ERROR, INFO)"
  type        = string
  default     = "INFO"
}

variable "common_tags" {
  type    = map(string)
  default = {}
}
