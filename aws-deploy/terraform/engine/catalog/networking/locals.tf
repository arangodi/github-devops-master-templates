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
  # RED DESDE SHARED
  ############################################
  network = try(data.terraform_remote_state.shared.outputs.network, {
    vpc_id               = null
    private_subnets      = []
    subnets_by_component = {}
  })

  ############################################
  # NETWORKING
  ############################################
  elbs           = try(local.catalog.networking.elbs, [])
  elbs_map       = { for e in local.elbs : e.name => e }
  namespaces     = try(local.catalog.networking.namespaces, [])
  eni_interfaces = try(local.catalog.networking.eni_interfaces, [])
  api_gateways   = try(local.catalog.networking.api_gateways, [])

  api_gateways_map = {
    for a in local.api_gateways : a.name => a
  }

  api_gateway_routes_nested = flatten([
    for a in local.api_gateways : [
      for r in try(a.routes, []) : merge(r, {
        api_gateway_name = a.name
        route_key        = "${a.name}-${r.name}"
      })
    ]
  ])
  
  api_gateway_routes_flat = try(local.catalog.networking.api_gateway_routes, [])

  api_gateway_routes = concat(
    local.api_gateway_routes_nested,
    [
      for r in local.api_gateway_routes_flat : merge(r, {
        route_key = "${r.api_gateway_name}-${r.name}"
      })
    ]
  )

  api_gateway_routes_map = {
    for r in local.api_gateway_routes : r.route_key => merge(r, {
      integration_scheme = try(r.integration_scheme, "https")
      integration_port   = try(r.integration_port, null)
    })
  }

  ############################################
  # ACM — resuelve el ARN del certificado
  ############################################
  certificate_arns = {
    for a in local.elbs : a.name =>
    try(a.certificate_arn, null) != null ?
      a.certificate_arn :
      try(a.port, 443) == 443 ?
        try(data.aws_acm_certificate.this[a.name].arn, null) :
        null 
  }

  ############################################
  # ARN ROLE CLOUDWATCH APIGW 
  ############################################
  api_gw_cloudwatch_role_arn = try(
    data.terraform_remote_state.shared.outputs.api_gw_cloudwatch_role_arn,
    null
  )

  ############################################
  # WEBSOCKET API
  ############################################
  websocket_apis = try(local.catalog.networking.websocket_apis, [])
  websocket_apis_map = {
    for a in local.websocket_apis : a.name => a
  }

  websocket_routes_nested = flatten([
    for a in local.websocket_apis : [
      for r in try(a.routes, []) : merge(r, {
        api_name  = a.name
        route_key = "${a.name}-${r.name}"
      })
    ]
  ])

  websocket_routes_flat = try(local.catalog.networking.websocket_routes, [])
  websocket_routes = concat(
    local.websocket_routes_nested,
    [
      for r in local.websocket_routes_flat : merge(r, {
        route_key = "${r.api_name}-${r.name}"
      })
    ]
  )
  websocket_routes_map = {
    for r in local.websocket_routes : r.route_key => merge(r, {
      integration_scheme = try(r.integration_scheme, "https")
      integration_port   = try(r.integration_port, null)
    })
  }
}