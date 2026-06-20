data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

# Data source para API Gateway existente
data "aws_api_gateway_rest_api" "existing" {
  count = var.existing_api_name != null ? 1 : 0
  name  = var.existing_api_name
}

# Data source para Cognito User Pool existente
data "aws_cognito_user_pool" "existing" {
  count        = var.existing_user_pool_id != null ? 1 : 0
  user_pool_id = var.existing_user_pool_id
}

data "aws_api_gateway_domain_name" "existing_domain" {
  count       = var.existing_custom_domain_name != null ? 1 : 0
  domain_name = var.existing_custom_domain_name
}

locals {
  safe_environment = replace(lower(var.environment), ".", "-")
  api_name         = lower("apigw-${var.project_name}-${var.name}")
  log_group_name   = "/aws/apigateway/${var.project_name}/${local.safe_environment}/${var.name}"

  rest_api_id               = var.existing_api_name != null ? data.aws_api_gateway_rest_api.existing[0].id : try(aws_api_gateway_rest_api.this[0].id, null)
  rest_api_root_resource_id = var.existing_api_name != null ? data.aws_api_gateway_rest_api.existing[0].root_resource_id : try(aws_api_gateway_rest_api.this[0].root_resource_id, null)

  # Resuelve el User Pool — data source obtiene ARN automáticamente
  user_pool_id  = var.existing_user_pool_id != null ? var.existing_user_pool_id : try(aws_cognito_user_pool.this[0].id, null)
  user_pool_arn = var.existing_user_pool_id != null ? data.aws_cognito_user_pool.existing[0].arn : try(aws_cognito_user_pool.this[0].arn, null)

  cognito_client_name = var.client_name != null ? lower(replace(var.client_name, " ", "-")) : var.project_name

  custom_domain_name = var.existing_custom_domain_name != null ? var.existing_custom_domain_name : var.custom_domain_name

  common_tags = merge({
    Name         = local.api_name
    project_name = var.project_name
    Ambiente     = var.environment
    module       = "catalog/networking/api-gateway/base"
  }, var.tags)
}

#################################################
# API GATEWAY ACCOUNT — opcional
#################################################
resource "aws_api_gateway_account" "this" {
  count               = var.cloudwatch_role_arn != null ? 1 : 0
  cloudwatch_role_arn = var.cloudwatch_role_arn
}

#################################################
# CLOUDWATCH LOG GROUP — opcional
#################################################
resource "aws_cloudwatch_log_group" "api_gw_logs" {
  count             = var.cloudwatch_role_arn != null ? 1 : 0
  name              = local.log_group_name
  retention_in_days = var.log_retention_days
  tags              = local.common_tags
}

#################################################
# REST API — solo si no hay uno existente
#################################################
resource "aws_api_gateway_rest_api" "this" {
  count = var.existing_api_name == null ? 1 : 0 

  name        = local.api_name
  description = var.description != null ? var.description : "API Gateway para ${var.project_name}"

  endpoint_configuration {
    types            = [var.endpoint_type]
    vpc_endpoint_ids = var.endpoint_type == "PRIVATE" ? var.vpc_endpoint_ids : null
  }

  tags = local.common_tags
}

#################################################
# COGNITO USER POOL — solo si no hay uno existente
#################################################
resource "aws_cognito_user_pool" "this" {
  count = var.enable_cognito && var.existing_user_pool_id == null ? 1 : 0

  name = lower("btgpactual-${local.cognito_client_name}-app")

  password_policy {
    minimum_length    = 8
    require_lowercase = true
    require_numbers   = true
    require_symbols   = true
    require_uppercase = true
  }

  tags = local.common_tags
}

resource "aws_cognito_user_pool_domain" "this" {
  count = var.enable_cognito && var.enable_cognito_domain && var.existing_user_pool_id == null ? 1 : 0

  domain       = var.cognito_domain_prefix != "" ? var.cognito_domain_prefix : "${var.project_name}"
  user_pool_id = local.user_pool_id
}

resource "aws_cognito_resource_server" "this" {
  for_each = var.enable_cognito && var.existing_user_pool_id == null ? { for rs in var.resource_servers : rs.identifier => rs } : {}

  identifier   = each.value.identifier
  name         = each.value.name
  user_pool_id = local.user_pool_id

  dynamic "scope" {
    for_each = each.value.scopes
    content {
      scope_name        = scope.value.name
      scope_description = scope.value.description
    }
  }
}

