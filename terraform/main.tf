# =============================================================================
# MAIN - Orquestador Principal de Módulos
# Proyecto: KL Ecommerce - Infraestructura Enterprise AWS
# Descripción: Punto de entrada principal que instancia todos los módulos
#              en el orden correcto respetando dependencias
# =============================================================================

# -----------------------------------------------------------------------------
# Locals: Valores calculados y reutilizables
# -----------------------------------------------------------------------------
locals {
  # Prefijo estándar para naming de todos los recursos
  name_prefix = "${var.project_name}-${var.environment}"

  # Tags comunes aplicados a todos los recursos
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
    Owner       = var.owner
    CostCenter  = var.cost_center
  }

  # Lista de nombres de microservicios
  microservice_names = keys(var.microservices)
}

# =============================================================================
# MÓDULO 1: IAM - Roles y Políticas
# Debe crearse primero ya que ECS depende de estos roles
# =============================================================================
module "iam" {
  source = "./modules/iam"

  project_name = var.project_name
  environment  = var.environment
  aws_region   = var.aws_region
  common_tags  = local.common_tags
}

# =============================================================================
# MÓDULO 2: NETWORKING - VPC, Subnets, Gateways, Security Groups
# Base de toda la infraestructura de red
# =============================================================================
module "networking" {
  source = "./modules/networking"

  project_name         = var.project_name
  environment          = var.environment
  vpc_cidr             = var.vpc_cidr
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  availability_zones   = var.availability_zones
  enable_nat_gateway   = var.enable_nat_gateway
  single_nat_gateway   = var.single_nat_gateway
  common_tags          = local.common_tags
}

# =============================================================================
# MÓDULO 3: ECR - Repositorios de Imágenes Docker
# Independiente, puede crearse en paralelo con networking
# =============================================================================
module "ecr" {
  source = "./modules/ecr"

  project_name            = var.project_name
  environment             = var.environment
  microservice_names      = local.microservice_names
  ecr_image_count_to_keep = var.ecr_image_count_to_keep
  common_tags             = local.common_tags
}

# =============================================================================
# MÓDULO 4: CLOUDWATCH - Log Groups y Métricas
# Debe existir antes de ECS para recibir logs
# =============================================================================
module "cloudwatch" {
  source = "./modules/cloudwatch"

  project_name       = var.project_name
  environment        = var.environment
  aws_region         = var.aws_region
  microservice_names = local.microservice_names
  log_retention_days = var.log_retention_days
  common_tags        = local.common_tags
}

# =============================================================================
# MÓDULO 5: S3 - Bucket Frontend React/Vite
# Independiente, puede crearse en paralelo
# =============================================================================
module "s3" {
  source = "./modules/s3"

  project_name         = var.project_name
  environment          = var.environment
  frontend_bucket_name = var.frontend_bucket_name
  common_tags          = local.common_tags
}

# =============================================================================
# MÓDULO 6: RDS - Base de Datos PostgreSQL
# Depende de networking (subnets privadas y security groups)
# =============================================================================
module "rds" {
  source = "./modules/rds"

  project_name               = var.project_name
  environment                = var.environment
  vpc_id                     = module.networking.vpc_id
  private_subnet_ids         = module.networking.private_subnet_ids
  rds_security_group_id      = module.networking.rds_security_group_id
  db_instance_class          = var.db_instance_class
  db_engine_version          = var.db_engine_version
  db_allocated_storage       = var.db_allocated_storage
  db_name                    = var.db_name
  db_username                = var.db_username
  db_password                = var.db_password
  db_multi_az                = var.db_multi_az
  db_backup_retention_period = var.db_backup_retention_period
  db_deletion_protection     = var.db_deletion_protection
  common_tags                = local.common_tags
}

# =============================================================================
# MÓDULO 7: ALB - Application Load Balancer
# Depende de networking (subnets públicas y security groups)
# =============================================================================
module "alb" {
  source = "./modules/alb"

  project_name          = var.project_name
  environment           = var.environment
  vpc_id                = module.networking.vpc_id
  public_subnet_ids     = module.networking.public_subnet_ids
  alb_security_group_id = module.networking.alb_security_group_id
  microservices         = var.microservices
  common_tags           = local.common_tags
}

# =============================================================================
# MÓDULO 8: ECS - Cluster, Services y Task Definitions
# Depende de: networking, ecr, alb, iam, cloudwatch, rds
# =============================================================================
module "ecs" {
  source = "./modules/ecs"

  project_name                  = var.project_name
  environment                   = var.environment
  aws_region                    = var.aws_region
  vpc_id                        = module.networking.vpc_id
  private_subnet_ids            = module.networking.private_subnet_ids
  ecs_security_group_id         = module.networking.ecs_security_group_id
  microservices                 = var.microservices
  service_image_tags            = var.service_image_tags
  ecr_repository_urls           = module.ecr.repository_urls
  alb_target_group_arns         = module.alb.target_group_arns
  ecs_task_execution_role_arn   = module.iam.ecs_task_execution_role_arn
  ecs_task_role_arn             = module.iam.ecs_task_role_arn
  cloudwatch_log_group_names    = module.cloudwatch.log_group_names
  alb_dns_name                  = module.alb.alb_dns_name  # DNS real del ALB para SERVICE_*_URL inter-servicio
  rds_endpoint                  = module.rds.db_host   # .address (solo hostname, sin :puerto)
  rds_port                      = module.rds.db_port
  db_name                       = var.db_name
  db_username                   = var.db_username
  db_password                   = var.db_password
  desired_count                 = var.desired_count
  common_tags                   = local.common_tags
}

# =============================================================================
# MÓDULO 9: API GATEWAY - REST API hacia ALB
# Depende de: alb, networking
# =============================================================================
module "api_gateway" {
  source = "./modules/api-gateway"

  project_name              = var.project_name
  environment               = var.environment
  aws_region                = var.aws_region
  alb_dns_name              = module.alb.alb_dns_name
  alb_listener_arn          = module.alb.alb_listener_arn
  vpc_id                    = module.networking.vpc_id
  private_subnet_ids        = module.networking.private_subnet_ids
  microservices             = var.microservices
  api_gateway_stage_name    = var.api_gateway_stage_name
  api_gateway_logging_level = var.api_gateway_logging_level
  common_tags               = local.common_tags
}

# =============================================================================
# MÓDULO 10: CLOUDFRONT - CDN Global
# Depende de: s3, alb
# Behavior /api/* → ALB directo (CloudFront → ALB → ECS)
# Behavior default → S3 (frontend estático)
# =============================================================================
module "cloudfront" {
  source = "./modules/cloudfront"

  project_name                    = var.project_name
  environment                     = var.environment
  frontend_bucket_regional_domain = module.s3.frontend_bucket_regional_domain
  frontend_bucket_id              = module.s3.frontend_bucket_name
  alb_dns_name                    = module.alb.alb_dns_name   # origen /api/*
  api_gateway_url                 = module.api_gateway.api_url # mantenido para outputs
  api_gateway_stage_name          = var.api_gateway_stage_name
  common_tags                     = local.common_tags
}

# =============================================================================
# MÓDULO 11: SECURITY - Políticas adicionales y WAF básico
# Depende de: cloudfront, s3
# =============================================================================
module "security" {
  source = "./modules/security"

  project_name                 = var.project_name
  environment                  = var.environment
  frontend_bucket_name         = module.s3.frontend_bucket_name
  frontend_bucket_arn          = module.s3.frontend_bucket_arn
  cloudfront_distribution_arn  = module.cloudfront.distribution_arn
  common_tags                  = local.common_tags
}
