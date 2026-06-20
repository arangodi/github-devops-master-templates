data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

# AMI — Amazon Linux
data "aws_ami" "amazon_linux" {
  count       = var.ami_id == null && var.os_type == "linux" ? 1 : 0
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}

# AMI — Windows Server
data "aws_ami" "windows" {
  count       = var.ami_id == null && var.os_type == "windows" ? 1 : 0
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["Windows_Server-2022-English-Full-Base-*"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}

locals {
  safe_environment = replace(lower(var.environment), ".", "-")
  instance_name    = lower("ec2-${var.project_name}-${var.name}")
  sg_name          = lower("secg-${var.project_name}-${var.name}-ec2")
  asg_name         = lower("asg-${var.project_name}-${var.name}")
  lt_name          = lower("lt-${var.project_name}-${var.name}")
  iam_role_name    = lower("iam-${var.project_name}-${var.name}-ec2-role")

  ami_id = var.ami_id != null ? var.ami_id : (
    var.os_type == "windows" ? data.aws_ami.windows[0].id : data.aws_ami.amazon_linux[0].id
  )

  root_device_name = var.os_type == "windows" ? "/dev/sda1" : "/dev/xvda"
  has_eni          = var.eni_id != null

  # ========================================
  # USER DATA
  # ========================================

  scripts_path = "${path.module}/../../../../scripts/userdata"

  predefined_script = var.user_data_script != null ? templatefile(
    "${local.scripts_path}/${var.user_data_script}",
    var.user_data_vars
  ) : null

  final_user_data = join("\n", compact([
    local.predefined_script,
    var.user_data
  ]))

  common_tags = merge({
    Name         = local.instance_name
    project_name = var.project_name
    os_type      = var.os_type
    module       = "catalog/compute/ec2"
  }, var.tags)
}

#################################################
# IAM ROLE
#################################################
resource "aws_iam_role" "this" {
  name = local.iam_role_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = local.common_tags
}

resource "aws_iam_instance_profile" "this" {
  name = local.iam_role_name
  role = aws_iam_role.this.name
}

resource "aws_iam_role_policy_attachment" "ssm" {
  count = var.enable_ssm ? 1 : 0

  role       = aws_iam_role.this.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "ecs" {
  count = var.ecs_cluster_name != null ? 1 : 0

  role       = aws_iam_role.this.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

#################################################
# SECURITY GROUP
#################################################
resource "aws_security_group" "this" {
  name        = local.sg_name
  description = "SG para EC2 ${var.project_name}-${var.name}"
  vpc_id      = var.vpc_id

  tags = merge(local.common_tags, {
    Name = local.sg_name
  })
}

resource "aws_vpc_security_group_egress_rule" "all" {
  security_group_id = aws_security_group.this.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
  description       = "Todo el trafico saliente"
}

resource "aws_vpc_security_group_ingress_rule" "ssh" {
  count = var.key_name != null && var.os_type == "linux" ? 1 : 0

  security_group_id = aws_security_group.this.id
  cidr_ipv4         = "10.0.0.0/8"
  from_port         = 22
  to_port           = 22
  ip_protocol       = "tcp"
  description       = "SSH interno"
}

resource "aws_vpc_security_group_ingress_rule" "rdp" {
  count = var.os_type == "windows" && var.enable_rdp ? 1 : 0

  security_group_id = aws_security_group.this.id
  cidr_ipv4         = "10.0.0.0/8"
  from_port         = 3389
  to_port           = 3389
  ip_protocol       = "tcp"
  description       = "RDP interno"
}

resource "aws_vpc_security_group_ingress_rule" "additional" {
  for_each = { for i, r in var.ingress_rules : tostring(i) => r }

  security_group_id = aws_security_group.this.id
  cidr_ipv4         = each.value.cidr
  from_port         = each.value.from_port
  to_port           = each.value.to_port
  ip_protocol       = each.value.protocol
  description       = each.value.description
}

#################################################
# LAUNCH TEMPLATE
#################################################
resource "aws_launch_template" "this" {
  name        = local.lt_name
  description = "Launch Template para ${local.instance_name}"

  image_id      = local.ami_id
  instance_type = var.instance_type
  key_name      = var.key_name

  user_data = length(local.final_user_data) > 0 ? base64encode(local.final_user_data) : null

  iam_instance_profile {
    name = aws_iam_instance_profile.this.name
  }

  dynamic "network_interfaces" {
    for_each = local.has_eni ? [1] : []
    content {
      network_interface_id = var.eni_id
      device_index         = 0
    }
  }

  vpc_security_group_ids = !local.has_eni ? concat([aws_security_group.this.id], var.additional_sg_ids) : null

  block_device_mappings {
    device_name = local.root_device_name
    ebs {
      volume_size           = var.root_volume_size
      volume_type           = var.root_volume_type
      encrypted             = var.root_volume_encrypted
      delete_on_termination = true
    }
  }

  dynamic "block_device_mappings" {
    for_each = var.ebs_volumes
    content {
      device_name = block_device_mappings.value.device_name
      ebs {
        volume_size           = block_device_mappings.value.size
        volume_type           = block_device_mappings.value.type
        encrypted             = block_device_mappings.value.encrypted
        delete_on_termination = true
      }
    }
  }

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  tag_specifications {
    resource_type = "instance"
    tags          = local.common_tags
  }

  tag_specifications {
    resource_type = "volume"
    tags          = local.common_tags
  }

  tags = local.common_tags
}

#################################################
# INSTANCIA STANDALONE — sin ASG
#################################################
resource "aws_instance" "this" {
  count = var.create_asg ? 0 : 1

  launch_template {
    id      = aws_launch_template.this.id
    version = "$Latest"
  }

  # Sin ENI necesita subnet explícita
  subnet_id = !local.has_eni ? var.subnet_ids[0] : null

  tags = local.common_tags

  lifecycle {
    ignore_changes = [ami]
  }
}

#################################################
# AUTOSCALING GROUP — mixed instances policy
# Solo para instancias sin ENI
#################################################
resource "aws_autoscaling_group" "this" {
  count = var.create_asg ? 1 : 0

  name                = local.asg_name
  min_size            = var.asg_min_size
  max_size            = var.asg_max_size
  desired_capacity    = var.asg_desired_size
  vpc_zone_identifier = var.subnet_ids

  mixed_instances_policy {
    launch_template {
      launch_template_specification {
        launch_template_id = aws_launch_template.this.id
        version            = "$Latest"
      }

      dynamic "override" {
        for_each = var.additional_instance_types
        content {
          instance_type = override.value
        }
      }
    }

    instances_distribution {
      on_demand_base_capacity                  = var.on_demand_base_capacity
      on_demand_percentage_above_base_capacity = var.on_demand_percentage
      spot_instance_pools                      = var.spot_instance_pools
    }
  }

  dynamic "tag" {
    for_each = local.common_tags
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }

  lifecycle {
    ignore_changes = [desired_capacity]
    precondition {
      condition     = !local.has_eni
      error_message = "No se puede usar ENI con ASG. Usa create_asg = false para instancias con IP fija."
    }
  }
}

#################################################
# PERMISOS PARA SECRETS MANAGER
#################################################
resource "aws_iam_role_policy" "secrets_access" {
  count = length(var.secrets) > 0 ? 1 : 0

  name = "${var.project_name}-${var.name}-secrets"
  role = aws_iam_role.this.id

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
          for secret_name in var.secrets :
          "arn:aws:secretsmanager:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:secret:${lower(var.project_name)}/${local.safe_environment}/${secret_name}-*"
        ]
      }
    ]
  })
}
