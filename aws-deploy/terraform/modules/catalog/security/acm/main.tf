locals {
  domain_parts = split(".", var.domain)
  apex_domain  = var.apex_domain != null ? var.apex_domain : join(".", slice(local.domain_parts, length(local.domain_parts) - 3, length(local.domain_parts)))

  common_tags = merge({
    Name         = "acm-${var.project_name}-${var.environment}-${var.name}"
    project_name = var.project_name
    Ambiente  = var.environment
    project_name = var.project_name
    module       = "catalog/security/acm"
  }, var.tags)

  zone_id = var.create_zone ? aws_route53_zone.this[0].zone_id : data.aws_route53_zone.existing[0].zone_id
}

#################################################
# HOSTED ZONE — crea si no existe
#################################################
resource "aws_route53_zone" "this" {
  count = var.create && var.validation_method == "DNS" && var.create_zone ? 1 : 0

  name    = local.apex_domain
  comment = "Zona gestionada por IDP para ${var.project_name}-${var.environment}"

  vpc {
    vpc_id = var.vpc_id
  }

  tags = local.common_tags
}

data "aws_route53_zone" "existing" {
  count = var.create && var.validation_method == "DNS" && !var.create_zone ? 1 : 0

  name         = local.apex_domain
  private_zone = true
}

#################################################
# CERTIFICADO
#################################################
resource "aws_acm_certificate" "this" {
  count = var.create ? 1 : 0

  domain_name               = var.domain
  subject_alternative_names = var.subject_alternative_names
  validation_method         = var.validation_method

  lifecycle {
    create_before_destroy = true
  }

  tags = local.common_tags
}

#################################################
# VALIDACION DNS
#################################################
resource "aws_route53_record" "validation" {
  for_each = var.create && var.validation_method == "DNS" ? {
    for dvo in aws_acm_certificate.this[0].domain_validation_options :
    dvo.domain_name => {
      name   = dvo.resource_record_name
      type   = dvo.resource_record_type
      record = dvo.resource_record_value
    }
  } : {}

  zone_id = local.zone_id
  name    = each.value.name
  type    = each.value.type
  records = [each.value.record]
  ttl     = 60

  allow_overwrite = true
}

resource "aws_acm_certificate_validation" "this" {
  count = var.create && var.validation_method == "DNS" ? 1 : 0

  certificate_arn         = aws_acm_certificate.this[0].arn
  validation_record_fqdns = [for r in aws_route53_record.validation : r.fqdn]
}