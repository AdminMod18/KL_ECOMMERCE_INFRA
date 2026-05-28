# =============================================================================
# MÓDULO ALB - Application Load Balancer
# Proyecto: KL Ecommerce
# Descripción: ALB con listeners, target groups y routing rules
#              para todos los microservicios Spring Boot
# =============================================================================

locals {
  name_prefix = "${var.project_name}-${var.environment}"
}

# =============================================================================
# APPLICATION LOAD BALANCER
# =============================================================================
resource "aws_lb" "main" {
  name               = "${local.name_prefix}-alb"
  internal           = false  # Público para recibir tráfico de API Gateway
  load_balancer_type = "application"
  security_groups    = [var.alb_security_group_id]
  subnets            = var.public_subnet_ids

  # Protección contra eliminación accidental
  enable_deletion_protection = false  # false en demo para facilitar terraform destroy

  # Logs de acceso (deshabilitado en demo para reducir costos)
  # access_logs {
  #   bucket  = "kl-ecommerce-alb-logs"
  #   prefix  = "alb"
  #   enabled = true
  # }

  tags = merge(var.common_tags, {
    Name = "${local.name_prefix}-alb"
    Type = "application-load-balancer"
  })
}

# =============================================================================
# TARGET GROUPS - Uno por microservicio
# =============================================================================
resource "aws_lb_target_group" "microservices" {
  for_each = var.microservices

  # AWS limit: 32 chars max. Use short env prefix + service abbreviation + hash suffix
  # Format: <env>-<8-char-service>-<6-char-hash>-tg  (stays under 32)
  name        = "${var.environment}-${substr(each.key, 0, 8)}-${substr(md5(each.key), 0, 6)}-tg"
  port        = each.value.port
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"  # Requerido para ECS Fargate

  # Health check para Spring Boot Actuator
  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 10
    interval            = 30
    path                = each.value.health_check_path
    protocol            = "HTTP"
    matcher             = "200"
  }

  # Deregistration delay reducido para despliegues más rápidos
  deregistration_delay = 30

  tags = merge(var.common_tags, {
    Name    = "${local.name_prefix}-${each.key}-tg"
    Service = each.key
    Port    = tostring(each.value.port)
    Type    = "target-group"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# =============================================================================
# LISTENER HTTP - Puerto 80
# Redirige a HTTPS o maneja tráfico directo (demo sin SSL)
# =============================================================================
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = "80"
  protocol          = "HTTP"

  # Acción por defecto: respuesta 404 para rutas no mapeadas
  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "application/json"
      message_body = jsonencode({
        error   = "Not Found"
        message = "Ruta no encontrada en KL Ecommerce API"
        status  = 404
      })
      status_code = "404"
    }
  }

  tags = merge(var.common_tags, {
    Name = "${local.name_prefix}-http-listener"
  })
}

# =============================================================================
# LISTENER RULES - Routing por path prefix
# Cada microservicio tiene DOS reglas:
#   1. /api{path_prefix}/* y /api{path_prefix}  → para tráfico desde CloudFront
#   2. {path_prefix}/* y {path_prefix}           → para tráfico interno VPC
#
# CloudFront envía /api/productos → ALB recibe /api/productos
# La regla /api/products/* captura eso y lo manda al product-service.
# El microservicio Spring Boot tiene server.servlet.context-path=/products
# por lo que el ALB debe reescribir /api/products/... → /products/...
# Esto se hace con un forward simple; Spring Boot recibe la URL completa
# y la maneja según su context-path configurado.
# =============================================================================

# Reglas para tráfico desde CloudFront (/api/{path_prefix}/*)
resource "aws_lb_listener_rule" "microservices_api" {
  for_each = var.microservices

  listener_arn = aws_lb_listener.http.arn
  # Prioridad offset +200 para no colisionar con las reglas directas
  priority = each.value.priority + 200

  condition {
    path_pattern {
      values = [
        "/api${each.value.path_prefix}",
        "/api${each.value.path_prefix}/*",
      ]
    }
  }

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.microservices[each.key].arn
  }

  tags = merge(var.common_tags, {
    Name    = "${local.name_prefix}-${each.key}-api-rule"
    Service = each.key
    Type    = "cloudfront-api-rule"
  })
}

# Reglas para tráfico interno VPC ({path_prefix}/*)
resource "aws_lb_listener_rule" "microservices" {
  for_each = var.microservices

  listener_arn = aws_lb_listener.http.arn
  priority     = each.value.priority

  condition {
    path_pattern {
      values = ["${each.value.path_prefix}/*", each.value.path_prefix]
    }
  }

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.microservices[each.key].arn
  }

  tags = merge(var.common_tags, {
    Name    = "${local.name_prefix}-${each.key}-rule"
    Service = each.key
    Type    = "internal-rule"
  })
}

# =============================================================================
# LISTENER RULE - Health check global del ALB
# =============================================================================
resource "aws_lb_listener_rule" "health" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 1

  condition {
    path_pattern {
      values = ["/health", "/health/*"]
    }
  }

  action {
    type = "fixed-response"
    fixed_response {
      content_type = "application/json"
      message_body = jsonencode({
        status  = "healthy"
        service = "kl-ecommerce-alb"
      })
      status_code = "200"
    }
  }

  tags = merge(var.common_tags, {
    Name = "${local.name_prefix}-health-rule"
  })
}
