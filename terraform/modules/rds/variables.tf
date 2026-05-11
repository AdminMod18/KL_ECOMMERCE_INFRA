# =============================================================================
# VARIABLES - Módulo RDS
# =============================================================================

variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "private_subnet_ids" {
  description = "IDs de subnets privadas para RDS"
  type        = list(string)
}

variable "rds_security_group_id" {
  description = "ID del Security Group de RDS"
  type        = string
}

variable "db_instance_class" {
  type    = string
  default = "db.t3.micro"
}

variable "db_engine_version" {
  type    = string
  default = "15.4"
}

variable "db_allocated_storage" {
  type    = number
  default = 20
}

variable "db_name" {
  type = string
}

variable "db_username" {
  type      = string
  sensitive = true
}

variable "db_password" {
  type      = string
  sensitive = true
}

variable "db_multi_az" {
  type    = bool
  default = false
}

variable "db_backup_retention_period" {
  type    = number
  default = 1
}

variable "db_deletion_protection" {
  type    = bool
  default = false
}

variable "common_tags" {
  type    = map(string)
  default = {}
}
