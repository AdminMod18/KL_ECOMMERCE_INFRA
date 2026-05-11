# =============================================================================
# MÓDULO NETWORKING - VPC Enterprise
# Proyecto: KL Ecommerce
# Descripción: VPC completa con subnets públicas/privadas, gateways,
#              route tables y security groups para arquitectura enterprise
# =============================================================================

# -----------------------------------------------------------------------------
# Locals del módulo
# -----------------------------------------------------------------------------
locals {
  name_prefix = "${var.project_name}-${var.environment}"
}

# =============================================================================
# VPC PRINCIPAL
# =============================================================================
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true  # Necesario para RDS y ECS
  enable_dns_support   = true

  tags = merge(var.common_tags, {
    Name = "${local.name_prefix}-vpc"
    Type = "main-vpc"
  })
}

# =============================================================================
# INTERNET GATEWAY
# Permite acceso a internet desde subnets públicas
# =============================================================================
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = merge(var.common_tags, {
    Name = "${local.name_prefix}-igw"
  })
}

# =============================================================================
# SUBNETS PÚBLICAS
# Usadas por: ALB, NAT Gateway
# =============================================================================
resource "aws_subnet" "public" {
  count = length(var.public_subnet_cidrs)

  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true  # Instancias en subnet pública obtienen IP pública

  tags = merge(var.common_tags, {
    Name = "${local.name_prefix}-public-subnet-${count.index + 1}"
    Type = "public"
    AZ   = var.availability_zones[count.index]
    # Tags para integración con Kubernetes (futuro)
    "kubernetes.io/role/elb" = "1"
  })
}

# =============================================================================
# SUBNETS PRIVADAS
# Usadas por: ECS Fargate, RDS PostgreSQL
# =============================================================================
resource "aws_subnet" "private" {
  count = length(var.private_subnet_cidrs)

  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  tags = merge(var.common_tags, {
    Name = "${local.name_prefix}-private-subnet-${count.index + 1}"
    Type = "private"
    AZ   = var.availability_zones[count.index]
    # Tags para integración con Kubernetes (futuro)
    "kubernetes.io/role/internal-elb" = "1"
  })
}

# =============================================================================
# ELASTIC IP para NAT Gateway
# =============================================================================
resource "aws_eip" "nat" {
  count  = var.enable_nat_gateway ? (var.single_nat_gateway ? 1 : length(var.public_subnet_cidrs)) : 0
  domain = "vpc"

  tags = merge(var.common_tags, {
    Name = "${local.name_prefix}-nat-eip-${count.index + 1}"
  })

  depends_on = [aws_internet_gateway.main]
}

# =============================================================================
# NAT GATEWAY
# Permite a ECS y RDS en subnets privadas acceder a internet
# (para pull de imágenes ECR, actualizaciones, etc.)
# single_nat_gateway = true reduce costos en demo
# =============================================================================
resource "aws_nat_gateway" "main" {
  count = var.enable_nat_gateway ? (var.single_nat_gateway ? 1 : length(var.public_subnet_cidrs)) : 0

  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = merge(var.common_tags, {
    Name = "${local.name_prefix}-nat-gw-${count.index + 1}"
  })

  depends_on = [aws_internet_gateway.main]
}

# =============================================================================
# ROUTE TABLE - Pública
# Enruta tráfico de internet a través del Internet Gateway
# =============================================================================
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = merge(var.common_tags, {
    Name = "${local.name_prefix}-public-rt"
    Type = "public"
  })
}

