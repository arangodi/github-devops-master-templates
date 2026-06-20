data "aws_region" "current" {}
data "aws_caller_identity" "current" {}
data "aws_ssm_parameter" "image_version" {
  count = var.image_version_ssm_parameter != null ? 1 : 0
  name  = var.image_version_ssm_parameter
}

locals {
  safe_environment  = replace(lower(var.environment), ".", "-")
  service_full_name = lower("ecs-${var.project_name}-${var.name}")
  log_group_name    = "/ecs/task/${var.project_name}/${local.safe_environment}/${var.name}"

  resolved_image_version = coalesce(
    var.image_version_ssm_parameter != null ? try(data.aws_ssm_parameter.image_version[0].value, null) : null,
    var.image_version,
    "latest"
  )

  ecr_image_uri = "${var.image_repo_uri}:${local.resolved_image_version}"

  use_real_image = local.resolved_image_version != "latest"

  final_image_uri = local.use_real_image ? local.ecr_image_uri : var.placeholder_image

  common_tags = merge({
    Name         = local.service_full_name
    project_name = var.project_name
    module       = "catalog/compute/ecs-service"
  }, var.tags)
}

#################################################
# TASK ROLE
#################################################
resource "aws_iam_role" "task" {
  count = var.task_role_create ? 1 : 0

  name = "iam-${lower(var.project_name)}-${lower(var.name)}-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = merge(local.common_tags, {
    Name = "iam-${lower(var.project_name)}-${lower(var.name)}-task-role"
  })
}

resource "aws_iam_role_policy_attachment" "task_s3_all" {
  count = var.task_role_create && length(var.s3_bucket_names) == 0 ? 1 : 0

  role       = aws_iam_role.task[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"
}

resource "aws_iam_role_policy" "task_s3_restricted" {
  count = var.task_role_create && length(var.s3_bucket_names) > 0 ? 1 : 0

  name = "s3-restricted-access"
  role = aws_iam_role.task[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = var.s3_actions
      Resource = flatten([
        for name in var.s3_bucket_names : [
          "arn:aws:s3:::${name}",
          "arn:aws:s3:::${name}/*"
        ]
      ])
    }]
  })
}

resource "aws_iam_role_policy_attachment" "task_managed" {
  for_each = var.task_role_create ? toset(var.task_managed_policies) : toset([])

  role       = aws_iam_role.task[0].name
  policy_arn = each.value
}

resource "time_sleep" "wait_for_iam" {
  count = var.task_role_create ? 1 : 0

  create_duration = "15s"

  depends_on = [
    aws_iam_role.task,
    aws_iam_role_policy_attachment.task_s3_all,
    aws_iam_role_policy.task_s3_restricted,
    aws_iam_role_policy_attachment.task_managed,
    aws_iam_role_policy.secrets_access
  ]
}

#################################################
# CLOUDWATCH LOG GROUP
#################################################
resource "aws_cloudwatch_log_group" "this" {
  name              = local.log_group_name
  retention_in_days = var.log_retention_days
  tags              = local.common_tags
}

