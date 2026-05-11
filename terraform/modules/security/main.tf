# =============================================================================
# MÓDULO SECURITY - Políticas de Seguridad Adicionales
# Proyecto: KL Ecommerce
# Descripción: Políticas de bucket S3, configuraciones de seguridad
#              y preparación para WAF (futuro)
# =============================================================================

locals {
  name_prefix = "${var.project_name}-${var.environment}"
}

# =============================================================================
# S3 BUCKET POLICY - Denegar acceso no cifrado
# =============================================================================
# Nota: La política principal de CloudFront se aplica en el módulo cloudfront
# Aquí agregamos políticas de seguridad adicionales

# =============================================================================
# AWS CONFIG RULE - Verificar que S3 tiene cifrado habilitado
# (Comentado para demo - requiere AWS Config habilitado)
# =============================================================================
# resource "aws_config_config_rule" "s3_bucket_ssl_requests_only" {
#   name = "${local.name_prefix}-s3-ssl-only"
#   source {
#     owner             = "AWS"
#     source_identifier = "S3_BUCKET_SSL_REQUESTS_ONLY"
#   }
# }

# =============================================================================
# SECRETS MANAGER - Almacenamiento seguro de secretos de aplicación
# =============================================================================
resource "aws_secretsmanager_secret" "app_secrets" {
  name        = "${local.name_prefix}/app-secrets"
  description = "Secretos de aplicación para KL Ecommerce"

  # Rotación automática (deshabilitada en demo)
  # rotation_lambda_arn = ""

  # Recuperación inmediata en demo (sin período de recuperación)
  recovery_window_in_days = 0

  tags = merge(var.common_tags, {
    Name = "${local.name_prefix}-app-secrets"
    Type = "secrets-manager"
  })
}

resource "aws_secretsmanager_secret_version" "app_secrets" {
  secret_id = aws_secretsmanager_secret.app_secrets.id

  secret_string = jsonencode({
    jwt_secret        = "CHANGE_ME_IN_PRODUCTION_${random_string.jwt_secret.result}"
    jwt_expiration    = "86400"
    app_environment   = var.environment
    cors_allowed_origins = "*"
  })
}

# String aleatorio para JWT secret (solo demo)
resource "random_string" "jwt_secret" {
  length  = 32
  special = true
}

# =============================================================================
# SSM PARAMETER STORE - Configuración de aplicación
# =============================================================================
resource "aws_ssm_parameter" "jwt_secret" {
  name        = "/${var.project_name}/${var.environment}/app/jwt-secret"
  description = "JWT Secret para autenticación"
  type        = "SecureString"
  value       = "CHANGE_ME_IN_PRODUCTION_${random_string.jwt_secret.result}"

  tags = merge(var.common_tags, {
    Name = "${local.name_prefix}-jwt-secret"
    Type = "ssm-parameter"
  })
}

resource "aws_ssm_parameter" "app_environment" {
  name        = "/${var.project_name}/${var.environment}/app/environment"
  description = "Entorno de la aplicación"
  type        = "String"
  value       = var.environment

  tags = merge(var.common_tags, {
    Name = "${local.name_prefix}-app-environment"
  })
}

resource "aws_ssm_parameter" "cors_origins" {
  name        = "/${var.project_name}/${var.environment}/app/cors-origins"
  description = "Orígenes CORS permitidos"
  type        = "String"
  value       = "*"  # En producción: reemplazar con el dominio CloudFront real

  tags = merge(var.common_tags, {
    Name = "${local.name_prefix}-cors-origins"
  })
}

# =============================================================================
# PREPARACIÓN PARA WAF (Web Application Firewall)
# Comentado para demo - habilitar en producción
# =============================================================================
# resource "aws_wafv2_web_acl" "main" {
#   name  = "${local.name_prefix}-waf"
#   scope = "CLOUDFRONT"
#
#   default_action {
#     allow {}
#   }
#
#   rule {
#     name     = "AWSManagedRulesCommonRuleSet"
#     priority = 1
#
#     override_action {
#       none {}
#     }
#
#     statement {
#       managed_rule_group_statement {
#         name        = "AWSManagedRulesCommonRuleSet"
#         vendor_name = "AWS"
#       }
#     }
#
#     visibility_config {
#       cloudwatch_metrics_enabled = true
#       metric_name                = "AWSManagedRulesCommonRuleSetMetric"
#       sampled_requests_enabled   = true
#     }
#   }
#
#   visibility_config {
#     cloudwatch_metrics_enabled = true
#     metric_name                = "${local.name_prefix}-waf-metric"
#     sampled_requests_enabled   = true
#   }
# }
