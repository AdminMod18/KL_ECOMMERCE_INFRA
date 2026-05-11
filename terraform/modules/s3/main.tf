# =============================================================================
# MÓDULO S3 - Frontend React/Vite
# Proyecto: KL Ecommerce
# Descripción: Bucket S3 para hosting estático del frontend
#              Configurado para CloudFront (no acceso público directo)
# =============================================================================

locals {
  name_prefix = "${var.project_name}-${var.environment}"
}

# =============================================================================
# BUCKET S3 - Frontend
# =============================================================================
resource "aws_s3_bucket" "frontend" {
  bucket = var.frontend_bucket_name

  tags = merge(var.common_tags, {
    Name    = var.frontend_bucket_name
    Type    = "frontend-bucket"
    Purpose = "React/Vite SPA hosting"
  })
}

# Bloquear acceso público directo (CloudFront es el único origen)
resource "aws_s3_bucket_public_access_block" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Versionado del bucket (útil para rollbacks)
resource "aws_s3_bucket_versioning" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Cifrado del bucket
resource "aws_s3_bucket_server_side_encryption_configuration" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

# Configuración de website (necesaria para SPA con React Router)
resource "aws_s3_bucket_website_configuration" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  index_document {
    suffix = "index.html"
  }

  # Redirigir errores 404 a index.html para React Router (SPA)
  error_document {
    key = "index.html"
  }
}

# CORS para desarrollo local
resource "aws_s3_bucket_cors_configuration" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET", "HEAD"]
    allowed_origins = ["*"]
    expose_headers  = ["ETag"]
    max_age_seconds = 3000
  }
}

# Lifecycle policy para limpiar versiones antiguas
resource "aws_s3_bucket_lifecycle_configuration" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  rule {
    id     = "cleanup-old-versions"
    status = "Enabled"

    noncurrent_version_expiration {
      noncurrent_days = 30
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

# =============================================================================
# BUCKET S3 - Logs de ALB (opcional, para producción)
# =============================================================================
resource "aws_s3_bucket" "alb_logs" {
  bucket = "${var.frontend_bucket_name}-alb-logs"

  tags = merge(var.common_tags, {
    Name    = "${local.name_prefix}-alb-logs"
    Type    = "alb-logs-bucket"
    Purpose = "ALB access logs storage"
  })
}

resource "aws_s3_bucket_public_access_block" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id

  rule {
    id     = "expire-old-logs"
    status = "Enabled"

    expiration {
      days = 30
    }
  }
}
