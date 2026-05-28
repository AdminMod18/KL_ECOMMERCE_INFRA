# =============================================================================
# MÓDULO ECS - Cluster, Task Definitions y Services
# Proyecto: KL Ecommerce
# Descripción: ECS Fargate cluster con task definitions y services
#              independientes para cada microservicio Spring Boot
# =============================================================================

locals {
  name_prefix = "${var.project_name}-${var.environment}"
}

# =============================================================================
# ECS CLUSTER
# =============================================================================
resource "aws_ecs_cluster" "main" {
  name = "${local.name_prefix}-cluster"

  # Container Insights para métricas avanzadas de contenedores
  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = merge(var.common_tags, {
    Name = "${local.name_prefix}-cluster"
    Type = "ecs-cluster"
  })
}

# Capacity providers: FARGATE y FARGATE_SPOT (SPOT reduce costos ~70%)
resource "aws_ecs_cluster_capacity_providers" "main" {
  cluster_name = aws_ecs_cluster.main.name

  capacity_providers = ["FARGATE", "FARGATE_SPOT"]

  # Por defecto usar FARGATE (más estable para demo)
  default_capacity_provider_strategy {
    base              = 1
    weight            = 100
    capacity_provider = "FARGATE"
  }
}

# =============================================================================
# TASK DEFINITIONS - Una por microservicio
# =============================================================================
resource "aws_ecs_task_definition" "microservices" {
  for_each = var.microservices

  family                   = "${local.name_prefix}-${each.key}"
  network_mode             = "awsvpc"  # Requerido para Fargate
  requires_compatibilities = ["FARGATE"]
  cpu                      = each.value.cpu
  memory                   = each.value.memory
  execution_role_arn       = var.ecs_task_execution_role_arn
  task_role_arn            = var.ecs_task_role_arn

  container_definitions = jsonencode([
    {
      name  = each.key
      image = "${var.ecr_repository_urls[each.key]}:${lookup(var.service_image_tags, each.key, "latest")}"

      # Mapeo de puertos
      portMappings = [
        {
          containerPort = each.value.port
          hostPort      = each.value.port
          protocol      = "tcp"
        }
      ]

      # Variables de entorno para Spring Boot
      environment = [
        # Configuración del servidor
        { name = "SERVER_PORT", value = tostring(each.value.port) },
        { name = "SPRING_PROFILES_ACTIVE", value = var.environment },

        # Configuración de base de datos
        # IMPORTANTE: var.rds_endpoint debe ser SOLO el hostname (aws_db_instance.address),
        # NO el endpoint completo (aws_db_instance.endpoint que incluye :5432).
        # Pasar db_host desde main.tf evita la URL malformada jdbc:...host:5432:5432/db
        { name = "SPRING_DATASOURCE_URL", value = "jdbc:postgresql://${var.rds_endpoint}:${var.rds_port}/${var.db_name}" },
        { name = "SPRING_DATASOURCE_USERNAME", value = var.db_username },
        { name = "SPRING_DATASOURCE_DRIVER_CLASS_NAME", value = "org.postgresql.Driver" },

        # JPA / Hibernate
        { name = "SPRING_JPA_HIBERNATE_DDL_AUTO", value = "update" },
        { name = "SPRING_JPA_SHOW_SQL", value = "false" },
        { name = "SPRING_JPA_DATABASE_PLATFORM", value = "org.hibernate.dialect.PostgreSQLDialect" },

        # Actuator para health checks
        # mappings expuesto temporalmente para descubrir endpoints reales del backend.
        # Una vez confirmados los paths, reducir a "health,info,metrics".
        { name = "MANAGEMENT_ENDPOINTS_WEB_EXPOSURE_INCLUDE", value = "health,info,metrics,mappings" },
        { name = "MANAGEMENT_ENDPOINT_HEALTH_SHOW_DETAILS", value = "always" },

        # HikariCP connection pool - CRÍTICO para db.t3.micro (max_connections=100).
        # 11 servicios × 5 conexiones = 55 conexiones máximas (margen seguro bajo 100).
        # Sin este límite HikariCP usa 10 por defecto → 110 conexiones → crash RDS.
        { name = "SPRING_DATASOURCE_HIKARI_MAXIMUM_POOL_SIZE", value = "5" },
        { name = "SPRING_DATASOURCE_HIKARI_MINIMUM_IDLE",      value = "2" },
        { name = "SPRING_DATASOURCE_HIKARI_CONNECTION_TIMEOUT", value = "30000" },
        { name = "SPRING_DATASOURCE_HIKARI_IDLE_TIMEOUT",      value = "600000" },

        # AWS Region
        { name = "AWS_DEFAULT_REGION", value = var.aws_region },
        { name = "AWS_REGION", value = var.aws_region },

        # Configuración de logging
        { name = "LOGGING_LEVEL_ROOT", value = "INFO" },
        { name = "LOGGING_LEVEL_COM_KLECOMMERCE", value = "DEBUG" },

        # Nombre del servicio para trazabilidad
        { name = "SPRING_APPLICATION_NAME", value = each.key },

        # URLs inter-servicio via ALB DNS real (resolvible dentro de la VPC).
        # Usar var.alb_dns_name (output dinámico de module.alb) en lugar del
        # nombre corto "${name_prefix}-alb" que NO resuelve en Route53 privado.
        { name = "SERVICE_AUTH_URL",         value = "http://${var.alb_dns_name}/auth" },
        { name = "SERVICE_USER_URL",         value = "http://${var.alb_dns_name}/users" },
        { name = "SERVICE_ORDER_URL",        value = "http://${var.alb_dns_name}/orders" },
        { name = "SERVICE_PRODUCT_URL",      value = "http://${var.alb_dns_name}/products" },
        { name = "SERVICE_PAYMENT_URL",      value = "http://${var.alb_dns_name}/payments" },
        { name = "SERVICE_NOTIFICATION_URL", value = "http://${var.alb_dns_name}/notifications" },
      ]

      # Secrets (contraseña de BD via SSM Parameter Store)
      # El ARN completo se construye con la región y account ID
      secrets = [
        {
          name      = "SPRING_DATASOURCE_PASSWORD"
          valueFrom = "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:parameter/${var.project_name}/${var.environment}/db/password"
        }
      ]

      # Configuración de logs CloudWatch
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "/ecs/${var.project_name}/${var.environment}/${each.key}"
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
          "awslogs-create-group"  = "true"
        }
      }

      # Health check del contenedor
      # startPeriod >= 150s: Spring Boot tarda ~90-120s en arrancar.
      # Con 60s anterior el ALB marcaba la tarea unhealthy antes de que levantara.
      healthCheck = {
        command     = ["CMD-SHELL", "curl -f http://localhost:${each.value.port}${each.value.health_check_path} || exit 1"]
        interval    = 30
        timeout     = 10
        retries     = 3
        startPeriod = 150  # Spring Boot necesita ~90-120s; 150s da margen suficiente
      }

      # Configuración de recursos
      essential = true

      # Límites de recursos (igual que task para Fargate)
      cpu    = each.value.cpu
      memory = each.value.memory

      # Readonly filesystem (seguridad)
      readonlyRootFilesystem = false

      # No privilegiado
      privileged = false
    }
  ])

  tags = merge(var.common_tags, {
    Name    = "${local.name_prefix}-${each.key}-task"
    Service = each.key
    Type    = "task-definition"
  })
}

