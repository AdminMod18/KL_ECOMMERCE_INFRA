# =============================================================================
# MÓDULO CLOUDWATCH - Logs y Métricas
# Proyecto: KL Ecommerce
# Descripción: Log groups por microservicio, métricas básicas y alarmas
# =============================================================================

locals {
  name_prefix = "${var.project_name}-${var.environment}"
}

# =============================================================================
# LOG GROUPS - Uno por microservicio
# =============================================================================
resource "aws_cloudwatch_log_group" "microservices" {
  for_each = toset(var.microservice_names)

  name              = "/ecs/${var.project_name}/${var.environment}/${each.key}"
  retention_in_days = var.log_retention_days

  tags = merge(var.common_tags, {
    Name    = "${local.name_prefix}-${each.key}-logs"
    Service = each.key
    Type    = "log-group"
  })
}

# =============================================================================
# LOG GROUP - API Gateway
# =============================================================================
resource "aws_cloudwatch_log_group" "api_gateway" {
  name              = "/aws/api-gateway/${local.name_prefix}"
  retention_in_days = var.log_retention_days

  tags = merge(var.common_tags, {
    Name = "${local.name_prefix}-api-gateway-logs"
    Type = "log-group"
  })
}

# =============================================================================
# LOG GROUP - ALB Access Logs (referencia, ALB escribe directamente a S3)
# =============================================================================
resource "aws_cloudwatch_log_group" "alb" {
  name              = "/aws/alb/${local.name_prefix}"
  retention_in_days = var.log_retention_days

  tags = merge(var.common_tags, {
    Name = "${local.name_prefix}-alb-logs"
    Type = "log-group"
  })
}

# =============================================================================
# DASHBOARD CLOUDWATCH - Vista general del sistema
# =============================================================================
resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${local.name_prefix}-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "text"
        x      = 0
        y      = 0
        width  = 24
        height = 1
        properties = {
          markdown = "# KL Ecommerce - ${upper(var.environment)} Dashboard\nMonitoreo de microservicios en ECS Fargate"
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 1
        width  = 12
        height = 6
        properties = {
          title  = "ECS CPU Utilization por Servicio"
          view   = "timeSeries"
          region = var.aws_region
          metrics = [
            for svc in var.microservice_names :
            ["AWS/ECS", "CPUUtilization", "ClusterName", "${local.name_prefix}-cluster", "ServiceName", "${local.name_prefix}-${svc}-svc"]
          ]
          period = 300
          stat   = "Average"
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 1
        width  = 12
        height = 6
        properties = {
          title  = "ECS Memory Utilization por Servicio"
          view   = "timeSeries"
          region = var.aws_region
          metrics = [
            for svc in var.microservice_names :
            ["AWS/ECS", "MemoryUtilization", "ClusterName", "${local.name_prefix}-cluster", "ServiceName", "${local.name_prefix}-${svc}-svc"]
          ]
          period = 300
          stat   = "Average"
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 7
        width  = 12
        height = 6
        properties = {
          title  = "ALB Request Count"
          view   = "timeSeries"
          region = var.aws_region
          metrics = [
            ["AWS/ApplicationELB", "RequestCount", "LoadBalancer", "${local.name_prefix}-alb"]
          ]
          period = 60
          stat   = "Sum"
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 7
        width  = 12
        height = 6
        properties = {
          title  = "ALB Response Time (ms)"
          view   = "timeSeries"
          region = var.aws_region
          metrics = [
            ["AWS/ApplicationELB", "TargetResponseTime", "LoadBalancer", "${local.name_prefix}-alb"]
          ]
          period = 60
          stat   = "Average"
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 13
        width  = 12
        height = 6
        properties = {
          title  = "RDS CPU Utilization"
          view   = "timeSeries"
          region = var.aws_region
          metrics = [
            ["AWS/RDS", "CPUUtilization", "DBInstanceIdentifier", "${local.name_prefix}-postgres"]
          ]
          period = 300
          stat   = "Average"
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 13
        width  = 12
        height = 6
        properties = {
          title  = "RDS Database Connections"
          view   = "timeSeries"
          region = var.aws_region
          metrics = [
            ["AWS/RDS", "DatabaseConnections", "DBInstanceIdentifier", "${local.name_prefix}-postgres"]
          ]
          period = 300
          stat   = "Average"
        }
      }
    ]
  })
}

# =============================================================================
# ALARMAS CLOUDWATCH - Alertas básicas
# =============================================================================

# Alarma: CPU alta en ECS (cualquier servicio)
resource "aws_cloudwatch_metric_alarm" "ecs_cpu_high" {
  for_each = toset(var.microservice_names)

  alarm_name          = "${local.name_prefix}-${each.key}-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "CPU alta en ${each.key} - supera 80%"
  treat_missing_data  = "notBreaching"

  dimensions = {
    ClusterName = "${local.name_prefix}-cluster"
    ServiceName = "${local.name_prefix}-${each.key}-svc"
  }

  tags = merge(var.common_tags, {
    Name    = "${local.name_prefix}-${each.key}-cpu-alarm"
    Service = each.key
  })
}

# Alarma: Memoria alta en ECS
resource "aws_cloudwatch_metric_alarm" "ecs_memory_high" {
  for_each = toset(var.microservice_names)

  alarm_name          = "${local.name_prefix}-${each.key}-memory-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "MemoryUtilization"
  namespace           = "AWS/ECS"
  period              = "300"
  statistic           = "Average"
  threshold           = "85"
  alarm_description   = "Memoria alta en ${each.key} - supera 85%"
  treat_missing_data  = "notBreaching"

  dimensions = {
    ClusterName = "${local.name_prefix}-cluster"
    ServiceName = "${local.name_prefix}-${each.key}-svc"
  }

  tags = merge(var.common_tags, {
    Name    = "${local.name_prefix}-${each.key}-memory-alarm"
    Service = each.key
  })
}

# Alarma: RDS CPU alta
resource "aws_cloudwatch_metric_alarm" "rds_cpu_high" {
  alarm_name          = "${local.name_prefix}-rds-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "CPU alta en RDS PostgreSQL - supera 80%"
  treat_missing_data  = "notBreaching"

  dimensions = {
    DBInstanceIdentifier = "${local.name_prefix}-postgres"
  }

  tags = merge(var.common_tags, {
    Name = "${local.name_prefix}-rds-cpu-alarm"
  })
}

# Alarma: ALB 5xx errors
resource "aws_cloudwatch_metric_alarm" "alb_5xx_errors" {
  alarm_name          = "${local.name_prefix}-alb-5xx-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "HTTPCode_Target_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = "60"
  statistic           = "Sum"
  threshold           = "10"
  alarm_description   = "Errores 5xx en ALB superan 10 en 1 minuto"
  treat_missing_data  = "notBreaching"

  tags = merge(var.common_tags, {
    Name = "${local.name_prefix}-alb-5xx-alarm"
  })
}
