# =============================================================================
# VARIABLES - Módulo ECR
# =============================================================================

variable "project_name" {
  description = "Nombre del proyecto"
  type        = string
}

variable "environment" {
  description = "Entorno de despliegue"
  type        = string
}

variable "microservice_names" {
  description = "Lista de nombres de microservicios para crear repositorios"
  type        = list(string)
}

variable "ecr_image_count_to_keep" {
  description = "Número de imágenes a conservar por repositorio"
  type        = number
  default     = 3
}

variable "common_tags" {
  description = "Tags comunes"
  type        = map(string)
  default     = {}
}
