# =============================================================================
# MÓDULO MONITORING - Observabilidad Avanzada
# Proyecto: KL Ecommerce
# Descripción: Métricas personalizadas, alarmas compuestas y notificaciones
#              SNS para alertas del sistema
# =============================================================================

locals {
  name_prefix = "${var.project_name}-${var.environment}"
}

# =============================================================================
# SNS TOPIC - Notificaciones de alarmas
# =============================================================================
resource "aws_sns_topic" "alerts" {
  name = "${local.name_prefix}-alerts"

  tags = merge(var.common_tags, {
    Name = "${local.name_prefix}-alerts-topic"
    Type = "sns-topic"
  })
}

# Suscripción por email (cambiar email en producción)
resource "aws_sns_topic_subscription" "email" {
  count = var.alert_email != "" ? 1 : 0

  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

# =============================================================================
# COMPOSITE ALARM - Alarma compuesta del sistema
# Se activa si múltiples servicios tienen problemas simultáneos
# =============================================================================
resource "aws_cloudwatch_composite_alarm" "system_health" {
  alarm_name        = "${local.name_prefix}-system-health"
  alarm_description = "Alarma compuesta: sistema con problemas críticos"

  # Se activa si RDS tiene CPU alta Y ALB tiene errores 5xx
  alarm_rule = "ALARM(\"${local.name_prefix}-rds-cpu-high\") AND ALARM(\"${local.name_prefix}-alb-5xx-errors\")"

  alarm_actions = [aws_sns_topic.alerts.arn]
  ok_actions    = [aws_sns_topic.alerts.arn]

  tags = merge(var.common_tags, {
    Name = "${local.name_prefix}-system-health-alarm"
  })
}

# =============================================================================
# METRIC FILTER - Detectar errores en logs de microservicios
# =============================================================================
resource "aws_cloudwatch_log_metric_filter" "error_count" {
  for_each = toset(var.microservice_names)

  name           = "${local.name_prefix}-${each.key}-error-filter"
  pattern        = "[timestamp, level=\"ERROR\", ...]"
  log_group_name = "/ecs/${var.project_name}/${var.environment}/${each.key}"

  metric_transformation {
    name          = "${each.key}-error-count"
    namespace     = "KLEcommerce/${var.environment}"
    value         = "1"
    default_value = "0"
    unit          = "Count"
  }
}

# Alarma basada en errores en logs
resource "aws_cloudwatch_metric_alarm" "log_errors" {
  for_each = toset(var.microservice_names)

  alarm_name          = "${local.name_prefix}-${each.key}-log-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "${each.key}-error-count"
  namespace           = "KLEcommerce/${var.environment}"
  period              = "300"
  statistic           = "Sum"
  threshold           = "10"
  alarm_description   = "Más de 10 errores en logs de ${each.key} en 5 minutos"
  treat_missing_data  = "notBreaching"

  alarm_actions = [aws_sns_topic.alerts.arn]

  tags = merge(var.common_tags, {
    Name    = "${local.name_prefix}-${each.key}-log-errors-alarm"
    Service = each.key
  })
}
