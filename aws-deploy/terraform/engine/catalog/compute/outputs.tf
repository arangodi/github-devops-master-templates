output "ecr_repositories" {
  description = "Map de los ECR creados — key es el nombre del ECR"
  value = {
    for k, m in module.ecr_repositories : k => {
      uri                          = m.uri
      arn                          = m.arn
      name                         = m.name
      image_version_parameter_name = m.image_version_parameter_name  
      image_version_parameter_arn  = m.image_version_parameter_arn   
    }
  }
}

output "ecs_clusters" {
  description = "Map de los ECS cluster creados — key es el nombre del ECS cluster"
  value = {
    for k, m in module.ecs_clusters : k => {
      name              = m.name
      id = m.id
      internal_sg_id = m.internal_sg_id
      execution_role_arn = m.execution_role_arn
      autoscaling_role_arn = m.autoscaling_role_arn
    }
  }
}

output "ecs_services" {
  description = "Map de los ECS services creados — key es el nombre del servicio"
  value = {
    for k, m in module.ecs_services : k => {
      service_name       = m.service_name        
      service_arn        = m.service_arn      
      task_definition_arn = m.task_definition_arn
      task_role_arn      = m.task_role_arn        
      container_sg_id    = m.container_sg_id     
      target_group_arn   = m.target_group_arn     
      log_group_name     = m.log_group_name        
    }
  }
}

output "eks_clusters" {
  description = "Map de los EKS clusters creados — key es el nombre lógico del cluster"
  value = {
    for k, m in module.eks_clusters : k => {
      cluster_name      = m.cluster_name
      cluster_arn       = m.cluster_arn
      cluster_endpoint  = m.cluster_endpoint
      cluster_ca        = m.cluster_ca
      cluster_sg_id     = m.cluster_sg_id
      node_role_arn     = m.node_role_arn
      oidc_provider_arn = m.oidc_provider_arn
      oidc_provider_url = m.oidc_provider_url
      lbc_role_arn      = m.lbc_role_arn
    }
  }
}

output "ec2_instances" {
  description = "Map de las EC2 creados — key es el nombre lógico del EC2"
  value = {
    for k, m in module.ec2_instances : k => {
      instance_id                 = m.instance_id
      private_ip                  = m.private_ip
      security_group_id           = m.security_group_id
      iam_role_arn                = m.iam_role_arn
      launch_template_id          = m.launch_template_id
      launch_template_version     = m.launch_template_version
    }
  }
}