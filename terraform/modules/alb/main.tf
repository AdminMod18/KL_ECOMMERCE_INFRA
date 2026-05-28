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
# LISTENER RULES
#
# ARQUITECTURA DE PATHS (confirmada contra código backend *Controller.java):
#
#   Tráfico CloudFront → ALB:  /api/{path_real_backend}/*
#   Tráfico interno VPC → ALB: /{path_real_backend}/*
#
# PATHS REALES DEL BACKEND (Spring Boot, context-path = '/'):
#   auth-service        → /auth/*          (login, roles, refresh, sincronizar-vendedor)
#   user-service        → /usuarios/*      (CRUD usuarios + /interno/* interno)
#   solicitud-service   → /solicitudes/*   (CRUD + validacion + activacion)
#   validation-service  → /validar/*       (+ /internal/mock/* solo interno)
#   payment-service     → /pagos/*
#   order-service       → /orden/*, /ordenes/*
#   product-service     → /productos/*     (+ interacciones)
#   notification-service→ /notificaciones/eventos/*
#   analytics-service   → /eventos/*, /kpis/*  (bajo prefijo /api/analytics en CF)
#   admin-service       → /admin/*         (parametros, auditoria, logs-error)
#   config-service      → /singleton/*
#
# HEALTH CHECKS (application-prod.yml):
#   Cada servicio expone actuator en /{nombre_en_ingles}/actuator/health
#   (configurado via management.endpoints.web.base-path en el código)
#
# PRIORIDADES:
#   1        → health check global ALB
#   10-110   → reglas internas VPC (/{path_real}/*)
#   210-510  → reglas CloudFront /api/* (prioridad base+200)
#   610-710  → reglas extra order-service (/ordenes) y analytics (/kpis)
# =============================================================================

