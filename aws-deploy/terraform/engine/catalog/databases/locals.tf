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

}