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

variable "api_gateway_url" {
  description = "URL de invocación del API Gateway"
  type        = string
}

variable "api_gateway_stage_name" {
  description = "Nombre del stage de API Gateway"
  type        = string
  default     = "dev"
}

variable "common_tags" {
  type    = map(string)
  default = {}
}
