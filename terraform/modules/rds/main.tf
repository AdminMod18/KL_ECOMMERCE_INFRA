# =============================================================================
# MÓDULO RDS - PostgreSQL
# Proyecto: KL Ecommerce
# Descripción: RDS PostgreSQL optimizado para demo con bajo costo
#              Subnet group, parameter group y instancia
# =============================================================================

locals {
  name_prefix = "${var.project_name}-${var.environment}"
}

# =============================================================================
# DB SUBNET GROUP
# RDS debe estar en subnets privadas en al menos 2 AZs
# =============================================================================
resource "aws_db_subnet_group" "main" {
  name        = "${local.name_prefix}-db-subnet-group"
  description = "Subnet group para RDS PostgreSQL - subnets privadas"
  subnet_ids  = var.private_subnet_ids

  tags = merge(var.common_tags, {
    Name = "${local.name_prefix}-db-subnet-group"
    Type = "db-subnet-group"
  })
}

# =============================================================================
# DB PARAMETER GROUP
# Parámetros optimizados para Spring Boot / Hibernate
# =============================================================================
resource "aws_db_parameter_group" "main" {
  name        = "${local.name_prefix}-postgres-params"
  family      = "postgres15"
  description = "Parameter group for PostgreSQL 15 - KL Ecommerce"

  # Max connections - calculado para 11 microservicios × 5 conexiones HikariCP
  # db.t3.micro soporta hasta ~100 conexiones por defecto.
  # Subimos a 200 para dar margen a futuros servicios y conexiones admin.
  # NOTA: este parámetro requiere reboot de la instancia RDS para aplicar.
  parameter {
    name         = "max_connections"
    value        = "200"
    apply_method = "pending-reboot"
  }

  # Log slow queries (dynamic parameter - immediate apply is fine)
  parameter {
    name         = "log_min_duration_statement"
    value        = "1000"
    apply_method = "immediate"
  }

  # Timezone (dynamic parameter)
  parameter {
    name         = "timezone"
    value        = "UTC"
    apply_method = "immediate"
  }

  # NOTE: shared_preload_libraries is a static parameter (requires reboot)
  # and cannot be set via Terraform parameter group on existing instances.
  # Enable it manually after creation if needed.

  tags = merge(var.common_tags, {
    Name = "${local.name_prefix}-postgres-params"
    Type = "db-parameter-group"
  })
}

# =============================================================================
# RDS INSTANCE - PostgreSQL
# =============================================================================
resource "aws_db_instance" "main" {
  identifier = "${local.name_prefix}-postgres"

  # Motor de base de datos
  engine         = "postgres"
  engine_version = var.db_engine_version
  instance_class = var.db_instance_class

  # Almacenamiento
  allocated_storage     = var.db_allocated_storage
  max_allocated_storage = 100  # Auto-scaling hasta 100GB
  storage_type          = "gp2"
  storage_encrypted     = true

  # Credenciales
  db_name  = var.db_name
  username = var.db_username
  password = var.db_password

  # Red y seguridad
  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [var.rds_security_group_id]
  publicly_accessible    = false  # Solo accesible desde VPC

  # Alta disponibilidad (false en demo para reducir costos)
  multi_az = var.db_multi_az

  # Backups
  backup_retention_period = var.db_backup_retention_period
  backup_window           = "03:00-04:00"  # UTC - madrugada
  maintenance_window      = "Mon:04:00-Mon:05:00"

  # Parameter group personalizado
  parameter_group_name = aws_db_parameter_group.main.name

  # Protección contra eliminación (false en demo)
  deletion_protection = var.db_deletion_protection

  # Snapshot al eliminar (false en demo para terraform destroy limpio)
  skip_final_snapshot       = true
  final_snapshot_identifier = null

  # Actualizaciones automáticas de versiones menores
  auto_minor_version_upgrade = true

  # Performance Insights (deshabilitado en demo para reducir costos)
  performance_insights_enabled = false

  # Enhanced Monitoring (deshabilitado en demo)
  monitoring_interval = 0

  # Logs habilitados
  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]

  tags = merge(var.common_tags, {
    Name = "${local.name_prefix}-postgres"
    Type = "rds-instance"
  })
}

# =============================================================================
# SSM PARAMETER STORE - Almacenar credenciales de forma segura
# Los microservicios ECS leen la contraseña desde SSM
# =============================================================================
resource "aws_ssm_parameter" "db_password" {
  name        = "/${var.project_name}/${var.environment}/db/password"
  description = "Contraseña de RDS PostgreSQL para ${var.project_name}"
  type        = "SecureString"
  value       = var.db_password

  tags = merge(var.common_tags, {
    Name = "${local.name_prefix}-db-password-param"
    Type = "ssm-parameter"
  })
}

resource "aws_ssm_parameter" "db_endpoint" {
  name        = "/${var.project_name}/${var.environment}/db/endpoint"
  description = "Endpoint de RDS PostgreSQL"
  type        = "String"
  value       = aws_db_instance.main.endpoint

  tags = merge(var.common_tags, {
    Name = "${local.name_prefix}-db-endpoint-param"
  })
}

resource "aws_ssm_parameter" "db_username" {
  name        = "/${var.project_name}/${var.environment}/db/username"
  description = "Usuario de RDS PostgreSQL"
  type        = "String"
  value       = var.db_username

  tags = merge(var.common_tags, {
    Name = "${local.name_prefix}-db-username-param"
  })
}