#################################################
# TASK DEFINITION
#################################################
resource "aws_ecs_task_definition" "this" {
  family = "${local.service_full_name}-task"

  network_mode             = var.launch_type == "EC2" ? "bridge" : "awsvpc"
  requires_compatibilities = [var.launch_type]

  cpu    = var.launch_type == "FARGATE" ? var.cpu : null
  memory = var.launch_type == "FARGATE" ? var.memory : null

  execution_role_arn = var.execution_role_arn
  task_role_arn      = var.task_role_create ? aws_iam_role.task[0].arn : var.task_role_arn

 
  container_definitions = jsonencode(concat(
    [{
      name  = var.name
      image = local.final_image_uri

      environment = [
      for k, v in var.environment_vars : { name = k, value = v }
      ]

      command = !local.use_real_image ? [
        "/bin/sh", "-c",
        "echo 'server { listen ${var.container_port}; location / { return 200; } }' > /etc/nginx/conf.d/default.conf && nginx -g 'daemon off;'"
      ] : null

      memory = var.launch_type == "EC2" ? (
        var.memory == "0.5GB" ? 512 :
        can(tonumber(var.memory)) ? tonumber(var.memory) :
        tonumber(replace(var.memory, "GB", "")) * 1024
      ) : null

      portMappings = [{
        containerPort = var.container_port
        hostPort      = var.launch_type == "EC2" ? 0 : var.container_port
        protocol      = "tcp"
      }]

      mountPoints = length(var.efs_volumes) > 0 ? [
        for vol in var.efs_volumes : {
          sourceVolume  = vol.name
          containerPath = vol.mount_path
          readOnly      = vol.read_only
        }
      ] : []

      linuxParameters = {
        initProcessEnabled = true
      }

      secrets = var.use_placeholder_image ? [] : [
        for secret_name in var.secrets : {
          name      = upper(replace(secret_name, "-", "_"))
          valueFrom = try(
            var.secrets_arns[secret_name],
            "arn:aws:secretsmanager:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:secret:${lower(var.project_name)}-${secret_name}"
          )
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-region        = data.aws_region.current.name
          awslogs-group         = local.log_group_name
          awslogs-stream-prefix = "ecs"
        }
      }

      healthCheck = var.enable_container_health_check ? {
        command     = ["CMD-SHELL", "curl -f http://localhost:${var.container_port}${var.health_check_path} || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 60
      } : null
    }],

    [for c in var.containers : {
      name      = c.name
      image     = c.image
      essential = c.essential
      cpu       = c.cpu

      memory = c.memory != null ? (
        can(tonumber(c.memory)) ? tonumber(c.memory) :
        c.memory == "0.5GB" ? 512 :
        tonumber(replace(c.memory, "GB", "")) * 1024
      ) : null

      privileged = c.privileged

      portMappings = c.container_port != null ? [{
        containerPort = c.container_port
        hostPort      = var.launch_type == "EC2" ? 0 : c.container_port
        protocol      = "tcp"
      }] : []

      environment = [
        for k, v in c.environment : { name = k, value = v }
      ]

      mountPoints = [
        for mp in c.mount_paths : {
          sourceVolume  = mp.source_volume
          containerPath = mp.container_path
          readOnly      = mp.read_only
        }
      ]

      dependsOn = [
        for dep in c.depends_on_containers : {
          containerName = dep.container_name
          condition     = dep.condition
        }
      ]

      linuxParameters = {
        initProcessEnabled = true
        capabilities = c.linux_parameters != null ? {
          add  = try(c.linux_parameters.capabilities.add, [])
          drop = try(c.linux_parameters.capabilities.drop, [])
        } : {
          add  = []
          drop = []
        }
      }

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-region        = data.aws_region.current.name
          awslogs-group         = local.log_group_name
          awslogs-stream-prefix = c.name
        }
      }
    }]
  ))

  dynamic "volume" {
    for_each = var.efs_volumes
    content {
      name = volume.value.name

      efs_volume_configuration {
        file_system_id     = volume.value.file_system_id
        transit_encryption = "ENABLED"

        dynamic "authorization_config" {
          for_each = volume.value.access_point_id != null ? [1] : []
          content {
            access_point_id = volume.value.access_point_id
            iam             = "ENABLED"
          }
        }
      }
    }
  }

  tags = local.common_tags

  depends_on = [
    aws_cloudwatch_log_group.this,
    time_sleep.wait_for_iam
  ]
}

#################################################
# SECURITY GROUP DEL CONTENEDOR
#################################################
resource "aws_security_group" "container" {
  name        = "secg-${lower(var.project_name)}-${lower(var.name)}-container"
  description = "SG for container ${var.project_name}-${var.environment}-${var.name}"
  vpc_id      = var.vpc_id
  tags        = local.common_tags
}

# ALB — tráfico desde el SG del ALB
resource "aws_vpc_security_group_ingress_rule" "from_elb" {
  count = var.elb_sg_id != null ? 1 : 0

  security_group_id            = aws_security_group.container.id
  referenced_security_group_id = var.elb_sg_id
  from_port                    = var.container_port
  to_port                      = var.container_port
  ip_protocol                  = "tcp"
  description                  = "Trafico desde el ELB al contenedor"
}

