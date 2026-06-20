locals {
  # Si create = false y no hay existing_uri, construye el URI desde el patrón
  repository_uri = var.create ? aws_ecr_repository.this[0].repository_url : coalesce(
    var.existing_uri,
    "${data.aws_caller_identity.current.account_id}.dkr.ecr.${data.aws_region.current.name}.amazonaws.com/ecr-${lower(var.project_name)}-${var.environment}-${lower(var.name)}"
  )
}

output "uri" {
  description = "URI del repositorio ECR"
  value       = local.repository_uri
}

output "arn" {
  description = "ARN del repositorio ECR"
  value       = var.create ? aws_ecr_repository.this[0].arn : null
}

output "name" {
  description = "Nombre del repositorio ECR"
  value       = var.create ? aws_ecr_repository.this[0].name : null
}

output "image_version_parameter_name" {
  description = "Nombre del parámetro SSM con la version de la imagen"
  value       = var.create && var.create_ssm_parameter ? aws_ssm_parameter.image_version[0].name : null  
}

output "image_version_parameter_arn" {
  description = "ARN del parámetro SSM con la version de la imagen"
  value       = var.create && var.create_ssm_parameter ? aws_ssm_parameter.image_version[0].arn : null  
}