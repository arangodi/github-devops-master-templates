locals {
  safe_environment = replace(lower(var.environment), ".", "-")

  authorizer_config = var.authorization == "COGNITO_USER_POOLS" && var.authorizer_id != null ? {
    authorization = "COGNITO_USER_POOLS"
    authorizer_id = var.authorizer_id
  } : {
    authorization = "NONE"
  }

  existing_resource_ids = {
    for p in var.paths : p.key => p.existing_resource_id
    if p.existing_resource_id != null
  }

  # Clasifica los paths por nivel según parent_key
  paths_by_level = {
    0 = { for p in var.paths : p.key => p if p.parent_key == null }
    1 = { for p in var.paths : p.key => p if p.parent_key != null && !contains([for pp in var.paths : pp.key if pp.parent_key == null], p.parent_key) == false }
    2 = { for p in var.paths : p.key => p if p.parent_key != null && contains(keys({ for pp in var.paths : pp.key => pp if pp.parent_key != null && contains(keys({ for ppp in var.paths : ppp.key => ppp if ppp.parent_key == null }), pp.parent_key) }), p.parent_key) }
  }

  # Resuelve el parent_id para cada path
  all_resource_ids = merge(
    { for k, r in aws_api_gateway_resource.paths_level_0 : k => r.id },
    { for k, r in aws_api_gateway_resource.paths_level_1 : k => r.id },
    { for k, r in aws_api_gateway_resource.paths_level_2 : k => r.id },
    { for k, r in aws_api_gateway_resource.paths_level_3 : k => r.id },
    { for k, r in aws_api_gateway_resource.paths_level_4 : k => r.id },
    { for k, r in aws_api_gateway_resource.paths_level_5 : k => r.id },
    { for k, r in aws_api_gateway_resource.paths_level_6 : k => r.id },
    { for k, r in aws_api_gateway_resource.paths_level_7 : k => r.id },
    { for k, r in aws_api_gateway_resource.paths_level_8 : k => r.id },
    { for k, r in aws_api_gateway_resource.paths_level_9 : k => r.id },
    local.existing_resource_ids,
  )

  # Paths con métodos — para crear integración
  paths_with_methods = {
    for p in var.paths : p.key => p
    if length(p.methods) > 0
  }

  # Resolver palabras clave de Cognito
  integration_uri_map = {
    COGNITO_TOKEN     = var.cognito_token_endpoint
    COGNITO_AUTHORIZE = var.cognito_authorize_endpoint
    COGNITO_USERINFO  = var.cognito_userinfo_endpoint
    COGNITO_REVOKE    = var.cognito_revoke_endpoint
  }

  flat_methods = flatten([
    for pk, p in local.paths_with_methods : [
      for m in p.methods : {
        key             = "${pk}-${m}"
        path_key        = pk
        method          = m
        api_key_required = try(p.api_key_required, false)
        has_proxy_param  = try(p.integration_path, null) != null && can(regex("\\{proxy\\}", p.integration_path))
        integration_uri = "${lookup(
          local.integration_uri_map,
          p.integration_uri != null ? p.integration_uri : var.integration_uri,
          p.integration_uri != null ? p.integration_uri : var.integration_uri
        )}${try(p.integration_path, "")}"
      }
    ]
  ])

  flat_methods_map = { for m in local.flat_methods : m.key => m }

  # Niveles de cada path
  level_0_keys = toset([for p in var.paths : p.key if p.parent_key == null])
  level_1_keys = toset([for p in var.paths : p.key if p.parent_key != null && contains(local.level_0_keys, p.parent_key)])
  level_2_keys = toset([for p in var.paths : p.key if p.parent_key != null && contains(local.level_1_keys, p.parent_key)])
  level_3_keys = toset([for p in var.paths : p.key if p.parent_key != null && contains(local.level_2_keys, p.parent_key)])
  level_4_keys = toset([for p in var.paths : p.key if p.parent_key != null && contains(local.level_3_keys, p.parent_key)])
  level_5_keys = toset([for p in var.paths : p.key if p.parent_key != null && contains(local.level_4_keys, p.parent_key)])
  level_6_keys = toset([for p in var.paths : p.key if p.parent_key != null && contains(local.level_5_keys, p.parent_key)])
  level_7_keys = toset([for p in var.paths : p.key if p.parent_key != null && contains(local.level_6_keys, p.parent_key)])
  level_8_keys = toset([for p in var.paths : p.key if p.parent_key != null && contains(local.level_7_keys, p.parent_key)])
  level_9_keys = toset([for p in var.paths : p.key if p.parent_key != null && contains(local.level_8_keys, p.parent_key)])

  paths_map = { for p in var.paths : p.key => p }
}

