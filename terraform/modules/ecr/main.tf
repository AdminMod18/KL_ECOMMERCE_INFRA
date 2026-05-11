# =============================================================================
# MÓDULO ECR - Elastic Container Registry
# Proyecto: KL Ecommerce
# Descripción: Repositorios ECR para todos los microservicios con
#              lifecycle policies para gestión automática de imágenes
# =============================================================================

locals {
  name_prefix = "${var.project_name}-${var.environment}"
}

# =============================================================================
# REPOSITORIOS ECR - Uno por microservicio
# =============================================================================
resource "aws_ecr_repository" "microservices" {
  for_each = toset(var.microservice_names)

  name                 = "${local.name_prefix}/${each.key}"
  image_tag_mutability = "MUTABLE" # Permite sobreescribir tags (útil para 'latest')

  # Escaneo de vulnerabilidades en cada push
  image_scanning_configuration {
    scan_on_push = true
  }

  # Cifrado con KMS (usa clave AWS gestionada por defecto)
  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = merge(var.common_tags, {
    Name        = "${local.name_prefix}-${each.key}-ecr"
    Service     = each.key
    Type        = "ecr-repository"
  })
}

# =============================================================================
# LIFECYCLE POLICIES - Gestión automática de imágenes
# Conserva solo las últimas N imágenes y elimina las antiguas
# Reduce costos de almacenamiento en ECR
# =============================================================================
resource "aws_ecr_lifecycle_policy" "microservices" {
  for_each   = aws_ecr_repository.microservices
  repository = each.value.name

  policy = jsonencode({
    rules = [
      {
        # Regla 1: Mantener solo las últimas N imágenes con tag
        rulePriority = 1
        description  = "Mantener las últimas ${var.ecr_image_count_to_keep} imágenes con tag"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["v", "release", "latest"]
          countType     = "imageCountMoreThan"
          countNumber   = var.ecr_image_count_to_keep
        }
        action = {
          type = "expire"
        }
      },
      {
        # Regla 2: Eliminar imágenes sin tag después de 1 día
        rulePriority = 2
        description  = "Eliminar imágenes sin tag después de 1 día"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 1
        }
        action = {
          type = "expire"
        }
      },
      {
        # Regla 3: Mantener máximo 10 imágenes en total (cualquier tag)
        rulePriority = 3
        description  = "Máximo 10 imágenes totales por repositorio"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 10
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

# =============================================================================
# REPOSITORY POLICY - Control de acceso al repositorio
# Permite acceso desde la cuenta AWS actual
# =============================================================================
data "aws_caller_identity" "current" {}

resource "aws_ecr_repository_policy" "microservices" {
  for_each   = aws_ecr_repository.microservices
  repository = each.value.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowPushPull"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action = [
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:BatchCheckLayerAvailability",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:DescribeRepositories",
          "ecr:GetRepositoryPolicy",
          "ecr:ListImages",
          "ecr:DeleteRepository",
          "ecr:BatchDeleteImage",
          "ecr:SetRepositoryPolicy",
          "ecr:DeleteRepositoryPolicy"
        ]
      }
    ]
  })
}
