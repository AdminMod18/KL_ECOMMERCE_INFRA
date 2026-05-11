# =============================================================================
# OUTPUTS - Módulo Networking
# =============================================================================

output "vpc_id" {
  description = "ID de la VPC"
  value       = aws_vpc.main.id
}

output "vpc_cidr" {
  description = "CIDR de la VPC"
  value       = aws_vpc.main.cidr_block
}

output "public_subnet_ids" {
  description = "IDs de subnets públicas"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "IDs de subnets privadas"
  value       = aws_subnet.private[*].id
}

output "internet_gateway_id" {
  description = "ID del Internet Gateway"
  value       = aws_internet_gateway.main.id
}

output "nat_gateway_ids" {
  description = "IDs de los NAT Gateways"
  value       = aws_nat_gateway.main[*].id
}

output "nat_gateway_ip" {
  description = "IP pública del NAT Gateway"
  value       = length(aws_eip.nat) > 0 ? aws_eip.nat[0].public_ip : null
}

output "alb_security_group_id" {
  description = "ID del Security Group del ALB"
  value       = aws_security_group.alb.id
}

output "ecs_security_group_id" {
  description = "ID del Security Group de ECS"
  value       = aws_security_group.ecs.id
}

output "rds_security_group_id" {
  description = "ID del Security Group de RDS"
  value       = aws_security_group.rds.id
}

output "vpc_endpoints_security_group_id" {
  description = "ID del Security Group de VPC Endpoints"
  value       = aws_security_group.vpc_endpoints.id
}

output "public_route_table_id" {
  description = "ID de la route table pública"
  value       = aws_route_table.public.id
}

output "private_route_table_ids" {
  description = "IDs de las route tables privadas"
  value       = aws_route_table.private[*].id
}
