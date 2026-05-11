# =============================================================================
# MÓDULO CLOUDFRONT - CDN Global
# Proyecto: KL Ecommerce
# Descripción: Distribución CloudFront con dos orígenes:
#              1. S3 para el frontend React/Vite
#              2. API Gateway para las llamadas /api/*
# =============================================================================

locals {
  name_prefix          = "${var.project_name}-${var.environment}"
  s3_origin_id         = "S3-${var.frontend_bucket_id}"
  api_gateway_origin_id = "APIGateway-${var.project_name}"
}

# =============================================================================
# ORIGIN ACCESS CONTROL (OAC) para S3
# Reemplaza el antiguo OAI - más seguro y moderno
# =============================================================================
resource "aws_cloudfront_origin_access_control" "s3" {
  name                              = "${local.name_prefix}-s3-oac"
  description                       = "OAC para acceso seguro de CloudFront a S3 frontend"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# =============================================================================
# CACHE POLICIES
# =============================================================================

# Cache policy para el frontend (archivos estáticos)
resource "aws_cloudfront_cache_policy" "frontend" {
  name        = "${local.name_prefix}-frontend-cache-policy"
  comment     = "Cache policy para assets estáticos del frontend React/Vite"
  default_ttl = 86400    # 1 día
  max_ttl     = 31536000 # 1 año
  min_ttl     = 0

  parameters_in_cache_key_and_forwarded_to_origin {
    cookies_config {
      cookie_behavior = "none"
    }
    headers_config {
      header_behavior = "none"
    }
    query_strings_config {
      query_string_behavior = "none"
    }
    enable_accept_encoding_brotli = true
    enable_accept_encoding_gzip   = true
  }
}

# =============================================================================
# DISTRIBUCIÓN CLOUDFRONT
# =============================================================================
resource "aws_cloudfront_distribution" "main" {
  enabled             = true
  is_ipv6_enabled     = true
  comment             = "KL Ecommerce CDN - ${var.environment}"
  default_root_object = "index.html"
  price_class         = "PriceClass_100"  # Solo US, Canada, Europa (menor costo)
  http_version        = "http2and3"

  # -------------------------------------------------------------------------
  # ORIGEN 1: S3 Frontend
  # -------------------------------------------------------------------------
  origin {
    domain_name              = var.frontend_bucket_regional_domain
    origin_id                = local.s3_origin_id
    origin_access_control_id = aws_cloudfront_origin_access_control.s3.id

    # Custom headers para identificar origen CloudFront
    custom_header {
      name  = "X-CloudFront-Origin"
      value = "s3-frontend"
    }
  }

  # -------------------------------------------------------------------------
  # ORIGEN 2: API Gateway
  # Extrae el dominio del URL del API Gateway (ej: abc123.execute-api.us-east-1.amazonaws.com)
  # -------------------------------------------------------------------------
  origin {
    # El URL del API Gateway tiene formato: https://{id}.execute-api.{region}.amazonaws.com/{stage}
    # Necesitamos solo el dominio sin https:// y sin el path del stage
    domain_name = regex("https://([^/]+)", var.api_gateway_url)[0]
    origin_id   = local.api_gateway_origin_id
    origin_path = "/${var.api_gateway_stage_name}"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "https-only"
      origin_ssl_protocols   = ["TLSv1.2"]

      # Timeouts
      origin_keepalive_timeout = 5
      origin_read_timeout      = 30
    }

    custom_header {
      name  = "X-CloudFront-Origin"
      value = "api-gateway"
    }
  }

  # -------------------------------------------------------------------------
  # BEHAVIOR: /api/* → API Gateway
  # -------------------------------------------------------------------------
  ordered_cache_behavior {
    path_pattern     = "/api/*"
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD", "OPTIONS"]
    target_origin_id = local.api_gateway_origin_id

    # Sin cache para API (datos dinámicos)
    forwarded_values {
      query_string = true
      headers      = ["Authorization", "Content-Type", "Accept", "Origin", "X-Requested-With"]

      cookies {
        forward = "all"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 0
    max_ttl                = 0
    compress               = true
  }

  # -------------------------------------------------------------------------
  # BEHAVIOR: /assets/* → S3 (archivos estáticos con cache largo)
  # -------------------------------------------------------------------------
  ordered_cache_behavior {
    path_pattern     = "/assets/*"
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = local.s3_origin_id

    cache_policy_id = aws_cloudfront_cache_policy.frontend.id

    viewer_protocol_policy = "redirect-to-https"
    compress               = true
  }

  # -------------------------------------------------------------------------
  # BEHAVIOR DEFAULT: S3 Frontend (React SPA)
  # -------------------------------------------------------------------------
  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = local.s3_origin_id

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 3600   # 1 hora para HTML
    max_ttl                = 86400  # 1 día máximo
    compress               = true
  }

  # -------------------------------------------------------------------------
  # CUSTOM ERROR RESPONSES - SPA React Router
  # Redirige errores 403/404 de S3 a index.html para React Router
  # -------------------------------------------------------------------------
  custom_error_response {
    error_code            = 403
    response_code         = 200
    response_page_path    = "/index.html"
    error_caching_min_ttl = 0
  }

  custom_error_response {
    error_code            = 404
    response_code         = 200
    response_page_path    = "/index.html"
    error_caching_min_ttl = 0
  }

  # -------------------------------------------------------------------------
  # RESTRICCIONES GEO (ninguna para demo)
  # -------------------------------------------------------------------------
  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  # -------------------------------------------------------------------------
  # CERTIFICADO SSL (CloudFront default)
  # Para dominio personalizado, usar ACM en us-east-1
  # -------------------------------------------------------------------------
  viewer_certificate {
    cloudfront_default_certificate = true
    minimum_protocol_version       = "TLSv1.2_2021"
  }

  # -------------------------------------------------------------------------
  # LOGGING (deshabilitado en demo para reducir costos)
  # -------------------------------------------------------------------------
  # logging_config {
  #   include_cookies = false
  #   bucket          = "${var.project_name}-cloudfront-logs.s3.amazonaws.com"
  #   prefix          = "cloudfront/"
  # }

  tags = merge(var.common_tags, {
    Name = "${local.name_prefix}-cloudfront"
    Type = "cloudfront-distribution"
  })
}

# =============================================================================
# BUCKET POLICY - Permitir acceso de CloudFront al S3
# =============================================================================
data "aws_caller_identity" "current" {}

resource "aws_s3_bucket_policy" "frontend" {
  bucket = var.frontend_bucket_id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCloudFrontServicePrincipal"
        Effect = "Allow"
        Principal = {
          Service = "cloudfront.amazonaws.com"
        }
        Action   = "s3:GetObject"
        Resource = "arn:aws:s3:::${var.frontend_bucket_id}/*"
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = aws_cloudfront_distribution.main.arn
          }
        }
      }
    ]
  })
}