#################################################
# RECURSOS — nivel 0 (raíz)
#################################################
resource "aws_api_gateway_resource" "paths_level_0" {
  for_each = {
    for k in local.level_0_keys : k => local.paths_map[k]
    if local.paths_map[k].existing_resource_id == null
  }

  rest_api_id = var.apigw_id
  parent_id   = var.apigw_root_resource_id
  path_part   = each.value.path_part
}

#################################################
# RECURSOS — nivel 1
#################################################
resource "aws_api_gateway_resource" "paths_level_1" {
  for_each = {
    for k in local.level_1_keys : k => local.paths_map[k]
    if local.paths_map[k].existing_resource_id == null 
  }

  rest_api_id = var.apigw_id
  parent_id = try(
    local.existing_resource_ids[each.value.parent_key],
    aws_api_gateway_resource.paths_level_0[each.value.parent_key].id
  )
  path_part   = each.value.path_part
}

#################################################
# RECURSOS — nivel 2
#################################################
resource "aws_api_gateway_resource" "paths_level_2" {
  for_each = {
    for k in local.level_2_keys : k => local.paths_map[k]
    if local.paths_map[k].existing_resource_id == null 
  }

  rest_api_id = var.apigw_id
  parent_id = try(
    local.existing_resource_ids[each.value.parent_key],
    aws_api_gateway_resource.paths_level_1[each.value.parent_key].id
  )
  path_part   = each.value.path_part
}

#################################################
# RECURSOS — nivel 3
#################################################
resource "aws_api_gateway_resource" "paths_level_3" {
  for_each = {
    for k in local.level_3_keys : k => local.paths_map[k]
    if local.paths_map[k].existing_resource_id == null 
  }

  rest_api_id = var.apigw_id
  parent_id = try(
    local.existing_resource_ids[each.value.parent_key],
    aws_api_gateway_resource.paths_level_2[each.value.parent_key].id
  )
  path_part   = each.value.path_part
}

#################################################
# RECURSOS — nivel 4
#################################################
resource "aws_api_gateway_resource" "paths_level_4" {
  for_each = {
    for k in local.level_4_keys : k => local.paths_map[k]
    if local.paths_map[k].existing_resource_id == null 
  }

  rest_api_id = var.apigw_id
  parent_id = try(
    local.existing_resource_ids[each.value.parent_key],
    aws_api_gateway_resource.paths_level_3[each.value.parent_key].id
  )
  path_part   = each.value.path_part
}

#################################################
# RECURSOS — nivel 5
#################################################
resource "aws_api_gateway_resource" "paths_level_5" {
  for_each = {
    for k in local.level_5_keys : k => local.paths_map[k]
    if local.paths_map[k].existing_resource_id == null 
  }

  rest_api_id = var.apigw_id
  parent_id = try(
    local.existing_resource_ids[each.value.parent_key],
    aws_api_gateway_resource.paths_level_4[each.value.parent_key].id
  ) 
  path_part   = each.value.path_part
}

#################################################
# RECURSOS — nivel 6
#################################################
resource "aws_api_gateway_resource" "paths_level_6" {
  for_each = {
    for k in local.level_6_keys : k => local.paths_map[k]
    if local.paths_map[k].existing_resource_id == null 
  }

  rest_api_id = var.apigw_id
  parent_id = try(
    local.existing_resource_ids[each.value.parent_key],
    aws_api_gateway_resource.paths_level_5[each.value.parent_key].id
  )
  path_part   = each.value.path_part
}

