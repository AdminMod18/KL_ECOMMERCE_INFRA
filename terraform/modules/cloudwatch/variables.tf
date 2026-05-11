# =============================================================================
# VARIABLES - Módulo CloudWatch
# =============================================================================

variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "aws_region" {
  description = "Región AWS"
  type        = string
  default     = "us-east-1"
}

variable "microservice_names" {
  description = "Lista de nombres de microservicios"
  type        = list(string)
}

variable "log_retention_days" {
  description = "Días de retención de logs"
  type        = number
  default     = 7
}

variable "common_tags" {
  type    = map(string)
  default = {}
}
