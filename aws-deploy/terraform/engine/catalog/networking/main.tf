#################################################
# ELBs
#################################################
module "elbs" {
  for_each = { for a in local.elbs : a.name => a }

  source = "../../../modules/catalog/networking/elb"

  name                  = each.value.name
  create                = try(each.value.create, true)
  existing_arn          = try(each.value.existing_arn, null)
  existing_listener_arn = try(each.value.existing_listener_arn, null)
  existing_sg_id        = try(each.value.existing_sg_id, null)

  vpc_id       = local.network.vpc_id
  subnet_group = try(each.value.subnet_group, "ELB")
  subnet_ids = try(
    local.network.subnets_by_component[try(each.value.subnet_group, "ELB")],
    local.network.private_subnets
  )
  load_balancer_type  = try(each.value.load_balancer_type, "application")
  certificate_arn     = try(local.certificate_arns[each.value.name], null)
  port                = try(each.value.port, 443)
  internal            = try(each.value.internal, true)
  ssl_policy          = try(each.value.ssl_policy, "ELBSecurityPolicy-TLS13-1-2-Ext2-2021-06")
  ingress_cidr        = try(each.value.ingress_cidr, "10.0.0.0/8")
  idle_timeout        = try(each.value.idle_timeout, 60)
  deletion_protection = try(each.value.deletion_protection, true)

  environment  = var.environment
  project_name = local.config.project_name
  account      = var.account
  tags         = merge(local.project_tags, try(each.value.tags, {}))
}

#################################################
# NLB → ALB ATTACHMENT
#################################################
module "nlb_alb_attachment" {
  for_each = {
    for a in local.elbs : a.name => a
    if try(a.default_target_alb_name, null) != null
  }

  source = "../../../modules/catalog/networking/nlb-alb-attachment"

  name    = each.value.name
  nlb_arn = module.elbs[each.key].arn
  alb_arn = module.elbs[each.value.default_target_alb_name].arn

  port            = try(each.value.port, 80)
  certificate_arn = try(local.certificate_arns[each.key], null)

  vpc_id       = local.network.vpc_id
  project_name = var.project_name
  tags         = merge(local.project_tags, try(each.value.tags, {}))

  depends_on = [module.elbs]
}

#################################################
# NAMESPACES SERVICE DISCOVERY
#################################################
module "namespaces" {
  for_each = { for n in local.namespaces : n.name => n }

  source = "../../../modules/catalog/networking/service-discovery"

  project_name = var.project_name
  create       = try(each.value.create, true)
  vpc_id       = local.network.vpc_id
  environment  = var.environment
  tags         = merge(local.project_tags, try(each.value.tags, {}))
}

#################################################
# ENIs — IP ESTÁTICA
#################################################
module "eni_interfaces" {
  for_each = { for e in local.eni_interfaces : e.name => e }

  source = "../../../modules/catalog/networking/eni"

  name         = each.value.name
  project_name = var.project_name
  environment  = var.environment

  subnet_id = try(
    local.network.subnets_by_component[try(each.value.subnet_group, "EC2")][
      try(each.value.subnet_index, 0)
    ],
    local.network.private_subnets[0]
  )

  private_ip         = try(each.value.private_ip, null)
  security_group_ids = try(each.value.security_group_ids, [])
  description        = try(each.value.description, null)

  tags = merge(local.project_tags, try(each.value.tags, {}))
}

#################################################
# API GATEWAYS — BASE
# Se crea una vez por API Gateway
#################################################
module "api_gateway_base" {
  for_each = local.api_gateways_map

  source = "../../../modules/catalog/networking/api-gateway/base"

  name         = each.value.name
  project_name = var.project_name
  environment  = var.environment
  description  = try(each.value.description, null)

  cloudwatch_role_arn = try(each.value.cloudwatch_role_arn, null)

  # API existente
  existing_api_name = try(each.value.existing_api_name, null)  

  endpoint_type    = try(each.value.endpoint_type, "REGIONAL")
  vpc_endpoint_ids = try(each.value.vpc_endpoint_ids, [])