# ---------------------------------------------------------------------------
# LOCAL: mapeo explícito path_real_backend → servicio
# Fuente: *Controller.java del backend + tabla confirmada por el equipo.
# ---------------------------------------------------------------------------
locals {
  # Reglas CloudFront /api/*: cada entrada es una regla independiente.
  # Formato: { rule_key → { service, patterns, priority } }
  # patterns: lista de path patterns que el ALB evaluará (wildcards AWS ALB).
  # priority: única por listener, sin colisiones.
  api_rules = {
    # auth-service: /api/auth/*
    "auth" = {
      service  = "auth-service"
      patterns = ["/api/auth", "/api/auth/*"]
      priority = 210
    }
    # user-service: /api/usuarios/*
    "usuarios" = {
      service  = "user-service"
      patterns = ["/api/usuarios", "/api/usuarios/*"]
      priority = 220
    }
    # solicitud-service: /api/solicitudes/*
    "solicitudes" = {
      service  = "solicitud-service"
      patterns = ["/api/solicitudes", "/api/solicitudes/*"]
      priority = 230
    }
    # validation-service: /api/validar/*
    "validar" = {
      service  = "validation-service"
      patterns = ["/api/validar", "/api/validar/*"]
      priority = 240
    }
    # payment-service: /api/pagos/*
    "pagos" = {
      service  = "payment-service"
      patterns = ["/api/pagos", "/api/pagos/*"]
      priority = 250
    }
    # order-service: /api/orden/* y /api/ordenes/*
    "orden" = {
      service  = "order-service"
      patterns = ["/api/orden", "/api/orden/*", "/api/ordenes", "/api/ordenes/*"]
      priority = 260
    }
    # product-service: /api/productos/*
    "productos" = {
      service  = "product-service"
      patterns = ["/api/productos", "/api/productos/*"]
      priority = 270
    }
    # notification-service: /api/notificaciones/*
    "notificaciones" = {
      service  = "notification-service"
      patterns = ["/api/notificaciones", "/api/notificaciones/*"]
      priority = 280
    }
    # analytics-service: /api/analytics/* cubre /api/analytics/eventos y /api/analytics/kpis
    # El backend expone /eventos y /kpis; CloudFront añade el prefijo /api/analytics.
    # El ALB enruta /api/analytics/* → analytics-service que recibe /api/analytics/eventos.
    # NOTA: el backend debe tener @RequestMapping("/api/analytics") o el frontend
    # debe llamar /api/analytics/eventos → backend recibe /api/analytics/eventos.
    # Si el backend solo tiene /eventos (sin prefijo), añadir context-path en backend.
    "analytics" = {
      service  = "analytics-service"
      patterns = ["/api/analytics", "/api/analytics/*"]
      priority = 290
    }
    # admin-service: /api/admin/*
    "admin" = {
      service  = "admin-service"
      patterns = ["/api/admin", "/api/admin/*"]
      priority = 300
    }
    # config-service: /api/config/* y /api/singleton/*
    "config" = {
      service  = "config-service"
      patterns = ["/api/config", "/api/config/*", "/api/singleton", "/api/singleton/*"]
      priority = 310
    }
  }

  # Reglas internas VPC: paths directos sin prefijo /api
  # Usadas por comunicación inter-servicio (SERVICE_*_URL en ECS).
  internal_rules = {
    "auth-internal" = {
      service  = "auth-service"
      patterns = ["/auth", "/auth/*"]
      priority = 10
    }
    "usuarios-internal" = {
      service  = "user-service"
      patterns = ["/usuarios", "/usuarios/*", "/interno", "/interno/*"]
      priority = 20
    }
    "solicitudes-internal" = {
      service  = "solicitud-service"
      patterns = ["/solicitudes", "/solicitudes/*"]
      priority = 30
    }
    "validar-internal" = {
      service  = "validation-service"
      patterns = ["/validar", "/validar/*", "/internal", "/internal/*"]
      priority = 40
    }
    "pagos-internal" = {
      service  = "payment-service"
      patterns = ["/pagos", "/pagos/*"]
      priority = 50
    }
    "orden-internal" = {
      service  = "order-service"
      patterns = ["/orden", "/orden/*", "/ordenes", "/ordenes/*"]
      priority = 60
    }
    "productos-internal" = {
      service  = "product-service"
      patterns = ["/productos", "/productos/*"]
      priority = 70
    }
    "notificaciones-internal" = {
      service  = "notification-service"
      patterns = ["/notificaciones", "/notificaciones/*"]
      priority = 80
    }
    "analytics-internal" = {
      service  = "analytics-service"
      patterns = ["/eventos", "/eventos/*", "/kpis", "/kpis/*"]
      priority = 90
    }
    "admin-internal" = {
      service  = "admin-service"
      patterns = ["/admin", "/admin/*"]
      priority = 100
    }
    "config-internal" = {
      service  = "config-service"
      patterns = ["/singleton", "/singleton/*"]
      priority = 110
    }
  }
}

# ---------------------------------------------------------------------------
# REGLAS CloudFront → ALB: /api/{path_real}/*
# ---------------------------------------------------------------------------
resource "aws_lb_listener_rule" "api" {
  for_each = local.api_rules

  listener_arn = aws_lb_listener.http.arn
  priority     = each.value.priority

  condition {
    path_pattern {
      values = each.value.patterns
    }
  }

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.microservices[each.value.service].arn
  }

  tags = merge(var.common_tags, {
    Name    = "${local.name_prefix}-${each.key}-api-rule"
    Service = each.value.service
    Type    = "cloudfront-api-rule"
  })
}

# ---------------------------------------------------------------------------
# REGLAS internas VPC: /{path_real}/*
# Usadas por SERVICE_*_URL en task definitions ECS.
# ---------------------------------------------------------------------------
resource "aws_lb_listener_rule" "internal" {
  for_each = local.internal_rules

  listener_arn = aws_lb_listener.http.arn
  priority     = each.value.priority

  condition {
    path_pattern {
      values = each.value.patterns
    }
  }

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.microservices[each.value.service].arn
  }

  tags = merge(var.common_tags, {
    Name    = "${local.name_prefix}-${each.key}-internal-rule"
    Service = each.value.service
    Type    = "internal-rule"
  })
}

# ---------------------------------------------------------------------------
# REGLA health check global del ALB (prioridad 1, más alta de todas)
# ---------------------------------------------------------------------------
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
