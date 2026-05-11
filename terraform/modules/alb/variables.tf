# =============================================================================
# VARIABLES - Módulo ALB
# =============================================================================

variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "vpc_id" {
  description = "ID de la VPC"
  type        = string
}

variable "public_subnet_ids" {
  description = "IDs de subnets públicas para el ALB"
  type        = list(string)
}

variable "alb_security_group_id" {
  description = "ID del Security Group del ALB"
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

variable "common_tags" {
  type    = map(string)
  default = {}
}
