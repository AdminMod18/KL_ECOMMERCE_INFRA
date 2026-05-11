# =============================================================================
# OUTPUTS - Módulo ALB
# =============================================================================

output "alb_arn" {
  description = "ARN del ALB"
  value       = aws_lb.main.arn
}

output "alb_dns_name" {
  description = "DNS del ALB"
  value       = aws_lb.main.dns_name
}

output "alb_zone_id" {
  description = "Zone ID del ALB"
  value       = aws_lb.main.zone_id
}

output "alb_listener_arn" {
  description = "ARN del listener HTTP del ALB"
  value       = aws_lb_listener.http.arn
}

output "target_group_arns" {
  description = "Mapa de ARNs de target groups por microservicio"
  value = {
    for name, tg in aws_lb_target_group.microservices :
    name => tg.arn
  }
}

output "target_group_names" {
  description = "Mapa de nombres de target groups"
  value = {
    for name, tg in aws_lb_target_group.microservices :
    name => tg.name
  }
}