  # Cognito
  enable_cognito            = try(each.value.cognito.enabled, false)
  client_name               = try(each.value.cognito.client_name, null)
  existing_user_pool_id     = try(each.value.cognito.existing_user_pool_id, null)
  cognito_domain_prefix     = try(each.value.cognito.domain_prefix, "")
  enable_cognito_domain     = try(each.value.cognito.enable_domain, false)
  access_token_validity     = try(each.value.cognito.access_token_validity, 60)
  id_token_validity         = try(each.value.cognito.id_token_validity, 60)
  refresh_token_validity    = try(each.value.cognito.refresh_token_validity, 30)
  enable_token_revocation   = try(each.value.cognito.enable_token_revocation, true)
  enable_client_credentials = try(each.value.cognito.enable_client_credentials, false)
  resource_servers          = try(each.value.cognito.resource_servers, [])

  enable_vpc_link = try(each.value.vpc_link.enabled, false)
  nlb_arn = try(each.value.vpc_link.enabled, false) ? try(
    module.elbs[each.value.vpc_link.nlb_name].arn,
    each.value.vpc_link.nlb_arn,
    null
  ) : null
  vpc_id     = local.network.vpc_id
  subnet_ids = try(
    local.network.subnets_by_component[try(each.value.vpc_link.subnet_group, "EC2")],
    local.network.private_subnets
  )

  create_stage          = try(each.value.stage.create, true)
  logging_level         = try(each.value.stage.logging_level, "INFO")
  enable_method_metrics = try(each.value.stage.enable_metrics, true)
  enable_data_trace     = try(each.value.stage.enable_data_trace, false)
  log_retention_days    = try(each.value.stage.log_retention_days, 30)
  enable_dummy_endpoint = try(each.value.enable_dummy_endpoint, true)

  enable_api_key       = try(each.value.usage_plan.enable_api_key, true)
  quota_limit          = try(each.value.usage_plan.quota_limit, 1000)
  quota_period         = try(each.value.usage_plan.quota_period, "MONTH")
  throttle_rate_limit  = try(each.value.usage_plan.throttle_rate_limit, 10)
  throttle_burst_limit = try(each.value.usage_plan.throttle_burst_limit, 2)

  enable_custom_domain          = try(each.value.custom_domain.enabled, false)
  existing_custom_domain_name    = try(each.value.custom_domain.existing_name, null)
  custom_domain_name            = try(each.value.custom_domain.name, "")
  custom_domain_base_path       = try(each.value.custom_domain.base_path, "(none)")
  custom_domain_certificate_arn = try(each.value.custom_domain.certificate_arn, null)
  custom_domain_security_policy = try(each.value.custom_domain.security_policy, "TLS_1_2")

  tags = merge(local.project_tags, try(each.value.tags, {}))
}

#################################################
# API GATEWAYS — ROUTES
# Se crea una vez por servicio/ruta
#################################################
module "api_gateway_routes" {
  for_each = local.api_gateway_routes_map

  source = "../../../modules/catalog/networking/api-gateway/routes"

  name         = each.value.name
  project_name = var.project_name
  environment  = var.environment

  # Referencias al base
  apigw_id = try(module.api_gateway_base[each.value.api_gateway_name].rest_api_id, each.value.apigw_id)
  apigw_root_resource_id = try(module.api_gateway_base[each.value.api_gateway_name].rest_api_root_resource_id, each.value.apigw_root_resource_id)
  apigw_stage_name = try(module.api_gateway_base[each.value.api_gateway_name].stage_name, each.value.apigw_stage_name)
  vpc_link_id = try(module.api_gateway_base[each.value.api_gateway_name].vpc_link_id, each.value.vpc_link_id, null)
  authorizer_id = try(module.api_gateway_base[each.value.api_gateway_name].authorizer_id, each.value.authorizer_id, null)

  # Integración NLB
  integration_uri = try(each.value.integration_uri, null) != null ? each.value.integration_uri : (
    try(each.value.nlb_name, null) != null
      ? "${each.value.integration_scheme}://${module.elbs[each.value.nlb_name].dns_name}${each.value.integration_port != null ? ":${each.value.integration_port}" : ""}"
      : null
  )
  nlb_arn = try(
    module.elbs[each.value.nlb_name].arn,
    each.value.nlb_arn,
    null
  )

