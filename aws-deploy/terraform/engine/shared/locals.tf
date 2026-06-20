locals {

  ############################################
  # LECTURA ARCHIVO DE CONFIGURACION
  ############################################
  config  = yamldecode(file(var.config_file))
  globals = try(local.config.globals, {})

  ############################################
  # STACK CLOUDFORMATION DE NETWORK
  ############################################
  stack_outputs = try(data.aws_cloudformation_stack.network[0].outputs, {})

  private_subnets_map = {
    for k, v in local.stack_outputs :
    k => v
    if startswith(k, local.globals.network.private_subnet_prefix)
  }

  subnet_components = distinct([
    for k in keys(local.private_subnets_map) :
    regex("PrivateSubnet[0-9]+(.*)", k)[0]
  ])

  subnet_by_component = {
    for comp in local.subnet_components :
    comp => [
      for k, v in local.private_subnets_map :
      v
      if endswith(k, comp)
    ]
  }

  ############################################
  # NETWORK CONSOLIDADO
  ############################################
  network = {
    vpc_id               = local.stack_outputs["VpcId"]
    private_subnets      = flatten(values(local.subnet_by_component))
    subnets_by_component = local.subnet_by_component
  }

}