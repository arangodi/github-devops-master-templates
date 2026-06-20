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

  ecs_clusters     = coalesce(try(local.catalog.compute.ecs_clusters, null), [])
  ecs_services     = coalesce(try(local.catalog.compute.ecs_services, null), [])
  ecr_repositories = coalesce(try(local.catalog.compute.ecr_repositories, null), [])
  eks_clusters     = coalesce(try(local.catalog.compute.eks_clusters, null), [])
  ec2_instances    = coalesce(try(local.catalog.compute.ec2_instances, null), [])

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
  # ECS SERVICES — desde directorio de servicios
  ############################################
  services_dir = "${dirname(dirname(dirname(var.config_file)))}/${var.account}/services/${var.environment}/${var.project_name}"

  dir_services = length(try(fileset(local.services_dir, "*.yml"), [])) > 0 ? [
    for f in fileset(local.services_dir, "*.yml") :
    yamldecode(file("${local.services_dir}/${f}"))
  ] : []

  # Usa services del YAML
  raw_services = length(local.ecs_services) > 0 ? local.ecs_services : local.dir_services

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