locals {
  routes_map = { for r in var.routes : r.key => r }
}

#################################################
# INTEGRACIÓN — una por ruta
#################################################
resource "aws_apigatewayv2_integration" "this" {
  for_each = local.routes_map

  api_id             = var.api_id
  integration_type   = var.integration_type
  integration_method = var.integration_method
  integration_uri    = each.value.integration_uri != null ? each.value.integration_uri : var.integration_uri
  connection_type    = var.connection_type
  connection_id      = var.connection_type == "VPC_LINK" ? var.vpc_link_id : null
}

#################################################
# RUTAS
#################################################
resource "aws_apigatewayv2_route" "this" {
  for_each = local.routes_map

  api_id    = var.api_id
  route_key = each.value.route_key

  authorization_type = each.value.authorization_type
  target             = "integrations/${aws_apigatewayv2_integration.this[each.key].id}"
}
