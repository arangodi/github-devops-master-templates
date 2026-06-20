locals {
  safe_environment = replace(lower(var.environment), ".", "-")
  eni_name         = lower("eni-${var.project_name}-${var.name}")

  common_tags = merge({
    Name         = local.eni_name
    project_name = var.project_name
    module       = "catalog/networking/eni"
  }, var.tags)
}

resource "aws_network_interface" "this" {
  subnet_id   = var.subnet_id
  description = var.description != null ? var.description : "ENI para ${local.eni_name}"

  private_ips = var.private_ip != null ? [var.private_ip] : null

  security_groups = var.security_group_ids

  tags = local.common_tags

  lifecycle {
    #prevent_destroy = true
    ignore_changes  = [security_groups]
  }
}