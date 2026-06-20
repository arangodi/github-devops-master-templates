data "aws_region" "current" {}

locals {
  safe_environment = replace(lower(var.environment), ".", "-")
  elb_prefix       = var.load_balancer_type == "network" ? "nlb" : "elb"
  sg_prefix        = var.load_balancer_type == "network" ? "nl" : "lb"
  elb_name         = lower("elb-${var.project_name}-${var.name}")
  sg_name          = lower("secg-${var.project_name}-${local.sg_prefix}-${var.name}")

  elb_protocol = var.certificate_arn != null ? "HTTPS" : "HTTP"

  common_tags = merge({
    Name         = local.elb_name
    project_name = var.project_name
    Ambiente     = var.environment
    module       = "catalog/networking/elb"
  }, var.tags)
}

#################################################
# SECURITY GROUP DEL ELB
#################################################
resource "aws_security_group" "this" {
  count = var.create && var.load_balancer_type == "application" ? 1 : 0

  name        = local.sg_name
  description = "SG for LB ${var.project_name}"
  vpc_id      = var.vpc_id

  tags = merge(local.common_tags, {
    Name = local.sg_name
  })
}

resource "aws_vpc_security_group_ingress_rule" "this" {
  count = var.create && var.load_balancer_type == "application" ? 1 : 0

  security_group_id = aws_security_group.this[0].id
  cidr_ipv4         = var.ingress_cidr
  from_port         = var.port
  to_port           = var.port
  ip_protocol       = "tcp"
  description       = "Trafico interno al ELB"
}

resource "aws_vpc_security_group_egress_rule" "this" {
  count = var.create && var.load_balancer_type == "application" ? 1 : 0

  security_group_id = aws_security_group.this[0].id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
  description       = "Todo el trafico saliente"
}

#################################################
# LOAD BALANCER
#################################################
resource "aws_lb" "this" {
  count = var.create ? 1 : 0

  name               = local.elb_name
  internal           = var.internal
  load_balancer_type = var.load_balancer_type
  
  security_groups = var.load_balancer_type == "application" ? [aws_security_group.this[0].id] : null
  
  subnets      = var.subnet_ids
  idle_timeout = var.load_balancer_type == "application" ? var.idle_timeout : null

  enforce_security_group_inbound_rules_on_private_link_traffic = var.load_balancer_type == "application" ? "off" : null

  enable_deletion_protection = var.deletion_protection

  tags = local.common_tags

  lifecycle {
    ignore_changes = [enable_deletion_protection]
  }
}

#################################################
# LISTENER ALB — HTTP o HTTPS según certificado
#################################################
resource "aws_lb_listener" "this" {
  count = var.create && var.load_balancer_type == "application" ? 1 : 0

  load_balancer_arn = aws_lb.this[0].arn
  port              = var.port
  protocol          = local.elb_protocol

  # Solo aplica para HTTPS
  ssl_policy      = local.elb_protocol == "HTTPS" ? var.ssl_policy : null
  certificate_arn = local.elb_protocol == "HTTPS" ? var.certificate_arn : null

  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "application/json"
      message_body = "{\"error\": \"not found\"}"
      status_code  = "400"
    }
  }

  tags = local.common_tags
}

#################################################
# LISTENER NLB — TCP o TLS según certificado
#################################################
resource "aws_lb_listener" "network" {
  count = var.create && var.load_balancer_type == "network" && var.default_target_group_arn != null ? 1 : 0

  load_balancer_arn = aws_lb.this[0].arn
  port              = var.port
  protocol          = var.certificate_arn != null ? "TLS" : "TCP"
  certificate_arn   = var.certificate_arn != null ? var.certificate_arn : null
  ssl_policy        = var.certificate_arn != null ? var.ssl_policy : null

  default_action {
    type             = "forward"
    target_group_arn = var.default_target_group_arn
  }

  tags = local.common_tags
}