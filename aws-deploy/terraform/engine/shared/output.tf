output "network" {
  description = "Datos de red consolidados desde CloudFormation"
  value       = local.network
}

output "vpc_id" {
  description = "ID de la VPC"
  value       = local.network.vpc_id
}

output "private_subnets" {
  description = "Lista de todas las subnets privadas"
  value       = local.network.private_subnets
}

output "subnets_by_component" {
  description = "Subnets agrupadas por componente"
  value       = local.network.subnets_by_component
}
