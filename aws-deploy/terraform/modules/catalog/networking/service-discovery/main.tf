locals {
  safe_environment = replace(lower(var.environment), ".", "-")
  namespace_name   = "${lower(var.project_name)}.net"

  common_tags = merge({
    Name         = "dsrv-${lower(var.project_name)}-namespace"
    project_name = var.project_name
    module       = "catalog/networking/service-discovery"
  }, var.tags)

  # Resolución del namespace según create
  namespace_id            = var.create ? aws_service_discovery_private_dns_namespace.this[0].id : data.aws_service_discovery_dns_namespace.this[0].id
  namespace_arn           = var.create ? aws_service_discovery_private_dns_namespace.this[0].arn : data.aws_service_discovery_dns_namespace.this[0].arn
  namespace_name_resolved = var.create ? aws_service_discovery_private_dns_namespace.this[0].name : data.aws_service_discovery_dns_namespace.this[0].name
}

# Crea el namespace si create = true
resource "aws_service_discovery_private_dns_namespace" "this" {
  count = var.create ? 1 : 0

  name = local.namespace_name
  vpc  = var.vpc_id
  tags = local.common_tags
}

# Referencia el namespace si create = false
data "aws_service_discovery_dns_namespace" "this" {
  count = var.create ? 0 : 1

  name = local.namespace_name
  type = "DNS_PRIVATE"
}