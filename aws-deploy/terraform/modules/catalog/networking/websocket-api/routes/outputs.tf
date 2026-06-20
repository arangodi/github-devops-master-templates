output "route_ids" {
  description = "Mapa de key → ID de la ruta"
  value = {
    for k, r in aws_apigatewayv2_route.this : k => r.id
  }
}

output "route_keys" {
  description = "Mapa de key → route_key. Ej: connect → $connect"
  value = {
    for k, r in aws_apigatewayv2_route.this : k => r.route_key
  }
}

output "integration_ids" {
  description = "Mapa de key → ID de la integración"
  value = {
    for k, i in aws_apigatewayv2_integration.this : k => i.id
  }
}
