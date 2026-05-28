# =============================================================================
# MÓDULO CLOUDFRONT - CDN Global
# Proyecto: KL Ecommerce
# Descripción: Distribución CloudFront con DOS orígenes:
#              1. S3  → frontend React/Vite  (default behavior)
#              2. ALB → microservicios ECS   (behavior /api/*)
#
# ARQUITECTURA:
#   Browser → CloudFront → S3   (rutas estáticas: /, /assets/*, etc.)
#   Browser → CloudFront → ALB  (rutas de API:    /api/*)
#
# NOTA: API Gateway se mantiene como recurso independiente para uso futuro
# (webhooks, auth flows, etc.) pero NO está en el path crítico del frontend.
# =============================================================================

locals {
  name_prefix   = "${var.project_name}-${var.environment}"
  s3_origin_id  = "S3-${var.frontend_bucket_id}"
  alb_origin_id = "ALB-${var.project_name}-${var.environment}"
}

# =============================================================================
# ORIGIN ACCESS CONTROL (OAC) para S3
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

# Cache policy para assets estáticos (JS, CSS, imágenes)
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
# CLOUDFRONT FUNCTION - Strip /api prefix
# Reescribe /api/productos → /productos antes de enviar al ALB.
# Necesario porque Spring Boot no tiene /api como context-path global.
# =============================================================================
resource "aws_cloudfront_function" "strip_api_prefix" {
  name    = "${local.name_prefix}-strip-api-prefix"
  runtime = "cloudfront-js-2.0"
  comment = "Elimina el prefijo /api de la URI antes de enviar al ALB. /api/productos -> /productos"
  publish = true

  code = <<-EOF
    function handler(event) {
      var request = event.request;
      // /api/productos → /productos
      // /api/auth/login → /auth/login
      request.uri = request.uri.replace(/^\/api/, '');
      // Si queda vacío (caso /api sin nada más), poner /
      if (request.uri === '') {
        request.uri = '/';
      }
      return request;
    }
  EOF
}

# =============================================================================
# DISTRIBUCIÓN CLOUDFRONT
# =============================================================================
resource "aws_cloudfront_distribution" "main" {
  enabled             = true
  is_ipv6_enabled     = true
  comment             = "KL Ecommerce CDN - ${var.environment}"
  default_root_object = "index.html"
  price_class         = "PriceClass_100"
  http_version        = "http2and3"

  # ---------------------------------------------------------------------------
  # ORIGEN 1: S3 Frontend (archivos estáticos)
  # ---------------------------------------------------------------------------
  origin {
    domain_name              = var.frontend_bucket_regional_domain
    origin_id                = local.s3_origin_id
    origin_access_control_id = aws_cloudfront_origin_access_control.s3.id

    custom_header {
      name  = "X-CloudFront-Origin"
      value = "s3-frontend"
    }
  }

  # ---------------------------------------------------------------------------
  # ORIGEN 2: ALB (microservicios ECS)
  # CloudFront → ALB puerto 80 (HTTP).
  # El ALB es público (internet-facing) y tiene reglas de routing por path.
  # No se usa HTTPS aquí porque el ALB no tiene certificado ACM en este setup;
  # la conexión CloudFront→usuario sí es HTTPS (viewer_protocol_policy).
  # ---------------------------------------------------------------------------
  origin {
    domain_name = var.alb_dns_name
    origin_id   = local.alb_origin_id

    custom_origin_config {
      http_port                = 80
      https_port               = 443
      origin_protocol_policy   = "http-only"   # ALB sin certificado ACM → HTTP
      origin_ssl_protocols     = ["TLSv1.2"]
      origin_keepalive_timeout = 5
      origin_read_timeout      = 60            # Spring Boot puede tardar en responder
    }

    custom_header {
      name  = "X-CloudFront-Origin"
      value = "alb-backend"
    }
  }

  # ---------------------------------------------------------------------------
  # BEHAVIOR 1: /api/* → ALB (con rewrite de path via CloudFront Function)
  #
  # El browser pide: /api/productos
  # CloudFront Function reescribe: /productos
  # ALB recibe: /productos → regla interna → product-service → 200 JSON
  #
  # Esto es necesario porque Spring Boot NO tiene /api como prefijo global
  # y el ALB no soporta rewrite de paths nativo.
  # ---------------------------------------------------------------------------
  ordered_cache_behavior {
    path_pattern     = "/api/*"
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD", "OPTIONS"]
    target_origin_id = local.alb_origin_id

    # CloudFront Function para eliminar /api del path
    function_association {
      event_type   = "viewer-request"
      function_arn = aws_cloudfront_function.strip_api_prefix.arn
    }

    # Sin cache para APIs dinámicas
    forwarded_values {
      query_string = true
      headers = [
        "Authorization",
        "Content-Type",
        "Accept",
        "Origin",
        "X-Requested-With",
        "Access-Control-Request-Headers",
        "Access-Control-Request-Method",
      ]
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

  # ---------------------------------------------------------------------------
  # BEHAVIOR 2: /assets/* → S3 (cache largo para JS/CSS hasheados)
  # ---------------------------------------------------------------------------
  ordered_cache_behavior {
    path_pattern     = "/assets/*"
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = local.s3_origin_id

    cache_policy_id = aws_cloudfront_cache_policy.frontend.id

    viewer_protocol_policy = "redirect-to-https"
    compress               = true
  }

  # ---------------------------------------------------------------------------
  # BEHAVIOR DEFAULT: S3 Frontend (React SPA)
  # Todas las rutas no capturadas por los behaviors anteriores van a S3.
  # ---------------------------------------------------------------------------
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
    default_ttl            = 3600
    max_ttl                = 86400
    compress               = true
  }

  # ---------------------------------------------------------------------------
  # CUSTOM ERROR RESPONSES - React Router SPA
  # S3 devuelve 403/404 para rutas SPA → CloudFront sirve index.html
  # IMPORTANTE: solo aplica al origen S3, no al ALB.
  # ---------------------------------------------------------------------------
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

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
    minimum_protocol_version       = "TLSv1.2_2021"
  }

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
