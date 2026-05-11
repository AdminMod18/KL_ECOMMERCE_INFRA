# =============================================================================
# VARIABLES - Módulo IAM
# =============================================================================

variable "project_name" {
  description = "Nombre del proyecto"
  type        = string
}

variable "environment" {
  description = "Entorno de despliegue"
  type        = string
}

variable "aws_region" {
  description = "Región AWS"
  type        = string
}

variable "common_tags" {
  description = "Tags comunes"
  type        = map(string)
  default     = {}
}
