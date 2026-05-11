# =============================================================================
# OUTPUTS - Módulo CloudFront
# =============================================================================

output "cloudfront_domain_name" {
  description = "Nombre de dominio de la distribución CloudFront"
  value       = aws_cloudfront_distribution.main.domain_name
}

output "distribution_id" {
  description = "ID de la distribución CloudFront"
  value       = aws_cloudfront_distribution.main.id
}

output "distribution_arn" {
  description = "ARN de la distribución CloudFront"
  value       = aws_cloudfront_distribution.main.arn
}

output "distribution_status" {
  description = "Estado de la distribución CloudFront"
  value       = aws_cloudfront_distribution.main.status
}

output "hosted_zone_id" {
  description = "Hosted Zone ID de CloudFront (para Route53)"
  value       = aws_cloudfront_distribution.main.hosted_zone_id
}
