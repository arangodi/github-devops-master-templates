#################################################
# ECR REPOSITORIES
#################################################
module "ecr_repositories" {
  for_each = { for r in local.ecr_repositories : r.name => r }

  source = "../../../modules/catalog/compute/ecr"

  name                 = each.value.name
  create               = try(each.value.create, true)
  create_ssm_parameter = try(each.value.create_ssm_parameter, true)
  existing_uri         = try(each.value.uri, null)
  image_tag_mutability = try(each.value.image_tag_mutability, "MUTABLE")
  scan_on_push         = try(each.value.scan_on_push, true)
  encryption_type      = try(each.value.encryption_type, "KMS")
  lifecycle_policy     = try(each.value.lifecycle_policy, null)
  allow_account_ids    = try(each.value.allow_account_ids, [])

  project_name = var.project_name
  account      = var.account
  environment  = var.environment
  tags         = merge(local.project_tags, try(each.value.tags, {}))
}

#################################################
# ECS CLUSTERS
#################################################
module "ecs_clusters" {
  for_each = {
    for k, c in local.ecs_clusters_map : k => c
    if try(c.create, false)
  }

  source = "../../../modules/catalog/compute/ecs-cluster"

  name          = each.value.name
  project_name  = var.project_name
  vpc_id        = local.network.vpc_id
  is_production = var.environment == "pdn"
  account       = var.account
  environment   = var.environment
  tags          = merge(local.project_tags, try(each.value.tags, {}))

}

resource "time_sleep" "wait_for_ec2_registration" {
  count = length([
    for k, ec2 in local.ec2_map : ec2
    if try(ec2.ecs_cluster_name, null) != null
  ]) > 0 ? 1 : 0

  create_duration = "180s"

  depends_on = [module.ec2_instances]
}

#################################################
# ECS SERVICES
#################################################
module "ecs_services" {
  for_each = { for s in local.final_ecs_services : s.name => s }

  source = "../../../modules/catalog/compute/ecs-service"

  name         = each.value.name
  project_name = var.project_name

  cluster_name = module.ecs_clusters[each.value.cluster].name

  vpc_id     = local.network.vpc_id
  subnet_ids = try(local.network.subnets_by_component["EC2"], local.network.private_subnets)

  internal_sg_id     = module.ecs_clusters[each.value.cluster].internal_sg_id
  execution_role_arn = module.ecs_clusters[each.value.cluster].execution_role_arn

  cpu    = try(each.value.task.cpu, 256)
  memory = try(each.value.task.memory, "0.5GB")

  image_repo_uri = try(
    module.ecr_repositories[each.value.name].uri,
    each.value.task.image_repo_uri,
    try(each.value.task.placeholder_image, "public.ecr.aws/nginx/nginx:alpine")
  )

  image_version_ssm_parameter = try(
    each.value.task.image_version_ssm,
    module.ecr_repositories[each.value.name].image_version_parameter_name,
    null
  )

  image_version  = try(each.value.task.image_version, null)
  container_port = try(each.value.task.container_port, 8080)
  environment_vars = try(each.value.task.environment_vars, {})

  containers            = try(each.value.task.containers, [])
  task_role_create      = try(each.value.task.task_role_create, true)
  task_role_arn         = try(each.value.task.task_role_arn, null)
  task_managed_policies = try(each.value.task.task_managed_policies, [])
  s3_bucket_names = [
    for name in try(each.value.task.s3_bucket_names, []) :
    can(regex("^s3-", name)) ? name : "s3-${var.project_name}-${name}"
  ]
  s3_actions = try(each.value.task.s3_actions, ["s3:GetObject", "s3:ListBucket"])

  health_check_path             = try(each.value.task.health_check_path, "/")
  enable_container_health_check = try(each.value.task.enable_container_health_check, false)
  log_retention_days            = try(each.value.task.log_retention_days, 30)

  desired_count             = try(each.value.task.desired_count, 1)
  health_check_grace_period = try(local.elbs[each.value.elb].listener_arn, null) != null ? try(each.value.task.health_check_grace_period, 60) : 0

  elb_listener_arn  = try(local.elbs[each.value.elb].listener_arn, null)
  elb_sg_id         = try(local.elbs[each.value.elb].security_group_id, null)
  base_path         = try(each.value.base_path, "/")
  listener_priority = try(each.value.listener_priority, 1)

  namespace_id = try(
    local.namespaces[each.value.namespace].id,
    local.default_namespace_id,
    null
  )

  min_containers           = try(each.value.autoscaling.min, 1)
  max_containers           = try(each.value.autoscaling.max, 4)
  autoscaling_target_value = try(each.value.autoscaling.target_cpu, 80)
  autoscaling_role_arn     = module.ecs_clusters[each.value.cluster].autoscaling_role_arn

  secrets_arns = {
    for secret_name in try(each.value.task.secrets, []) :
    secret_name => try(
      data.terraform_remote_state.security.outputs.secrets[secret_name].secret_arn,
      data.aws_secretsmanager_secret.external[secret_name].arn,
      null
    )
  }

  secrets = try(each.value.task.secrets, [])


  use_placeholder_image = try(each.value.task.use_placeholder, false)
  placeholder_image     = try(each.value.task.placeholder_image, "public.ecr.aws/nginx/nginx:alpine")