# =============================================================================
# DATA SOURCES
# =============================================================================
data "aws_caller_identity" "current" {}

# =============================================================================
# ECS SERVICES - Uno por microservicio
# =============================================================================
resource "aws_ecs_service" "microservices" {
  for_each = var.microservices

  name            = "${local.name_prefix}-${each.key}-svc"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.microservices[each.key].arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  # Grace period para que Spring Boot (~90-120s de arranque) no sea matado
  # por el ALB antes de que el Actuator responda. Sin esto (default=0) el
  # servicio entra en bucle "Task failed ELB health checks".
  health_check_grace_period_seconds = 180

  # Configuración de red (subnets privadas)
  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [var.ecs_security_group_id]
    assign_public_ip = false  # Privado, acceso via NAT Gateway
  }

  # Integración con ALB
  load_balancer {
    target_group_arn = var.alb_target_group_arns[each.key]
    container_name   = each.key
    container_port   = each.value.port
  }

  # Estrategia de despliegue: rolling update
  deployment_controller {
    type = "ECS"
  }

  # Configuración de despliegue
  deployment_maximum_percent         = 200  # Permite 2x tasks durante despliegue
  deployment_minimum_healthy_percent = 50   # Mantiene 50% durante despliegue

  # Circuit breaker para rollback automático en fallos
  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  # Habilitar ECS Exec para debugging
  enable_execute_command = true

  # Propagación de tags a tasks
  propagate_tags = "SERVICE"

  # Ignorar cambios en task_definition para permitir despliegues externos (CI/CD)
  lifecycle {
    ignore_changes = [task_definition, desired_count]
  }

  tags = merge(var.common_tags, {
    Name    = "${local.name_prefix}-${each.key}-service"
    Service = each.key
    Type    = "ecs-service"
  })

  depends_on = [aws_ecs_task_definition.microservices]
}