resource "aws_cognito_user_pool_client" "this" {
  count = var.enable_cognito && var.existing_user_pool_id == null ? 1 : 0

  name         = lower("btgpactual-${local.cognito_client_name}-app")
  user_pool_id = local.user_pool_id

  generate_secret = var.enable_client_credentials ? true : false

  access_token_validity  = var.access_token_validity
  id_token_validity      = var.id_token_validity
  refresh_token_validity = var.refresh_token_validity

  token_validity_units {
    access_token  = "minutes"
    id_token      = "minutes"
    refresh_token = "days"
  }

  enable_token_revocation              = var.enable_token_revocation
  allowed_oauth_flows                  = var.enable_client_credentials ? ["client_credentials"] : []
  allowed_oauth_flows_user_pool_client = var.enable_client_credentials ? true : false

  allowed_oauth_scopes = var.enable_client_credentials ? flatten([
    for rs in aws_cognito_resource_server.this : [
      for scope in rs.scope_identifiers : scope
    ]
  ]) : []

  explicit_auth_flows = [
    "ALLOW_REFRESH_TOKEN_AUTH",
    "ALLOW_USER_PASSWORD_AUTH",
    "ALLOW_USER_SRP_AUTH"
  ]

  depends_on = [aws_cognito_resource_server.this]
}

#################################################
# AUTORIZADOR COGNITO
#################################################
resource "aws_api_gateway_authorizer" "cognito" {
  count = var.enable_cognito ? 1 : 0
  

  name            = "cognito-authorizer"
  rest_api_id     = local.rest_api_id
  type            = "COGNITO_USER_POOLS"
  identity_source = "method.request.header.Authorization"
  provider_arns   = [local.user_pool_arn]
}

#################################################
# VPC LINK
#################################################
resource "aws_security_group" "vpc_link" {
  count = var.enable_vpc_link ? 1 : 0

  name        = lower("secg-${var.project_name}-${var.name}-vpclink")
  description = "SG para VPC Link de ${local.api_name}"
  vpc_id      = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  #tags = merge(local.common_tags, {
  #  Name = lower("secg-${var.project_name}-${var.name}-vpclink")
  #})
}

resource "aws_api_gateway_vpc_link" "this" {
  count = var.enable_vpc_link ? 1 : 0

  name        = lower("vpclink-${var.project_name}-${var.name}")
  description = "VPC Link para ${local.api_name}"
  target_arns = [var.nlb_arn]

  #tags = local.common_tags
}

#################################################
# DUMMY ENDPOINT
#################################################
resource "aws_api_gateway_resource" "dummy" {
  count = var.enable_dummy_endpoint ? 1 : 0

  rest_api_id = local.rest_api_id 
  parent_id   = local.rest_api_root_resource_id 
  path_part   = "health"
}

