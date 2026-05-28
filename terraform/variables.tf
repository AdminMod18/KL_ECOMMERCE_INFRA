# =============================================================================
# VARIABLES GLOBALES
# Proyecto: KL Ecommerce - Infraestructura Enterprise AWS
# Descripción: Todas las variables parametrizables del proyecto
# =============================================================================

# -----------------------------------------------------------------------------
# Variables de Proyecto y Entorno
# -----------------------------------------------------------------------------
variable "project_name" {
  description = "Nombre del proyecto usado en naming convention de todos los recursos"
  type        = string
  default     = "kl-ecommerce"
}

variable "environment" {
  description = "Entorno de despliegue (dev, staging, prod)"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "El entorno debe ser: dev, staging o prod."
  }
}

variable "owner" {
  description = "Propietario del proyecto para etiquetado de recursos"
  type        = string
  default     = "ecommerce-team"
}

variable "cost_center" {
  description = "Centro de costos para facturación y control de gastos"
  type        = string
  default     = "demo-university"
}

# -----------------------------------------------------------------------------
# Variables de AWS
# -----------------------------------------------------------------------------
variable "aws_region" {
  description = "Región AWS donde se desplegará la infraestructura"
  type        = string
  default     = "us-east-1"
}

# -----------------------------------------------------------------------------
# Variables de Networking
# -----------------------------------------------------------------------------
variable "vpc_cidr" {
  description = "CIDR block principal de la VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "Lista de CIDRs para subnets públicas (ALB, NAT Gateway)"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "Lista de CIDRs para subnets privadas (ECS, RDS)"
  type        = list(string)
  default     = ["10.0.10.0/24", "10.0.11.0/24"]
}

