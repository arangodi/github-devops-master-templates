locals {
  certificate_arn = var.create ? aws_acm_certificate.this[0].arn : var.existing_arn
}

output "arn" {
  description = "ARN del certificado ACM"
  value       = local.certificate_arn
}

output "domain" {
  description = "Dominio principal del certificado"
  value       = var.create ? aws_acm_certificate.this[0].domain_name : var.domain
}

output "zone_id" {
  description = "ID de la zona Route53 — null si no se creo"
  value       = var.create && var.validation_method == "DNS" && var.create_zone ? aws_route53_zone.this[0].zone_id : null
}

output "zone_name_servers" {
  description = "Name servers de la zona Route53 — necesarios para delegar el dominio"
  value       = var.create && var.validation_method == "DNS" && var.create_zone ? aws_route53_zone.this[0].name_servers : null
}