#################################################
# RECURSOS — nivel 7
#################################################
resource "aws_api_gateway_resource" "paths_level_7" {
  for_each = {
    for k in local.level_7_keys : k => local.paths_map[k]
    if local.paths_map[k].existing_resource_id == null 
  }

  rest_api_id = var.apigw_id
  parent_id = try(
    local.existing_resource_ids[each.value.parent_key],
    aws_api_gateway_resource.paths_level_6[each.value.parent_key].id
  ) 
  path_part   = each.value.path_part
}

#################################################
# RECURSOS — nivel 8
#################################################
resource "aws_api_gateway_resource" "paths_level_8" {
  for_each = {
    for k in local.level_8_keys : k => local.paths_map[k]
    if local.paths_map[k].existing_resource_id == null 
  }

  rest_api_id = var.apigw_id
  parent_id = try(
    local.existing_resource_ids[each.value.parent_key],
    aws_api_gateway_resource.paths_level_7[each.value.parent_key].id
  )
  path_part   = each.value.path_part
}

#################################################
# RECURSOS — nivel 9
#################################################
resource "aws_api_gateway_resource" "paths_level_9" {
  for_each = {
    for k in local.level_9_keys : k => local.paths_map[k]
    if local.paths_map[k].existing_resource_id == null 
  }

  rest_api_id = var.apigw_id
  parent_id = try(
    local.existing_resource_ids[each.value.parent_key],
    aws_api_gateway_resource.paths_level_8[each.value.parent_key].id
  )
  path_part   = each.value.path_part
}

#################################################
# MÉTODOS + INTEGRACIÓN NLB
#################################################
resource "aws_api_gateway_method" "methods" {
  for_each = local.flat_methods_map

  rest_api_id      = var.apigw_id
  resource_id      = local.all_resource_ids[each.value.path_key]
  http_method      = each.value.method
  authorization    = local.authorizer_config.authorization
  authorizer_id    = try(local.authorizer_config.authorizer_id, null)
  api_key_required = each.value.api_key_required

  request_parameters = each.value.has_proxy_param ? {
    "method.request.path.proxy" = true
  } : {}

  depends_on = [
    aws_api_gateway_resource.paths_level_0,
    aws_api_gateway_resource.paths_level_1,
    aws_api_gateway_resource.paths_level_2,
    aws_api_gateway_resource.paths_level_3,
    aws_api_gateway_resource.paths_level_4,
    aws_api_gateway_resource.paths_level_5,
    aws_api_gateway_resource.paths_level_6,
    aws_api_gateway_resource.paths_level_7,
    aws_api_gateway_resource.paths_level_8,
    aws_api_gateway_resource.paths_level_9,
  ]
}

resource "aws_api_gateway_integration" "integrations" {
  for_each = local.flat_methods_map

  rest_api_id             = var.apigw_id
  resource_id             = local.all_resource_ids[each.value.path_key]
  http_method             = aws_api_gateway_method.methods[each.key].http_method
  integration_http_method = each.value.method == "ANY" ? "ANY" : each.value.method
  type                    = var.integration_type
  connection_type         = var.connection_type
  connection_id           = var.connection_type == "VPC_LINK" ? var.vpc_link_id : null
  uri                     = each.value.integration_uri

  request_parameters = each.value.has_proxy_param ? {
    "integration.request.path.proxy" = "method.request.path.proxy"
  } : {}
}


resource "aws_api_gateway_method_response" "response_200" {
  for_each = local.flat_methods_map

  rest_api_id = var.apigw_id
  resource_id = local.all_resource_ids[each.value.path_key]
  http_method = aws_api_gateway_method.methods[each.key].http_method
  status_code = "200"

  depends_on = [aws_api_gateway_method.methods]
}

#################################################
# DEPLOYMENT — redespliega el API con las nuevas rutas
#################################################
resource "aws_api_gateway_deployment" "deployment" {
  rest_api_id = var.apigw_id

  triggers = {
    redeployment = sha1(jsonencode([
      values(aws_api_gateway_method.methods),
      values(aws_api_gateway_integration.integrations),
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [
    aws_api_gateway_method.methods,
    aws_api_gateway_integration.integrations,
    aws_api_gateway_method_response.response_200,
  ]
}