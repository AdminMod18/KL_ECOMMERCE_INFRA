# =============================================================================
# ENTORNO PROD - Configuración específica
# Proyecto: KL Ecommerce
# Descripción: Entorno de producción con alta disponibilidad y redundancia
# ADVERTENCIA: Recursos más costosos - revisar antes de aplicar
# =============================================================================

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Backend remoto obligatorio en producción
  backend "s3" {
    bucket         = "kl-ecommerce-terraform-state-prod"
    key            = "prod/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "kl-ecommerce-terraform-locks"
  }
}

module "infrastructure" {
  source = "../../"

  # Proyecto
  project_name = "kl-ecommerce"
  environment  = "prod"
  owner        = "ecommerce-team"
  cost_center  = "production"

  # AWS
  aws_region = "us-east-1"

  # Networking - CIDR prod (diferente a dev para evitar conflictos)
  vpc_cidr             = "10.1.0.0/16"
  public_subnet_cidrs  = ["10.1.1.0/24", "10.1.2.0/24"]
  private_subnet_cidrs = ["10.1.10.0/24", "10.1.11.0/24"]
  availability_zones   = ["us-east-1a", "us-east-1b"]
  enable_nat_gateway   = true
  single_nat_gateway   = false  # NAT por AZ en prod (alta disponibilidad)

  # ECS - Mayor capacidad en prod
  ecs_task_cpu    = 512
  ecs_task_memory = 1024
  desired_count   = 2  # 2 réplicas por servicio

  # RDS - Alta disponibilidad en prod
  db_instance_class          = "db.t3.small"
  db_allocated_storage       = 50
  db_name                    = "kl_ecommerce_prod"
  db_username                = "kl_admin"
  db_password                = var.db_password
  db_multi_az                = true   # Multi-AZ en prod
  db_backup_retention_period = 7      # 7 días de backups
  db_deletion_protection     = true   # Protección en prod

  # Frontend
  frontend_bucket_name = "kl-ecommerce-frontend-prod-2024"

  # CloudWatch
  log_retention_days = 30  # 30 días en prod

  # ECR
  ecr_image_count_to_keep = 10  # Más imágenes en prod

  # API Gateway
  api_gateway_stage_name = "prod"
}

variable "db_password" {
  description = "Contraseña de la base de datos de producción"
  type        = string
  sensitive   = true
}