# NLB — tráfico por CIDR porque NLB no tiene SG
resource "aws_vpc_security_group_ingress_rule" "from_nlb" {
  count = var.nlb_arn != null ? 1 : 0

  security_group_id = aws_security_group.container.id
  cidr_ipv4         = "10.0.0.0/8"
  from_port         = var.container_port
  to_port           = var.container_port
  ip_protocol       = "tcp"
  description       = "Trafico desde el NLB al contenedor"
}

resource "aws_vpc_security_group_egress_rule" "all" {
  security_group_id = aws_security_group.container.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
  description       = "Todo el trafico saliente"
}

#################################################
# LISTENER RULE — simple (comportamiento actual)
#################################################
resource "aws_lb_target_group" "this" {
  count = var.elb_listener_arn != null && length(var.target_groups) == 0 ? 1 : 0
  name             = lower("${var.project_name}-${var.name}")
  port             = var.container_port
  protocol         = "HTTP"
  protocol_version = "HTTP1"
  target_type      = var.launch_type == "EC2" ? "instance" : "ip"
  vpc_id           = var.vpc_id
  health_check {
    path                = var.health_check_path
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
  deregistration_delay = 60
  tags = merge(local.common_tags, {
    Name = "elb-${lower(var.project_name)}-${lower(var.name)}-tg"
  })

  lifecycle {
    create_before_destroy = true
  }
}

#################################################
# TARGET GROUPS MÚLTIPLES
#################################################
resource "aws_lb_target_group" "multi" {
  for_each = { for tg in var.target_groups : tg.container_name => tg }

  name             = lower("${var.project_name}-${each.key}")
  port             = each.value.container_port
  protocol         = each.value.protocol
  protocol_version = "HTTP1"
  target_type      = var.launch_type == "EC2" ? "instance" : "ip"
  vpc_id           = var.vpc_id

  health_check {
    path                = each.value.health_check_path
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  deregistration_delay = 60

  tags = merge(local.common_tags, {
    Name = "elb-${lower(var.project_name)}-${lower(each.key)}-tg"
  })
}

#################################################
# TARGET GROUP NLB — TCP por puerto del container
#################################################
resource "aws_lb_target_group" "nlb" {
  count = var.nlb_arn != null ? 1 : 0

  name        = lower("${var.name}-tg")
  port        = var.container_port
  protocol    = "TCP"
  target_type = var.launch_type == "EC2" ? "instance" : "ip"
  vpc_id      = var.vpc_id

  #health_check {
  #  protocol            = "TCP"
  #  interval            = 30
  #  healthy_threshold   = 2
  #  unhealthy_threshold = 2
  #}

  deregistration_delay = 60

  tags = merge(local.common_tags, {
    Name = "nlb-${lower(var.project_name)}-${lower(var.name)}-tg"
  })
}

resource "aws_lb_listener" "nlb" {
  count = var.nlb_arn != null ? 1 : 0

  load_balancer_arn = var.nlb_arn
  port              = var.container_port
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.nlb[0].arn
  }

  tags = local.common_tags
}

resource "aws_lb_listener_rule" "multi" {
  for_each = { for tg in var.target_groups : tg.container_name => tg }

  listener_arn = var.elb_listener_arn
  priority     = each.value.listener_priority

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.multi[each.key].arn
  }

  condition {
    path_pattern {
      values = ["${each.value.path}/*"]
    }
  }

  tags = local.common_tags
}

#################################################
# SERVICE DISCOVERY SERVICE
#################################################
resource "aws_service_discovery_service" "this" {
  count = var.namespace_id != null ? 1 : 0

  name = var.name

  dns_config {
    namespace_id   = var.namespace_id
    routing_policy = var.launch_type == "EC2" ? "WEIGHTED" : "MULTIVALUE"

    dynamic "dns_records" {
      for_each = var.launch_type == "FARGATE" ? [1] : []
      content {
        ttl  = 60
        type = "A"
      }
    }

    dns_records {
      ttl  = 60
      type = "SRV"
    }
  }

  tags = merge(local.common_tags, {
    Name = "dsrv-${lower(var.project_name)}-${lower(var.name)}"
  })
}

