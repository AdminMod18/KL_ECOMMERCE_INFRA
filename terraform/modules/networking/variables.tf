# =============================================================================
# VARIABLES - Módulo Networking
# =============================================================================

variable "project_name" {
  description = "Nombre del proyecto"
  type        = string
}

variable "environment" {
  description = "Entorno de despliegue"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block de la VPC"
  type        = string
}

variable "public_subnet_cidrs" {
  description = "CIDRs de subnets públicas"
  type        = list(string)
}

variable "private_subnet_cidrs" {
  description = "CIDRs de subnets privadas"
  type        = list(string)
}

variable "availability_zones" {
  description = "Zonas de disponibilidad"
  type        = list(string)
}

variable "enable_nat_gateway" {
  description = "Habilitar NAT Gateway"
  type        = bool
  default     = true
}

variable "single_nat_gateway" {
  description = "Usar un solo NAT Gateway"
  type        = bool
  default     = true
}

variable "common_tags" {
  description = "Tags comunes para todos los recursos"
  type        = map(string)
  default     = {}
}
