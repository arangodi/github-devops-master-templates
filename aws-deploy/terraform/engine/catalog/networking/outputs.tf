output "elbs" {
  description = "Map de ELBs creados — key es el nombre del ELB"
  value = {
    for k, m in module.elbs : k => {
      arn               = m.arn
      dns_name          = m.dns_name
      listener_arn      = m.listener_arn
      security_group_id = m.security_group_id
      zone_id           = m.zone_id
      load_balancer_type = try(local.elbs_map[k].load_balancer_type, "application")
    }
  }
}

output "namespaces" {
  description = "Map de namespaces creados — key es el nombre del namespace"
  value = {
    for k, m in module.namespaces : k => {
      id   = m.id
      arn  = m.arn
      name = m.name
    }
  }
}

output "eni_interfaces" {
  description = "Map de ENIs creados — key es el nombre del ENI"
  value = {
    for k, m in module.eni_interfaces : k => {
      eni_id      = m.eni_id
      private_ip  = m.private_ip
      subnet_id   = m.subnet_id
      mac_address = m.mac_address
    }
  }
}

output "api_gateways" {
  description = "Map de API Gateways creados — key es el nombre del API Gateway"
  value = {
    for k, m in module.api_gateway_base : k => {
      api_name                   = m.api_name                   
      rest_api_id                = m.rest_api_id
      rest_api_arn               = m.rest_api_arn
      rest_api_execution_arn     = m.rest_api_execution_arn
      rest_api_root_resource_id  = m.rest_api_root_resource_id
      stage_name                 = m.stage_name
      invoke_url                 = m.invoke_url
      authorizer_id              = m.authorizer_id
      vpc_link_id                = m.vpc_link_id
      vpc_link_sg_id             = m.vpc_link_sg_id
      api_key_id                 = m.api_key_id
      usage_plan_id              = m.usage_plan_id
      user_pool_id               = m.user_pool_id
      user_pool_client_id        = m.user_pool_client_id
      user_pool_domain           = m.user_pool_domain
      custom_domain_name         = m.custom_domain_name
      custom_domain_target       = m.custom_domain_target
      custom_domain_base_path    = m.custom_domain_base_path    
      custom_domain_url          = m.custom_domain_url          
      log_group_name             = m.log_group_name
    }
  }
}

output "api_gateway_routes" {
  description = "Map de rutas de API Gateway creadas — key es el nombre de la ruta"
  value = {
    for k, m in module.api_gateway_routes : k => {
      name             = k
      api_gateway_id   = m.apigw_id
      deployment_id    = m.deployment_id
      paths_created    = m.paths_created
      integration_type = m.integration_type
      connection_type  = m.connection_type
      methods_created  = m.methods_created
    }
  }
}

output "websocket_apis" {
  description = "Map de WebSocket APIs — key es el nombre del API"
  value = {
    for k, m in module.websocket_api_base : k => {
      api_id            = m.api_id
      api_name          = m.api_name
      api_endpoint      = m.api_endpoint
      invoke_url        = m.invoke_url
      stage_name        = m.stage_name
      stage_id          = m.stage_id
      vpc_link_id       = m.vpc_link_id
      vpc_link_arn      = m.vpc_link_arn
      security_group_id = m.security_group_id
    }
  }
}