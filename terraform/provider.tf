# =============================================================================
# PROVIDER CONFIGURATION
# Proyecto: KL Ecommerce - Infraestructura Enterprise AWS
# Descripción: Configuración del proveedor AWS y backend de estado Terraform
# =============================================================================

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
  }

  # Backend S3 para estado remoto (descomentar en producción)
  # backend "s3" {
  #   bucket         = "kl-ecommerce-terraform-state"
  #   key            = "infrastructure/terraform.tfstate"
  #   region         = "us-east-1"
  #   encrypt        = true
  #   dynamodb_table = "kl-ecommerce-terraform-locks"
  # }
}

# -----------------------------------------------------------------------------
# Proveedor principal AWS
# -----------------------------------------------------------------------------
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
      Owner       = var.owner
      CostCenter  = var.cost_center
    }
  }
}

# -----------------------------------------------------------------------------
# Proveedor AWS us-east-1 para recursos globales (ACM, CloudFront)
# -----------------------------------------------------------------------------
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
      Owner       = var.owner
      CostCenter  = var.cost_center
    }
  }
}