  # Autorización
  authorization = try(each.value.authorization, "NONE")

  # Paths
  paths        = try(each.value.paths, [])
  create_proxy = try(each.value.create_proxy, false)
  proxy_methods    = try(each.value.proxy_methods, ["ANY"])
  proxy_parent_key = try(each.value.proxy_parent_key, null)

  integration_type = try(each.value.integration_type, "HTTP_PROXY")
  connection_type  = try(each.value.connection_type, "VPC_LINK")

  cognito_token_endpoint     = try(module.api_gateway_base[each.value.api_gateway_name].cognito_token_endpoint, null)
  cognito_authorize_endpoint = try(module.api_gateway_base[each.value.api_gateway_name].cognito_authorize_endpoint, null)
  cognito_userinfo_endpoint  = try(module.api_gateway_base[each.value.api_gateway_name].cognito_userinfo_endpoint, null)
  cognito_revoke_endpoint    = try(module.api_gateway_base[each.value.api_gateway_name].cognito_revoke_endpoint, null)

  tags = merge(local.project_tags, try(each.value.tags, {}))

  depends_on = [module.api_gateway_base]
}

#################################################
# WEBSOCKET API — BASE
#################################################
module "websocket_api_base" {
  for_each = local.websocket_apis_map

  source = "../../../modules/catalog/networking/websocket-api/base"

  name         = each.value.name
  project_name = var.project_name
  environment  = var.environment
  account      = var.account
  description  = try(each.value.description, null)

  # Crear vs referenciar
  create            = try(each.value.create, true)
  existing_api_name = try(each.value.existing_api_name, null)

  # API
  route_selection_expression = try(each.value.route_selection_expression, "$request.body.action")

  # Stage
  create_stage       = try(each.value.create_stage, true)
  auto_deploy        = try(each.value.auto_deploy, true)
  log_retention_days = try(each.value.log_retention_days, 30)

  # VPC Link
  enable_vpc_link = try(each.value.vpc_link.enabled, false)
  nlb_arn = try(each.value.vpc_link.enabled, false) ? try(
    module.elbs[each.value.vpc_link.nlb_name].arn,
    each.value.vpc_link.nlb_arn,
    null
  ) : null
  vpc_id     = local.network.vpc_id
  subnet_ids = try(
    local.network.subnets_by_component[try(each.value.vpc_link.subnet_group, "EC2")],
    local.network.private_subnets
  )

  # Security Group
  ingress_cidr = try(each.value.ingress_cidr, "10.0.0.0/8")
  ingress_port = try(each.value.ingress_port, 443)

  tags = merge(local.project_tags, try(each.value.tags, {}))
}

#################################################
# WEBSOCKET API — ROUTES
#################################################
module "websocket_api_routes" {
  for_each = local.websocket_routes_map

  source = "../../../modules/catalog/networking/websocket-api/routes"

  name         = each.value.name
  project_name = var.project_name
  environment  = var.environment

  # Referencias al base
  api_id = try(
    module.websocket_api_base[each.value.api_name].api_id,
    each.value.api_id
  )
  vpc_link_id = try(
    module.websocket_api_base[each.value.api_name].vpc_link_id,
    each.value.vpc_link_id,
    null
  )

  # Integración
  integration_uri = try(each.value.integration_uri, null) != null ? each.value.integration_uri : (
    try(each.value.nlb_name, null) != null
      ? "${each.value.integration_scheme}://${module.elbs[each.value.nlb_name].dns_name}${each.value.integration_port != null ? ":${each.value.integration_port}" : ""}"
      : null
  )
  integration_type   = try(each.value.integration_type, "HTTP_PROXY")
  connection_type    = try(each.value.connection_type, "VPC_LINK")
  integration_method = try(each.value.integration_method, "ANY")

  # Rutas
  routes = try(each.value.routes, [])

  tags = merge(local.project_tags, try(each.value.tags, {}))

  depends_on = [module.websocket_api_base]
}