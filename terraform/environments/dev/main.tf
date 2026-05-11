# =============================================================================
# ENTORNO DEV - Configuración específica
# Proyecto: KL Ecommerce
# Descripción: Entorno de desarrollo con recursos mínimos y bajo costo
# =============================================================================

# Este archivo es un alias que apunta al módulo raíz con variables de dev
# Para usar: cd environments/dev && terraform init && terraform apply

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

module "infrastructure" {
  source = "../../"

  # Proyecto
  project_name = "kl-ecommerce"
  environment  = "dev"
  owner        = "ecommerce-team"
  cost_center  = "demo-university"

  # AWS
  aws_region = "us-east-1"

  # Networking - CIDR dev
  vpc_cidr             = "10.0.0.0/16"
  public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnet_cidrs = ["10.0.10.0/24", "10.0.11.0/24"]
  availability_zones   = ["us-east-1a", "us-east-1b"]
  enable_nat_gateway   = true
  single_nat_gateway   = true  # Un solo NAT en dev

  # ECS - Mínimo en dev
  ecs_task_cpu    = 256
  ecs_task_memory = 512
  desired_count   = 1

  # RDS - Mínimo en dev
  db_instance_class          = "db.t3.micro"
  db_allocated_storage       = 20
  db_name                    = "kl_ecommerce_dev"
  db_username                = "kl_admin"
  db_password                = var.db_password
  db_multi_az                = false
  db_backup_retention_period = 1
  db_deletion_protection     = false

  # Frontend
  frontend_bucket_name = "kl-ecommerce-frontend-dev-2024"

  # CloudWatch
  log_retention_days = 7

  # ECR
  ecr_image_count_to_keep = 3

  # API Gateway
  api_gateway_stage_name = "dev"
}

variable "db_password" {
  description = "Contraseña de la base de datos"
  type        = string
  sensitive   = true
}
