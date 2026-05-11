# =============================================================================
# VARIABLES - Módulo S3
# =============================================================================

variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "frontend_bucket_name" {
  description = "Nombre único del bucket S3 para el frontend"
  type        = string
}

variable "common_tags" {
  type    = map(string)
  default = {}
}
