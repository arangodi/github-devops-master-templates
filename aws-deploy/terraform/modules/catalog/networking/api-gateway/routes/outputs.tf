output "deployment_id" {
  description = "ID del deployment"
  value       = aws_api_gateway_deployment.deployment.id
}

output "apigw_id" {
  description = "ID del API Gateway"
  value       = var.apigw_id
}

output "paths_created" {
  description = "Lista de path_parts creados"
  value       = [for p in var.paths : p.path_part]
}

output "integration_type" {
  description = "Tipo de integración configurada"
  value       = var.integration_type
}

output "connection_type" {
  description = "Tipo de conexión (VPC_LINK o INTERNET)"
  value       = var.connection_type
}

output "methods_created" {
  description = "Map de métodos HTTP creados por path"
  value = {
    for k, m in aws_api_gateway_method.methods : k => {
      resource_id   = m.resource_id
      http_method   = m.http_method
      authorization = m.authorization
    }
  }
}

output "all_resource_ids" {
  description = "Map consolidado de todos los resource IDs creados (todos los niveles)"
  value       = local.all_resource_ids
}

# Outputs de niveles individuales (mantener por compatibilidad)
output "resource_ids_level_0" {
  description = "IDs de recursos nivel 0"
  value       = { for k, r in aws_api_gateway_resource.paths_level_0 : k => r.id }
}

output "resource_ids_level_1" {
  description = "IDs de recursos nivel 1"
  value       = { for k, r in aws_api_gateway_resource.paths_level_1 : k => r.id }
}

output "resource_ids_level_2" {
  description = "IDs de recursos nivel 2"
  value       = { for k, r in aws_api_gateway_resource.paths_level_2 : k => r.id }
}

output "resource_ids_level_3" {
  description = "IDs de recursos nivel 3"
  value       = { for k, r in aws_api_gateway_resource.paths_level_3 : k => r.id }
}