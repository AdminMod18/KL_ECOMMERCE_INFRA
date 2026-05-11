# =============================================================================
# OUTPUTS - Módulo ECS
# =============================================================================

output "cluster_name" {
  description = "Nombre del cluster ECS"
  value       = aws_ecs_cluster.main.name
}

output "cluster_arn" {
  description = "ARN del cluster ECS"
  value       = aws_ecs_cluster.main.arn
}

output "cluster_id" {
  description = "ID del cluster ECS"
  value       = aws_ecs_cluster.main.id
}

output "service_names" {
  description = "Mapa de nombres de servicios ECS"
  value = {
    for name, svc in aws_ecs_service.microservices :
    name => svc.name
  }
}

output "service_arns" {
  description = "Mapa de ARNs de servicios ECS"
  value = {
    for name, svc in aws_ecs_service.microservices :
    name => svc.id
  }
}

output "task_definition_arns" {
  description = "Mapa de ARNs de task definitions"
  value = {
    for name, td in aws_ecs_task_definition.microservices :
    name => td.arn
  }
}

output "task_definition_families" {
  description = "Mapa de familias de task definitions"
  value = {
    for name, td in aws_ecs_task_definition.microservices :
    name => td.family
  }
}