# Asociar subnets públicas con route table pública
resource "aws_route_table_association" "public" {
  count = length(aws_subnet.public)

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# =============================================================================
# ROUTE TABLES - Privadas
# Enruta tráfico de salida a través del NAT Gateway
# =============================================================================
resource "aws_route_table" "private" {
  count  = var.enable_nat_gateway ? (var.single_nat_gateway ? 1 : length(var.private_subnet_cidrs)) : length(var.private_subnet_cidrs)
  vpc_id = aws_vpc.main.id

  tags = merge(var.common_tags, {
    Name = "${local.name_prefix}-private-rt-${count.index + 1}"
    Type = "private"
  })
}

# Ruta de salida a internet via NAT Gateway (solo si está habilitado)
resource "aws_route" "private_nat" {
  count = var.enable_nat_gateway ? (var.single_nat_gateway ? 1 : length(var.private_subnet_cidrs)) : 0

  route_table_id         = aws_route_table.private[count.index].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = var.single_nat_gateway ? aws_nat_gateway.main[0].id : aws_nat_gateway.main[count.index].id
}

# Asociar subnets privadas con route tables privadas
resource "aws_route_table_association" "private" {
  count = length(aws_subnet.private)

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = var.single_nat_gateway ? aws_route_table.private[0].id : aws_route_table.private[count.index].id
}

# =============================================================================
# SECURITY GROUPS
# =============================================================================

# -----------------------------------------------------------------------------
# Security Group: ALB (Application Load Balancer)
# Permite tráfico HTTP/HTTPS desde internet
# -----------------------------------------------------------------------------
resource "aws_security_group" "alb" {
  name        = "${local.name_prefix}-alb-sg"
  description = "Security Group para Application Load Balancer - permite HTTP/HTTPS desde internet"
  vpc_id      = aws_vpc.main.id

  # Ingress: HTTP desde internet
  ingress {
    description = "HTTP desde internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Ingress: HTTPS desde internet
  ingress {
    description = "HTTPS desde internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Egress: Todo el tráfico de salida permitido
  egress {
    description = "Todo el tráfico de salida"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.common_tags, {
    Name = "${local.name_prefix}-alb-sg"
    Type = "alb-security-group"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# -----------------------------------------------------------------------------
# Security Group: ECS Fargate
# Solo permite tráfico desde el ALB en los puertos de los microservicios
# -----------------------------------------------------------------------------
resource "aws_security_group" "ecs" {
  name        = "${local.name_prefix}-ecs-sg"
  description = "Security Group para ECS Fargate - permite tráfico solo desde ALB"
  vpc_id      = aws_vpc.main.id

  # Ingress: Puertos de microservicios (9001-9011) solo desde ALB
  ingress {
    description     = "Puertos microservicios Spring Boot desde ALB"
    from_port       = 9001
    to_port         = 9011
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  # Ingress: Comunicación interna entre microservicios
  ingress {
    description = "Comunicación interna entre microservicios ECS"
    from_port   = 9001
    to_port     = 9011
    protocol    = "tcp"
    self        = true
  }

  # Egress: Todo el tráfico de salida (para ECR, RDS, CloudWatch)
  egress {
    description = "Todo el tráfico de salida"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.common_tags, {
    Name = "${local.name_prefix}-ecs-sg"
    Type = "ecs-security-group"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# -----------------------------------------------------------------------------
# Security Group: RDS PostgreSQL
# Solo permite tráfico desde ECS en puerto 5432
# -----------------------------------------------------------------------------
resource "aws_security_group" "rds" {
  name        = "${local.name_prefix}-rds-sg"
  description = "Security Group para RDS PostgreSQL - permite acceso solo desde ECS"
  vpc_id      = aws_vpc.main.id

  # Ingress: PostgreSQL solo desde ECS
  ingress {
    description     = "PostgreSQL desde ECS Fargate"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs.id]
  }

  # Egress: Solo dentro de la VPC
  egress {
    description = "Tráfico de salida dentro de VPC"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.vpc_cidr]
  }

  tags = merge(var.common_tags, {
    Name = "${local.name_prefix}-rds-sg"
    Type = "rds-security-group"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# -----------------------------------------------------------------------------
# Security Group: VPC Endpoints (para ECR sin NAT en producción)
# Permite comunicación con endpoints de AWS sin salir a internet
# -----------------------------------------------------------------------------
resource "aws_security_group" "vpc_endpoints" {
  name        = "${local.name_prefix}-vpc-endpoints-sg"
  description = "Security Group para VPC Endpoints de AWS (ECR, CloudWatch, etc.)"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTPS desde subnets privadas para VPC Endpoints"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = var.private_subnet_cidrs
  }

  egress {
    description = "Todo el tráfico de salida"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.common_tags, {
    Name = "${local.name_prefix}-vpc-endpoints-sg"
    Type = "vpc-endpoints-security-group"
  })
}

# =============================================================================
# VPC FLOW LOGS (Observabilidad de red)
# Registra todo el tráfico de red para auditoría y debugging
# =============================================================================
resource "aws_cloudwatch_log_group" "vpc_flow_logs" {
  name              = "/aws/vpc/${local.name_prefix}/flow-logs"
  retention_in_days = 7

  tags = merge(var.common_tags, {
    Name = "${local.name_prefix}-vpc-flow-logs"
  })
}

resource "aws_iam_role" "vpc_flow_logs" {
  name = "${local.name_prefix}-vpc-flow-logs-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "vpc-flow-logs.amazonaws.com"
        }
      }
    ]
  })

  tags = var.common_tags
}

resource "aws_iam_role_policy" "vpc_flow_logs" {
  name = "${local.name_prefix}-vpc-flow-logs-policy"
  role = aws_iam_role.vpc_flow_logs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams"
        ]
        Effect   = "Allow"
        Resource = "*"
      }
    ]
  })
}

resource "aws_flow_log" "main" {
  iam_role_arn    = aws_iam_role.vpc_flow_logs.arn
  log_destination = aws_cloudwatch_log_group.vpc_flow_logs.arn
  traffic_type    = "ALL"
  vpc_id          = aws_vpc.main.id

  tags = merge(var.common_tags, {
    Name = "${local.name_prefix}-vpc-flow-log"
  })
}