#################################################
# ECS SERVICE
#################################################
resource "aws_ecs_service" "this" {
  name            = "${local.service_full_name}-service"
  cluster         = var.cluster_name
  task_definition = aws_ecs_task_definition.this.arn
  desired_count   = var.desired_count

  launch_type = var.launch_type

  propagate_tags                    = "TASK_DEFINITION"
  enable_execute_command            = true
  health_check_grace_period_seconds = var.health_check_grace_period
  wait_for_steady_state             = var.launch_type == "EC2" ? false : true

  deployment_minimum_healthy_percent = 100
  deployment_maximum_percent         = 200

  dynamic "network_configuration" {
    for_each = var.launch_type == "FARGATE" ? [1] : []
    content {
      subnets          = var.subnet_ids
      security_groups  = compact([var.internal_sg_id, aws_security_group.container.id])
      assign_public_ip = false
    }
  }

  # Un solo TG
  dynamic "load_balancer" {
    for_each = var.elb_listener_arn != null && length(var.target_groups) == 0 ? [1] : []
    content {
      target_group_arn = aws_lb_target_group.this[0].arn
      container_name   = var.name
      container_port   = var.container_port
    }
  }

  # Múltiples TGs
  dynamic "load_balancer" {
    for_each = { for tg in var.target_groups : tg.container_name => tg }
    content {
      target_group_arn = aws_lb_target_group.multi[load_balancer.key].arn
      container_name   = load_balancer.value.container_name
      container_port   = load_balancer.value.container_port
    }
  }

  dynamic "load_balancer" {
    for_each = var.nlb_arn != null ? [1] : []
    content {
      target_group_arn = aws_lb_target_group.nlb[0].arn
      container_name   = var.name
      container_port   = var.container_port
    }
  }

  dynamic "service_registries" {
    for_each = var.namespace_id != null ? [1] : []
    content {
      registry_arn   = aws_service_discovery_service.this[0].arn
      port           = var.launch_type == "FARGATE" ? var.container_port : null
      container_name = var.launch_type == "EC2" ? var.name : null
      container_port = var.launch_type == "EC2" ? var.container_port : null
    }
  }

  lifecycle {
    create_before_destroy = false
  }
  
   timeouts {
    delete = "10m"    # ← Timeout explícito para no colgarse indefinidamente
  }
  
  tags = local.common_tags

  depends_on = [
    aws_lb_listener_rule.this,
    aws_lb_listener_rule.multi,
    aws_lb_listener.nlb,
    aws_service_discovery_service.this
  ]
}

#################################################
# AUTOSCALING TARGET
#################################################
resource "aws_appautoscaling_target" "this" {
  min_capacity       = var.min_containers
  max_capacity       = var.max_containers
  resource_id        = "service/${var.cluster_name}/${aws_ecs_service.this.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
  role_arn           = var.autoscaling_role_arn
}

#################################################
# AUTOSCALING POLICY
#################################################
resource "aws_appautoscaling_policy" "this" {
  name               = "aas-${lower(var.project_name)}-${lower(var.name)}-ecs-autoscalingpolicy"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.this.resource_id
  scalable_dimension = aws_appautoscaling_target.this.scalable_dimension
  service_namespace  = aws_appautoscaling_target.this.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }

    scale_in_cooldown  = 60
    scale_out_cooldown = 120
    target_value       = var.autoscaling_target_value
  }
}

#################################################
# PERMISOS PARA SECRETS MANAGER
#################################################
resource "aws_iam_role_policy" "secrets_access" {
  count = var.task_role_create && length(var.secrets) > 0 ? 1 : 0

  name = "${var.project_name}-${var.name}-secrets"
  role = aws_iam_role.task[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = [
          for secret_name, secret_arn in var.secrets_arns :
          secret_arn != null ? "${secret_arn}*" : "arn:aws:secretsmanager:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:secret:${lower(var.project_name)}-${secret_name}-*"
        ]
      }
    ]
  })

  depends_on = [aws_iam_role.task]
}