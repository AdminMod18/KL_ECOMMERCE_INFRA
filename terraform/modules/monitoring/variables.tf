# =============================================================================
# VARIABLES - Módulo Monitoring
# =============================================================================

variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "microservice_names" {
  description = "Lista de nombres de microservicios"
  type        = list(string)
}

variable "alert_email" {
  description = "Email para recibir alertas (dejar vacío para deshabilitar)"
  type        = string
  default     = ""
}

variable "common_tags" {
  type    = map(string)
  default = {}
}
