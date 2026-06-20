locals {

  ############################################
  # LECTURA ARCHIVO DE CONFIGURACION
  ############################################
  config  = yamldecode(file(var.config_file))
  catalog = try(local.config.catalog, {})

  ############################################
  # TAGS DESDE tags.yml
  ############################################
  project_tags = try(
    {
      for tag in yamldecode(file("${dirname(var.config_file)}/tags.yml")).variables :
      tag.name => tag.value
    },
    {}
  )

  ############################################
  # RED DESDE CLOUDFORMATION
  ############################################
  network = try(data.terraform_remote_state.shared.outputs.network, { vpc_id = null, private_subnets = [], subnets_by_component = {} })

  ############################################
  # NETWORKING — ELBs y namespaces ya creados
  ############################################
  elbs       = coalesce(try(data.terraform_remote_state.networking.outputs.elbs, null), {})
  namespaces = coalesce(try(data.terraform_remote_state.networking.outputs.namespaces, null), {})
  #eni_interfaces = try(data.terraform_remote_state.networking.outputs.eni_interfaces, {})
  eni_interfaces = coalesce(try(data.terraform_remote_state.networking.outputs.eni_interfaces, null), {})


  ############################################
  # COMPUTE
  ############################################
  safe_environment = replace(lower(var.environment), ".", "-")

  ecs_clusters     = try(local.catalog.compute.ecs_clusters, [])
  ecs_services     = try(local.catalog.compute.ecs_services, [])
  ecr_repositories = try(local.catalog.compute.ecr_repositories, [])
  eks_clusters     = try(local.catalog.compute.eks_clusters, [])
  ec2_instances    = try(local.catalog.compute.ec2_instances, [])

  ecs_clusters_map = {
    for c in local.ecs_clusters : c.name => c
  }

  eks_clusters_map = {
    for c in local.eks_clusters : c.name => c
  }

  ec2_map = {
    for e in local.ec2_instances : e.name => e
  }

  # Nombre del namespace — sigue el patrón {project_name}.net
  default_namespace_name = "${lower(var.project_name)}.net"

  # Resuelve el ID del namespace desde el state de networking
  default_namespace_id = try(
    local.namespaces[var.project_name].id,
    local.namespaces["${var.project_name}-ns"].id,
    null
  )

  ############################################
  # ECS SERVICES
  ############################################
  raw_services = local.ecs_services

  # Enriquece cada servicio con los valores de infra 
  final_ecs_services = [
    for svc in local.raw_services : merge(
      {
        cluster   = length(local.ecs_clusters) > 0 ? local.ecs_clusters[0].name : null
        namespace = var.project_name
        elb       = null
        autoscaling = {
          min        = 1
          max        = 4
          target_cpu = 80
        }
      },
      svc
    )
  ]
}