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
  # SECURITY
  ############################################
  certificates = [
    for c in try(local.catalog.security.certificates, []) : merge(c, {
      domain = try(c.domain, "${c.name}${var.environment}.btgpactual.com.co")
    })
  ]

  ############################################
  # SECRET MANAGER
  ############################################
  secrets = coalesce(try(local.catalog.security.secrets, null), [])
  secrets_map = { for s in local.secrets : s.name => s }

}