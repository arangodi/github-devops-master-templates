output "rest_api_id" {
  description = "ID del REST API Gateway"
  value       = local.rest_api_id
}

output "rest_api_arn" {
  description = "ARN del REST API Gateway"
  value       = var.existing_api_name != null ? data.aws_api_gateway_rest_api.existing[0].arn : try(aws_api_gateway_rest_api.this[0].arn, null)
}

output "rest_api_execution_arn" {
  description = "ARN de ejecución del REST API Gateway"
  value       = var.existing_api_name != null ? data.aws_api_gateway_rest_api.existing[0].execution_arn : try(aws_api_gateway_rest_api.this[0].execution_arn, null)
}

output "rest_api_root_resource_id" {
  description = "ID del resource raíz del REST API"
  value       = local.rest_api_root_resource_id
}

output "api_name" {
  description = "Nombre lógico del API Gateway"
  value       = local.api_name
}

output "stage_name" {
  description = "Nombre del stage"
  value       = var.create_stage && var.existing_api_name == null ? try(aws_api_gateway_stage.this[0].stage_name, null) : null
}

output "invoke_url" {
  description = "URL de invocación del API Gateway"
  value       = var.create_stage && var.existing_api_name == null ? try(aws_api_gateway_stage.this[0].invoke_url, null) : null
}

output "user_pool_id" {
  description = "ID del Cognito User Pool"
  value       = var.enable_cognito ? local.user_pool_id : null
}

output "user_pool_arn" {
  description = "ARN del Cognito User Pool"
  value       = var.enable_cognito ? local.user_pool_arn : null
}

output "user_pool_client_id" {
  description = "ID del Cognito User Pool Client"
  value       = var.enable_cognito && var.existing_user_pool_id == null ? try(aws_cognito_user_pool_client.this[0].id, null) : null
}

output "user_pool_domain" {
  description = "Dominio del Cognito User Pool"
  value       = var.enable_cognito && var.enable_cognito_domain && var.existing_user_pool_id == null ? try(aws_cognito_user_pool_domain.this[0].domain, null) : null
}

output "authorizer_id" {
  description = "ID del autorizador Cognito"
  value       = var.enable_cognito ? aws_api_gateway_authorizer.cognito[0].id : null
}

output "resource_server_identifiers" {
  description = "Identificadores de los resource servers de Cognito"
  value       = var.enable_cognito && var.existing_user_pool_id == null ? [for rs in aws_cognito_resource_server.this : rs.identifier] : []
}

output "vpc_link_id" {
  description = "ID del VPC Link"
  value       = var.enable_vpc_link ? aws_api_gateway_vpc_link.this[0].id : null
}

output "vpc_link_sg_id" {
  description = "ID del SG del VPC Link"
  value       = var.enable_vpc_link ? aws_security_group.vpc_link[0].id : null
}

output "api_key_id" {
  description = "ID del API Key"
  value       = var.enable_api_key ? aws_api_gateway_api_key.this[0].id : null
}

output "api_key_value" {
  description = "Valor del API Key"
  value       = var.enable_api_key ? aws_api_gateway_api_key.this[0].value : null
  sensitive   = true
}

output "usage_plan_id" {
  description = "ID del Usage Plan"
  value       = var.enable_api_key ? aws_api_gateway_usage_plan.this[0].id : null
}

#################################################
# CUSTOM DOMAIN OUTPUTS — MEJORADOS
#################################################
output "custom_domain_name" {
  description = "Nombre del custom domain (creado o existente)"
  value = var.enable_custom_domain ? (
    var.existing_custom_domain_name != null ? 
      var.existing_custom_domain_name :
      try(aws_api_gateway_domain_name.this[0].domain_name, null)
  ) : null
}

output "custom_domain_target" {
  description = "Target DNS del custom domain (regional_domain_name) para configurar en Route53"
  value = var.enable_custom_domain ? (
    var.existing_custom_domain_name != null ? 
      try(data.aws_api_gateway_domain_name.existing_domain[0].regional_domain_name, null) :
      try(aws_api_gateway_domain_name.this[0].regional_domain_name, null)
  ) : null
}

output "custom_domain_base_path" {
  description = "Base path configurado en el custom domain mapping"
  value       = var.enable_custom_domain ? var.custom_domain_base_path : null
}

output "custom_domain_url" {
  description = "URL completa del custom domain incluyendo el base path"
  value = var.enable_custom_domain ? (
    var.custom_domain_base_path != "(none)" ?
      "https://${var.existing_custom_domain_name != null ? var.existing_custom_domain_name : try(aws_api_gateway_domain_name.this[0].domain_name, "")}/${var.custom_domain_base_path}" :
      "https://${var.existing_custom_domain_name != null ? var.existing_custom_domain_name : try(aws_api_gateway_domain_name.this[0].domain_name, "")}"
  ) : null
}

output "log_group_name" {
  description = "Nombre del log group de CloudWatch. null si no se configuraron logs"
  value       = var.cloudwatch_role_arn != null ? aws_cloudwatch_log_group.api_gw_logs[0].name : null
}

output "access_token_validity" {
  description = "Duración del access token en minutos"
  value       = var.enable_cognito ? var.access_token_validity : null
}

output "id_token_validity" {
  description = "Duración del ID token en minutos"
  value       = var.enable_cognito ? var.id_token_validity : null
}

output "refresh_token_validity" {
  description = "Duración del refresh token en días"
  value       = var.enable_cognito ? var.refresh_token_validity : null
}

output "enable_token_revocation" {
  description = "Estado de la revocación de tokens"
  value       = var.enable_cognito ? var.enable_token_revocation : null
}

output "cognito_token_endpoint" {
  description = "URL del endpoint de token de Cognito (/oauth2/token)"
  value = var.enable_cognito && var.enable_cognito_domain && var.existing_user_pool_id == null ? (
    "https://${aws_cognito_user_pool_domain.this[0].domain}.auth.${data.aws_region.current.name}.amazoncognito.com/oauth2/token"
  ) : null
}

output "cognito_authorize_endpoint" {
  description = "URL del endpoint de autorización de Cognito (/oauth2/authorize)"
  value = var.enable_cognito && var.enable_cognito_domain && var.existing_user_pool_id == null ? (
    "https://${aws_cognito_user_pool_domain.this[0].domain}.auth.${data.aws_region.current.name}.amazoncognito.com/oauth2/authorize"
  ) : null
}

output "cognito_userinfo_endpoint" {
  description = "URL del endpoint de userinfo de Cognito (/oauth2/userInfo)"
  value = var.enable_cognito && var.enable_cognito_domain && var.existing_user_pool_id == null ? (
    "https://${aws_cognito_user_pool_domain.this[0].domain}.auth.${data.aws_region.current.name}.amazoncognito.com/oauth2/userInfo"
  ) : null
}

output "cognito_revoke_endpoint" {
  description = "URL del endpoint de revocación de Cognito (/oauth2/revoke)"
  value = var.enable_cognito && var.enable_cognito_domain && var.existing_user_pool_id == null ? (
    "https://${aws_cognito_user_pool_domain.this[0].domain}.auth.${data.aws_region.current.name}.amazoncognito.com/oauth2/revoke"
  ) : null
}