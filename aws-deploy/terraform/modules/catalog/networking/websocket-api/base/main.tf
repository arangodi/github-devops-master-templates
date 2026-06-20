data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

locals {
  api_name = lower("wsapi-${var.project_name}-${var.name}")

  # Resuelve el API ID desde el recurso creado o el data source
  api_id = var.create ? aws_apigatewayv2_api.this[0].id : tolist(data.aws_apigatewayv2_apis.existing[0].ids)[0]

  # Endpoint del API
  api_endpoint = "wss://${local.api_id}.execute-api.${data.aws_region.current.name}.amazonaws.com"

  common_tags = merge({
    Name         = local.api_name
    project_name = var.project_name
    environment  = var.environment
    module       = "catalog/networking/websocket-api/base"
  }, var.tags)
}

#################################################
# DATA SOURCE — WebSocket API existente
#################################################
data "aws_apigatewayv2_apis" "existing" {
  count         = var.create ? 0 : 1
  protocol_type = "WEBSOCKET"
  name          = var.existing_api_name
}

#################################################
# WEBSOCKET API
#################################################
resource "aws_apigatewayv2_api" "this" {
  count = var.create ? 1 : 0

  name                       = local.api_name
  protocol_type              = "WEBSOCKET"
  description                = var.description
  route_selection_expression = var.route_selection_expression

  tags = local.common_tags
}

#################################################
# CLOUDWATCH LOG GROUP
#################################################
resource "aws_cloudwatch_log_group" "this" {
  count = var.create_stage ? 1 : 0

  name              = "/aws/apigateway/websocket/${var.project_name}/${var.environment}/${var.name}"
  retention_in_days = var.log_retention_days

  tags = local.common_tags
}

#################################################
# STAGE
#################################################
resource "aws_apigatewayv2_stage" "this" {
  count = var.create_stage ? 1 : 0

  api_id      = local.api_id
  name        = var.environment
  auto_deploy = var.auto_deploy

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.this[0].arn
    format = jsonencode({
      requestId      = "$context.requestId"
      ip             = "$context.identity.sourceIp"
      requestTime    = "$context.requestTime"
      routeKey       = "$context.routeKey"
      status         = "$context.status"
      connectionId   = "$context.connectionId"
      eventType      = "$context.eventType"
      integrationError = "$context.integrationErrorMessage"
    })
  }

  tags = local.common_tags
}

#################################################
# SECURITY GROUP — VPC Link
#################################################
resource "aws_security_group" "vpc_link" {
  count = var.enable_vpc_link ? 1 : 0

  name        = lower("secg-${var.project_name}-${var.name}-ws-vpc-link")
  description = "SG para VPC Link WebSocket ${var.project_name}-${var.name}"
  vpc_id      = var.vpc_id

  tags = merge(local.common_tags, {
    Name = lower("secg-${var.project_name}-${var.name}-ws-vpc-link")
  })
}

resource "aws_vpc_security_group_ingress_rule" "vpc_link" {
  count = var.enable_vpc_link ? 1 : 0

  security_group_id = aws_security_group.vpc_link[0].id
  cidr_ipv4         = var.ingress_cidr
  from_port         = var.ingress_port
  to_port           = var.ingress_port
  ip_protocol       = "tcp"
  description       = "Trafico entrante al VPC Link WebSocket"
}

resource "aws_vpc_security_group_egress_rule" "vpc_link" {
  count = var.enable_vpc_link ? 1 : 0

  security_group_id = aws_security_group.vpc_link[0].id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
  description       = "Todo el trafico saliente"
}

#################################################
# VPC LINK v2
#################################################
resource "aws_apigatewayv2_vpc_link" "this" {
  count = var.enable_vpc_link ? 1 : 0

  name               = lower("vpclink-${var.project_name}-${var.name}")
  subnet_ids         = var.subnet_ids
  security_group_ids = [aws_security_group.vpc_link[0].id]

  tags = local.common_tags
}
