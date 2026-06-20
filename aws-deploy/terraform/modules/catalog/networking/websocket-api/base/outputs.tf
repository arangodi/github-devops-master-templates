output "api_id" {
  description = "ID del WebSocket API"
  value       = local.api_id
}

output "api_endpoint" {
  description = "Endpoint del WebSocket API. Ej: wss://xxxx.execute-api.us-east-1.amazonaws.com"
  value       = var.create ? aws_apigatewayv2_api.this[0].api_endpoint : null
}

output "api_name" {
  description = "Nombre del WebSocket API"
  value       = var.create ? aws_apigatewayv2_api.this[0].name : var.existing_api_name
}

output "stage_name" {
  description = "Nombre del stage"
  value       = var.create_stage ? aws_apigatewayv2_stage.this[0].name : null
}

output "stage_id" {
  description = "ID del stage"
  value       = var.create_stage ? aws_apigatewayv2_stage.this[0].id : null
}

output "invoke_url" {
  description = "URL completa para conectarse al WebSocket. Ej: wss://xxxx.execute-api.us-east-1.amazonaws.com/dev"
  value       = var.create_stage ? aws_apigatewayv2_stage.this[0].invoke_url : null
}

output "vpc_link_id" {
  description = "ID del VPC Link v2. Usado por el módulo de routes"
  value       = var.enable_vpc_link ? aws_apigatewayv2_vpc_link.this[0].id : null
}

output "vpc_link_arn" {
  description = "ARN del VPC Link v2"
  value       = var.enable_vpc_link ? aws_apigatewayv2_vpc_link.this[0].arn : null
}

output "security_group_id" {
  description = "ID del SG del VPC Link"
  value       = var.enable_vpc_link ? aws_security_group.vpc_link[0].id : null
}
