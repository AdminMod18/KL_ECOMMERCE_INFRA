# =============================================================================
# OUTPUTS - Módulo S3
# =============================================================================

output "frontend_bucket_name" {
  description = "Nombre del bucket S3 del frontend"
  value       = aws_s3_bucket.frontend.id
}

output "frontend_bucket_arn" {
  description = "ARN del bucket S3 del frontend"
  value       = aws_s3_bucket.frontend.arn
}

output "frontend_bucket_regional_domain" {
  description = "Dominio regional del bucket (para CloudFront OAC)"
  value       = aws_s3_bucket.frontend.bucket_regional_domain_name
}

output "frontend_bucket_website_endpoint" {
  description = "Endpoint de website del bucket S3"
  value       = aws_s3_bucket_website_configuration.frontend.website_endpoint
}

output "alb_logs_bucket_name" {
  description = "Nombre del bucket de logs del ALB"
  value       = aws_s3_bucket.alb_logs.id
}

output "alb_logs_bucket_arn" {
  description = "ARN del bucket de logs del ALB"
  value       = aws_s3_bucket.alb_logs.arn
}
