data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

#################################################
# DATA SOURCE — filesystem existente
#################################################
data "aws_efs_file_system" "existing" {
  count          = var.create ? 0 : 1
  file_system_id = var.existing_filesystem_id
}

locals {
  filesystem_name = lower("efs-${var.project_name}-${var.name}")

  common_tags = merge({
    Name         = local.filesystem_name
    project_name = var.project_name
    environment  = var.environment
    module       = "catalog/storage/efs"
  }, var.tags)
}

#################################################
# SECURITY GROUP — permite NFS desde la VPC
#################################################
resource "aws_security_group" "this" {
  count = var.create ? 1 : 0

  name        = lower("secg-${var.project_name}-${var.name}-efs")
  description = "SG para EFS ${var.project_name}-${var.name}"
  vpc_id      = var.vpc_id

  tags = merge(local.common_tags, {
    Name = lower("secg-${var.project_name}-${var.name}-efs")
  })
}

resource "aws_vpc_security_group_ingress_rule" "nfs" {
  count = var.create ? 1 : 0

  security_group_id = aws_security_group.this[0].id
  cidr_ipv4         = "10.0.0.0/8"
  from_port         = 2049
  to_port           = 2049
  ip_protocol       = "tcp"
  description       = "NFS desde la VPC"
}

resource "aws_vpc_security_group_egress_rule" "all" {
  count = var.create ? 1 : 0

  security_group_id = aws_security_group.this[0].id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
  description       = "Todo el trafico saliente"
}

#################################################
# EFS FILESYSTEM
#################################################
resource "aws_efs_file_system" "this" {
  count = var.create ? 1 : 0

  performance_mode = var.performance_mode
  throughput_mode  = var.throughput_mode
  encrypted        = var.encryption_enabled
  kms_key_id       = var.encryption_enabled ? var.kms_key_arn : null

  provisioned_throughput_in_mibps = var.throughput_mode == "provisioned" ? var.provisioned_throughput_in_mibps : null

  dynamic "lifecycle_policy" {
    for_each = var.transition_to_ia != null ? [1] : []
    content {
      transition_to_ia = var.transition_to_ia
    }
  }

  tags = local.common_tags
}

#################################################
# MOUNT TARGETS — uno por subnet
#################################################
resource "aws_efs_mount_target" "this" {
  for_each = var.create ? { for idx, subnet in var.subnet_ids : tostring(idx) => subnet } : {}

  file_system_id  = aws_efs_file_system.this[0].id
  subnet_id       = each.value
  security_groups = [aws_security_group.this[0].id]
}

#################################################
# BACKUP POLICY
#################################################
resource "aws_efs_backup_policy" "this" {
  count = var.create ? 1 : 0

  file_system_id = aws_efs_file_system.this[0].id

  backup_policy {
    status = var.enable_backup ? "ENABLED" : "DISABLED"
  }
}

#################################################
# ACCESS POINTS — uno por servicio ECS
#################################################
resource "aws_efs_access_point" "this" {
  for_each = var.create ? { for ap in var.access_points : ap.name => ap } : {}

  file_system_id = aws_efs_file_system.this[0].id

  posix_user {
    uid = each.value.uid
    gid = each.value.gid
  }

  root_directory {
    path = "/${each.key}"

    creation_info {
      owner_uid   = each.value.uid
      owner_gid   = each.value.gid
      permissions = each.value.permissions
    }
  }

  tags = merge(local.common_tags, {
    Name = lower("efs-ap-${var.project_name}-${each.key}")
  })
}

