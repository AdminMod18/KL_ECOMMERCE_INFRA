# =============================================================================
# VARIABLES - Módulo Security
# =============================================================================

variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "frontend_bucket_name" {
  description = "Nombre del bucket S3 del frontend"
  type        = string
}

variable "frontend_bucket_arn" {
  description = "ARN del bucket S3 del frontend"
  type        = string
}

variable "cloudfront_distribution_arn" {
  description = "ARN de la distribución CloudFront"
  type        = string
}

variable "common_tags" {
  type    = map(string)
  default = {}
}