resource "aws_api_gateway_method" "dummy_get" {
  count = var.enable_dummy_endpoint ? 1 : 0

  rest_api_id   = local.rest_api_id
  resource_id   = aws_api_gateway_resource.dummy[0].id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "dummy" {
  count = var.enable_dummy_endpoint ? 1 : 0

  rest_api_id = local.rest_api_id
  resource_id = aws_api_gateway_resource.dummy[0].id
  http_method = aws_api_gateway_method.dummy_get[0].http_method
  type        = "MOCK"

  request_templates = {
    "application/json" = jsonencode({ statusCode = 200 })
  }
}

resource "aws_api_gateway_method_response" "dummy_response" {
  count = var.enable_dummy_endpoint ? 1 : 0

  rest_api_id = local.rest_api_id
  resource_id = aws_api_gateway_resource.dummy[0].id
  http_method = aws_api_gateway_method.dummy_get[0].http_method
  status_code = "200"
}

#################################################
# DEPLOYMENT
#################################################
resource "aws_api_gateway_deployment" "this" {
  count = var.existing_api_name == null ? 1 : 0

  rest_api_id = local.rest_api_id

  triggers = {
    redeployment = sha1(jsonencode([
      try(aws_api_gateway_rest_api.this[0].body, ""),
      var.enable_dummy_endpoint ? aws_api_gateway_integration.dummy[0].id : ""
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [
    aws_api_gateway_method.dummy_get,
    aws_api_gateway_integration.dummy
  ]
}

#################################################
# STAGE
#################################################
resource "aws_api_gateway_stage" "this" {
  count = var.create_stage && var.existing_api_name == null ? 1 : 0

  stage_name    = local.safe_environment
  rest_api_id   = local.rest_api_id
  deployment_id = aws_api_gateway_deployment.this[0].id

  dynamic "access_log_settings" {
    for_each = var.cloudwatch_role_arn != null ? [1] : []
    content {
      destination_arn = aws_cloudwatch_log_group.api_gw_logs[0].arn
      format = jsonencode({
        requestId      = "$context.requestId"
        ip             = "$context.identity.sourceIp"
        caller         = "$context.identity.caller"
        user           = "$context.identity.user"
        requestTime    = "$context.requestTime"
        httpMethod     = "$context.httpMethod"
        resourcePath   = "$context.resourcePath"
        status         = "$context.status"
        protocol       = "$context.protocol"
        responseLength = "$context.responseLength"
      })
    }
  }

  tags = local.common_tags

  depends_on = [aws_api_gateway_account.this]
}

#################################################
# METHOD SETTINGS — opcional
#################################################
resource "aws_api_gateway_method_settings" "this" {
  count = var.create_stage && var.cloudwatch_role_arn != null ? 1 : 0

  rest_api_id = local.rest_api_id
  stage_name  = aws_api_gateway_stage.this[0].stage_name
  method_path = "*/*"

  settings {
    logging_level      = var.logging_level
    metrics_enabled    = var.enable_method_metrics
    data_trace_enabled = var.enable_data_trace
  }

  depends_on = [aws_api_gateway_stage.this]
}

#################################################
# API KEY + USAGE PLAN
#################################################
resource "aws_api_gateway_api_key" "this" {
  count = var.enable_api_key ? 1 : 0

  name        = lower("${var.project_name}-${var.name}-api-key")
  description = "API Key para ${local.api_name}"
  enabled     = true

  tags = local.common_tags
}

resource "aws_api_gateway_usage_plan" "this" {
  count = var.enable_api_key ? 1 : 0

  name = lower("${var.project_name}-${var.name}-usage-plan")

  api_stages {
    api_id = local.rest_api_id  
    stage  = var.create_stage && var.existing_api_name == null ? aws_api_gateway_stage.this[0].stage_name : local.safe_environment
  }

  quota_settings {
    limit  = var.quota_limit
    period = var.quota_period
  }

  throttle_settings {
    rate_limit  = var.throttle_rate_limit
    burst_limit = var.throttle_burst_limit
  }

  tags = local.common_tags

  depends_on = [aws_api_gateway_stage.this]
}

resource "aws_api_gateway_usage_plan_key" "this" {
  count = var.enable_api_key ? 1 : 0

  key_id        = aws_api_gateway_api_key.this[0].id
  key_type      = "API_KEY"
  usage_plan_id = aws_api_gateway_usage_plan.this[0].id
}

#################################################
# CUSTOM DOMAIN
#################################################
resource "aws_api_gateway_domain_name" "this" {
  count = var.enable_custom_domain && var.custom_domain_name != "" && var.existing_custom_domain_name == null ? 1 : 0

  domain_name              = var.custom_domain_name
  regional_certificate_arn = var.custom_domain_certificate_arn
  security_policy          = var.custom_domain_security_policy

  endpoint_configuration {
    types = ["REGIONAL"]
  }

  tags = local.common_tags
}

resource "aws_api_gateway_base_path_mapping" "this" {
  count = var.enable_custom_domain && (var.custom_domain_name != "" || var.existing_custom_domain_name != null) ? 1 : 0

  domain_name = local.custom_domain_name
  api_id      = local.rest_api_id 
  stage_name  = var.create_stage && var.existing_api_name == null ? aws_api_gateway_stage.this[0].stage_name : local.safe_environment
  base_path   = var.custom_domain_base_path

  depends_on = [aws_api_gateway_deployment.this]
}