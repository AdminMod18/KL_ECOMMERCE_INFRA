# =============================================================================
# VARIABLES - Módulo CloudFront
# =============================================================================

variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "frontend_bucket_regional_domain" {
  description = "Dominio regional del bucket S3 del frontend"
  type        = string
}

variable "frontend_bucket_id" {
  description = "ID (nombre) del bucket S3 del frontend"
  type        = string
}

variable "alb_dns_name" {
  description = "DNS público del ALB. Origen CloudFront para el behavior /api/*. Ej: kl-ecommerce-prod-alb-985321400.us-east-2.elb.amazonaws.com"
  type        = string
}

# api_gateway_url se mantiene como variable opcional para no romper
# referencias externas, pero ya no se usa como origen de CloudFront.
# CloudFront apunta directamente al ALB para /api/*.
variable "api_gateway_url" {
  description = "URL del API Gateway (no usado como origen CloudFront; mantenido para compatibilidad de outputs)"
  type        = string
  default     = ""
}

variable "api_gateway_stage_name" {
  description = "Nombre del stage de API Gateway"
  type        = string
  default     = "prod"
}

variable "common_tags" {
  type    = map(string)
  default = {}
}
