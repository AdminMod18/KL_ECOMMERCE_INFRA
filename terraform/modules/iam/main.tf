# =============================================================================
# MÓDULO IAM - Roles y Políticas
# Proyecto: KL Ecommerce
# Descripción: Roles IAM para ECS Task Execution y Task Role
#              con políticas mínimas necesarias (principio de menor privilegio)
# =============================================================================

locals {
  name_prefix = "${var.project_name}-${var.environment}"
}

# =============================================================================
# ECS TASK EXECUTION ROLE
# Usado por ECS para: pull de imágenes ECR, escribir logs en CloudWatch,
# leer secrets de SSM Parameter Store
# =============================================================================
resource "aws_iam_role" "ecs_task_execution" {
  name        = "${local.name_prefix}-ecs-task-execution-role"
  description = "Rol de ejecución de tasks ECS - permite pull ECR y logs CloudWatch"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(var.common_tags, {
    Name = "${local.name_prefix}-ecs-task-execution-role"
    Type = "iam-role"
  })
}

# Política AWS gestionada para ejecución de tasks ECS
resource "aws_iam_role_policy_attachment" "ecs_task_execution_managed" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Política adicional para ECR y CloudWatch Logs
resource "aws_iam_role_policy" "ecs_task_execution_custom" {
  name = "${local.name_prefix}-ecs-task-execution-custom-policy"
  role = aws_iam_role.ecs_task_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        # Acceso a ECR para pull de imágenes
        Sid    = "ECRAccess"
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage"
        ]
        Resource = "*"
      },
      {
        # Acceso a CloudWatch Logs para escribir logs de contenedores
        Sid    = "CloudWatchLogsAccess"
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:CreateLogGroup",
          "logs:DescribeLogStreams"
        ]
        Resource = "arn:aws:logs:${var.aws_region}:*:log-group:/ecs/${var.project_name}/*"
      },
      {
        # Acceso a SSM Parameter Store para secrets
        Sid    = "SSMParameterAccess"
        Effect = "Allow"
        Action = [
          "ssm:GetParameters",
          "ssm:GetParameter",
          "ssm:GetParametersByPath"
        ]
        Resource = "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:parameter/${var.project_name}/${var.environment}/*"
      },
      {
        # Acceso a Secrets Manager
        Sid    = "SecretsManagerAccess"
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = "arn:aws:secretsmanager:${var.aws_region}:${data.aws_caller_identity.current.account_id}:secret:${var.project_name}/${var.environment}/*"
      }
    ]
  })
}

# =============================================================================
# ECS TASK ROLE
# Usado por la aplicación dentro del contenedor para acceder a servicios AWS
# (S3, SQS, SNS, DynamoDB, etc.)
# =============================================================================
resource "aws_iam_role" "ecs_task" {
  name        = "${local.name_prefix}-ecs-task-role"
  description = "Rol de task ECS - permisos para la aplicación dentro del contenedor"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(var.common_tags, {
    Name = "${local.name_prefix}-ecs-task-role"
    Type = "iam-role"
  })
}

# Política para la aplicación dentro del contenedor
resource "aws_iam_role_policy" "ecs_task_custom" {
  name = "${local.name_prefix}-ecs-task-custom-policy"
  role = aws_iam_role.ecs_task.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        # CloudWatch Logs desde la aplicación
        Sid    = "CloudWatchLogs"
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams"
        ]
        Resource = "arn:aws:logs:${var.aws_region}:*:log-group:/ecs/${var.project_name}/*"
      },
      {
        # CloudWatch Metrics para métricas de aplicación
        Sid    = "CloudWatchMetrics"
        Effect = "Allow"
        Action = [
          "cloudwatch:PutMetricData",
          "cloudwatch:GetMetricData",
          "cloudwatch:ListMetrics"
        ]
        Resource = "*"
      },
      {
        # X-Ray para tracing distribuido (futuro)
        Sid    = "XRayAccess"
        Effect = "Allow"
        Action = [
          "xray:PutTraceSegments",
          "xray:PutTelemetryRecords",
          "xray:GetSamplingRules",
          "xray:GetSamplingTargets"
        ]
        Resource = "*"
      },
      {
        # ECS Exec para debugging (acceso a contenedor en ejecución)
        Sid    = "ECSExec"
        Effect = "Allow"
        Action = [
          "ssmmessages:CreateControlChannel",
          "ssmmessages:CreateDataChannel",
          "ssmmessages:OpenControlChannel",
          "ssmmessages:OpenDataChannel"
        ]
        Resource = "*"
      }
    ]
  })
}

# =============================================================================
# ROL PARA API GATEWAY - CloudWatch Logs
# =============================================================================
resource "aws_iam_role" "api_gateway_cloudwatch" {
  name        = "${local.name_prefix}-api-gateway-cloudwatch-role"
  description = "Rol para API Gateway - permite escribir logs en CloudWatch"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "apigateway.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(var.common_tags, {
    Name = "${local.name_prefix}-api-gateway-cloudwatch-role"
  })
}

resource "aws_iam_role_policy_attachment" "api_gateway_cloudwatch" {
  role       = aws_iam_role.api_gateway_cloudwatch.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonAPIGatewayPushToCloudWatchLogs"
}

# Configurar API Gateway para usar el rol de CloudWatch
resource "aws_api_gateway_account" "main" {
  cloudwatch_role_arn = aws_iam_role.api_gateway_cloudwatch.arn
}

# =============================================================================
# DATA SOURCES
# =============================================================================
data "aws_caller_identity" "current" {}