variable "availability_zones" {
  description = "Zonas de disponibilidad a usar (mínimo 2 para alta disponibilidad)"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

variable "enable_nat_gateway" {
  description = "Habilitar NAT Gateway para acceso a internet desde subnets privadas"
  type        = bool
  default     = true
}

variable "single_nat_gateway" {
  description = "Usar un solo NAT Gateway (reduce costos en demo, no recomendado en prod)"
  type        = bool
  default     = true
}

# -----------------------------------------------------------------------------
# Variables de ECS / Contenedores
# -----------------------------------------------------------------------------
variable "ecs_task_cpu" {
  description = "CPU asignada a cada task ECS en unidades (256 = 0.25 vCPU)"
  type        = number
  default     = 256
}

variable "ecs_task_memory" {
  description = "Memoria asignada a cada task ECS en MB"
  type        = number
  default     = 512
}

variable "desired_count" {
  description = "Número deseado de tasks ECS por microservicio"
  type        = number
  default     = 1
}

variable "docker_image_tag" {
  description = "Tag de imagen Docker a desplegar en todos los microservicios"
  type        = string
  default     = "latest"
}

# Tags de imagen por microservicio (permite versiones independientes)
variable "service_image_tags" {
  description = "Mapa de tags de imagen Docker por microservicio"
  type        = map(string)
  default = {
    auth-service         = "latest"
    user-service         = "latest"
    solicitud-service    = "latest"
    validation-service   = "latest"
    payment-service      = "latest"
    order-service        = "latest"
    product-service      = "latest"
    notification-service = "latest"
    analytics-service    = "latest"
    admin-service        = "latest"
    config-service       = "latest"
  }
}

# -----------------------------------------------------------------------------
# Variables de Microservicios (puertos)
# -----------------------------------------------------------------------------
variable "microservices" {
  description = "Configuración completa de cada microservicio"
  type = map(object({
    port        = number
    path_prefix = string
    priority    = number
    cpu         = number
    memory      = number
    health_check_path = string
  }))
  default = {
    # path_prefix: usado en container healthCheck de ECS (curl al actuator).
    # health_check_path: usado en el target group ALB health check.
    # Ambos apuntan al actuator en inglés (confirmado 200 en todos los servicios).
    # Las reglas de routing ALB usan los locals api_rules/internal_rules
    # con los paths reales del backend en español.
    auth-service = {
      port              = 9001
      path_prefix       = "/auth/actuator/health"
      priority          = 10
      cpu               = 256
      memory            = 512
      health_check_path = "/auth/actuator/health"
    }
    user-service = {
      port              = 9002
      path_prefix       = "/users/actuator/health"
      priority          = 20
      cpu               = 256
      memory            = 512
      health_check_path = "/users/actuator/health"
    }
    solicitud-service = {
      port              = 9003
      path_prefix       = "/solicitudes/actuator/health"
      priority          = 30
      cpu               = 256
      memory            = 512
      health_check_path = "/solicitudes/actuator/health"
    }
    validation-service = {
      port              = 9004
      path_prefix       = "/validation/actuator/health"
      priority          = 40
      cpu               = 256
      memory            = 512
      health_check_path = "/validation/actuator/health"
    }
    payment-service = {
      port              = 9005
      path_prefix       = "/payments/actuator/health"
      priority          = 50
      cpu               = 256
      memory            = 512
      health_check_path = "/payments/actuator/health"
    }
    order-service = {
      port              = 9006
      path_prefix       = "/orders/actuator/health"
      priority          = 60
      cpu               = 256
      memory            = 512
      health_check_path = "/orders/actuator/health"
    }
    product-service = {
      port              = 9007
      path_prefix       = "/products/actuator/health"
      priority          = 70
      cpu               = 256
      memory            = 512
      health_check_path = "/products/actuator/health"
    }
    notification-service = {
      port              = 9008
      path_prefix       = "/notifications/actuator/health"
      priority          = 80
      cpu               = 256
      memory            = 512
      health_check_path = "/notifications/actuator/health"
    }
    analytics-service = {
      port              = 9009
      path_prefix       = "/analytics/actuator/health"
      priority          = 90
      cpu               = 256
      memory            = 512
      health_check_path = "/analytics/actuator/health"
    }
    admin-service = {
      port              = 9010
      path_prefix       = "/admin/actuator/health"
      priority          = 100
      cpu               = 256
      memory            = 512
      health_check_path = "/admin/actuator/health"
    }
    config-service = {
      port              = 9011
      path_prefix       = "/config/actuator/health"
      priority          = 110
      cpu               = 256
      memory            = 512
      # config-service expone actuator en /config/actuator/health
      # (confirmado via management.endpoints.web.base-path en application-prod.yml)
      health_check_path = "/config/actuator/health"
    }
  }
}

# -----------------------------------------------------------------------------
# Variables de RDS
# -----------------------------------------------------------------------------
variable "db_instance_class" {
  description = "Clase de instancia RDS (db.t3.micro para demo)"
  type        = string
  default     = "db.t3.micro"
}

variable "db_engine_version" {
  description = "Versión del motor PostgreSQL"
  type        = string
  default     = "15.4"
}

variable "db_allocated_storage" {
  description = "Almacenamiento inicial en GB para RDS"
  type        = number
  default     = 20
}

variable "db_name" {
  description = "Nombre de la base de datos principal"
  type        = string
  default     = "kl_ecommerce"
}

variable "db_username" {
  description = "Usuario administrador de la base de datos"
  type        = string
  default     = "kl_admin"
  sensitive   = true
}

variable "db_password" {
  description = "Contraseña del administrador de la base de datos"
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.db_password) >= 8
    error_message = "La contraseña debe tener al menos 8 caracteres."
  }
}

variable "db_multi_az" {
  description = "Habilitar Multi-AZ para alta disponibilidad (false en demo para reducir costos)"
  type        = bool
  default     = false
}

variable "db_backup_retention_period" {
  description = "Días de retención de backups automáticos (0 = deshabilitado)"
  type        = number
  default     = 1
}

variable "db_deletion_protection" {
  description = "Protección contra eliminación accidental de RDS"
  type        = bool
  default     = false
}

# -----------------------------------------------------------------------------
# Variables de S3 / Frontend
# -----------------------------------------------------------------------------
variable "frontend_bucket_name" {
  description = "Nombre único del bucket S3 para el frontend React/Vite"
  type        = string
  default     = "kl-ecommerce-frontend-dev"
}

# -----------------------------------------------------------------------------
# Variables de CloudWatch
# -----------------------------------------------------------------------------
variable "log_retention_days" {
  description = "Días de retención de logs en CloudWatch"
  type        = number
  default     = 7
}

# -----------------------------------------------------------------------------
# Variables de ECR
# -----------------------------------------------------------------------------
variable "ecr_image_count_to_keep" {
  description = "Número de imágenes Docker a conservar en ECR por repositorio"
  type        = number
  default     = 3
}

# -----------------------------------------------------------------------------
# Variables de API Gateway
# -----------------------------------------------------------------------------
variable "api_gateway_stage_name" {
  description = "Nombre del stage de API Gateway"
  type        = string
  default     = "dev"
}

variable "api_gateway_logging_level" {
  description = "Nivel de logging de API Gateway (OFF, ERROR, INFO)"
  type        = string
  default     = "INFO"
}