  launch_type = try(each.value.task.launch_type, "FARGATE")

  efs_volumes = [
    for vol in try(each.value.efs, []) : {
      name            = vol.name
      file_system_id  = data.terraform_remote_state.storage.outputs.efs_filesystems[vol.filesystem].filesystem_id
      access_point_id = try(
        data.terraform_remote_state.storage.outputs.efs_filesystems[vol.filesystem].access_point_ids[vol.access_point],
        null
      )
      mount_path = vol.mount_path
      read_only  = try(vol.read_only, false)
    }
  ]

  target_groups = [
    for tg in try(each.value.target_groups, []) : {
      container_name    = tg.container_name
      container_port    = tg.container_port
      path              = tg.path
      listener_priority = tg.listener_priority
      health_check_path = try(tg.health_check_path, "/")
      protocol          = try(tg.protocol, "HTTP")
    }
  ]

  nlb_arn = try(local.elbs[each.value.elb].load_balancer_type, "application") == "network" ? try(local.elbs[each.value.elb].arn, null) : null

  account     = var.account
  environment = var.environment
  tags        = merge(local.project_tags, try(each.value.tags, {}))

  depends_on = [
    module.ecr_repositories,
    time_sleep.wait_for_ec2_registration,
  ]
}

#################################################
# EKS CLUSTERS
#################################################
module "eks_clusters" {
  for_each = {
    for k, c in local.eks_clusters_map : k => c
    if try(c.create, false)
  }

  source = "../../../modules/catalog/compute/eks-cluster"

  name         = each.value.name
  project_name = var.project_name
  vpc_id       = local.network.vpc_id
  subnet_ids   = try(local.network.subnets_by_component["EC2"], local.network.private_subnets)

  kubernetes_version = try(each.value.kubernetes_version, null)
  enable_irsa        = try(each.value.enable_irsa, false)

  authentication_mode             = try(each.value.authentication_mode, "API_AND_CONFIG_MAP")
  access_entries                  = try(each.value.access_entries, [])
  enable_load_balancer_controller = try(each.value.enable_load_balancer_controller, false)

  node_groups      = try(each.value.node_groups, [])
  fargate_profiles = try(each.value.fargate_profiles, [])

  addon_coredns_version    = try(each.value.addon_coredns_version, null)
  addon_kube_proxy_version = try(each.value.addon_kube_proxy_version, null)
  addon_vpc_cni_version    = try(each.value.addon_vpc_cni_version, null)

  secrets = try(each.value.secrets, [])

  account     = var.account
  environment = var.environment
  tags        = merge(local.project_tags, try(each.value.tags, {}))
}

#################################################
# EC2 INSTANCES
#################################################
module "ec2_instances" {
  for_each = local.ec2_map

  source = "../../../modules/catalog/compute/ec2"

  name          = each.value.name
  os_type       = try(each.value.os_type, "linux")
  instance_type = try(each.value.instance_type, "t3.micro")
  ami_id        = try(each.value.ami_id, null)

  vpc_id = local.network.vpc_id
  subnet_ids = try(
    local.network.subnets_by_component[try(each.value.subnet_group, "EC2")],
    local.network.private_subnets
  )

  eni_id = try(
    local.eni_interfaces[each.value.eni_name].eni_id,
    null
  )

  key_name   = try(each.value.key_name, null)
  enable_ssm = try(each.value.enable_ssm, true)
  enable_rdp = try(each.value.enable_rdp, false)

  root_volume_size      = try(each.value.root_volume_size, try(each.value.os_type, "linux") == "windows" ? 50 : 20)
  root_volume_type      = try(each.value.root_volume_type, "gp3")
  root_volume_encrypted = try(each.value.root_volume_encrypted, true)
  ebs_volumes           = try(each.value.ebs_volumes, [])

  user_data_script = try(each.value.ecs_cluster_name, null) != null ? "ecs-agent.sh" : try(each.value.user_data_script, null)

  user_data_vars = try(each.value.ecs_cluster_name, null) != null ? {
    cluster_name = module.ecs_clusters[each.value.ecs_cluster_name].name
  } : try(each.value.user_data_vars, {})

  user_data = try(each.value.user_data, null)

  ecs_cluster_name = try(each.value.ecs_cluster_name, null) != null ? module.ecs_clusters[each.value.ecs_cluster_name].name : null

  create_asg                = try(each.value.create_asg, false)
  asg_min_size              = try(each.value.asg_min_size, 1)
  asg_max_size              = try(each.value.asg_max_size, 3)
  asg_desired_size          = try(each.value.asg_desired_size, 1)
  on_demand_base_capacity   = try(each.value.on_demand_base_capacity, 1)
  on_demand_percentage      = try(each.value.on_demand_percentage, 100)
  spot_instance_pools       = try(each.value.spot_instance_pools, 2)
  additional_instance_types = try(each.value.additional_instance_types, [])

  additional_sg_ids = try(each.value.additional_sg_ids, [])
  ingress_rules     = try(each.value.ingress_rules, [])

  secrets = try(each.value.secrets, [])

  project_name = var.project_name
  environment  = var.environment
  tags         = merge(local.project_tags, try(each.value.tags, {}))

  depends_on = [module.ecs_clusters]
}
