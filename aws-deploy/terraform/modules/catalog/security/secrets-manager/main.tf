data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  safe_environment = replace(lower(var.environment), ".", "-")
  
  secret_name = lower("sm-${var.project_name}-${var.name}")
  
  # ARN del secret (creado o existente)
  secret_arn = var.create ? aws_secretsmanager_secret.this[0].arn : var.existing_secret_arn

  reader_role_name = var.reader_role_name != null ? var.reader_role_name : "${var.project_name}-${var.name}-reader"
  writer_role_name = var.writer_role_name != null ? var.writer_role_name : "${var.project_name}-${var.name}-writer"

  common_tags = merge({
    Name         = local.secret_name
    project_name = var.project_name
    #Ambiente     = var.environment
    managed_by   = "terraform"
    module       = "catalog/security/secrets-manager"
  }, var.tags)
}

#################################################
# SECRET
#################################################
resource "aws_secretsmanager_secret" "this" {
  count = var.create ? 1 : 0

  name                    = local.secret_name
  description             = var.description != null ? var.description : "Secret para ${var.project_name}-${var.name}"
  kms_key_id              = var.kms_key_id
  recovery_window_in_days = var.recovery_window_days

  tags = local.common_tags
}

resource "aws_secretsmanager_secret_version" "this" {
  count = var.create ? 1 : 0

  secret_id = aws_secretsmanager_secret.this[0].id
  
  secret_string = var.secret_type == "string" ? (
    var.secret_value != null ? jsonencode(var.secret_value) : "{}"
  ) : null

  lifecycle {
    ignore_changes = [secret_string, secret_binary]
  }
}

#################################################
# ROTACION AUTOMATICA
#################################################
resource "aws_secretsmanager_secret_rotation" "this" {
  count = var.create && var.enable_rotation ? 1 : 0

  secret_id           = aws_secretsmanager_secret.this[0].id
  rotation_lambda_arn = var.rotation_lambda_arn

  rotation_rules {
    automatically_after_days = var.rotation_days
    duration                 = var.rotation_duration
  }

  depends_on = [aws_secretsmanager_secret.this]
}

resource "aws_iam_role" "reader" {
  count = var.create_reader_role ? 1 : 0

  name = local.reader_role_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat(
      
      length(var.reader_role_trusted_services) > 0 ? [{
        Effect = "Allow"
        Principal = {
          Service = var.reader_role_trusted_services
        }
        Action = "sts:AssumeRole"
      }] : [],
  
      length(var.reader_role_trusted_arns) > 0 ? [{
        Effect = "Allow"
        Principal = {
          AWS = var.reader_role_trusted_arns
        }
        Action = "sts:AssumeRole"
      }] : []
    )
  })

  tags = merge(local.common_tags, {
    Name = local.reader_role_name
  })
}

resource "aws_iam_role_policy" "reader" {
  count = var.create_reader_role ? 1 : 0

  name = "secrets-read-access"
  role = aws_iam_role.reader[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "secretsmanager:GetSecretValue",
        "secretsmanager:DescribeSecret"
      ]
      Resource = local.secret_arn
    }]
  })
}

resource "aws_iam_role" "writer" {
  count = var.create_writer_role ? 1 : 0

  name = local.writer_role_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat(
      length(var.writer_role_trusted_services) > 0 ? [{
        Effect = "Allow"
        Principal = {
          Service = var.writer_role_trusted_services
        }
        Action = "sts:AssumeRole"
      }] : [],
      length(var.writer_role_trusted_arns) > 0 ? [{
        Effect = "Allow"
        Principal = {
          AWS = var.writer_role_trusted_arns
        }
        Action = "sts:AssumeRole"
      }] : []
    )
  })

  tags = merge(local.common_tags, {
    Name = local.writer_role_name
  })
}

resource "aws_iam_role_policy" "writer" {
  count = var.create_writer_role ? 1 : 0

  name = "secrets-write-access"
  role = aws_iam_role.writer[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "secretsmanager:GetSecretValue",
        "secretsmanager:DescribeSecret",
        "secretsmanager:PutSecretValue",
        "secretsmanager:UpdateSecret"
      ]
      Resource = local.secret_arn
    }]
  })
}

data "aws_iam_policy_document" "secret_policy" {
  count = var.create && (
    length(var.reader_role_arns) > 0 ||
    length(var.writer_role_arns) > 0 ||
    length(var.admin_role_arns) > 0
  ) ? 1 : 0

  dynamic "statement" {
    for_each = length(var.reader_role_arns) > 0 ? [1] : []
    content {
      sid    = "AllowRead"
      effect = "Allow"
      principals {
        type        = "AWS"
        identifiers = var.reader_role_arns
      }
      actions = [
        "secretsmanager:GetSecretValue",
        "secretsmanager:DescribeSecret",
        "secretsmanager:GetResourcePolicy"
      ]
      resources = [local.secret_arn]
    }
  }

  dynamic "statement" {
    for_each = length(var.writer_role_arns) > 0 ? [1] : []
    content {
      sid    = "AllowWrite"
      effect = "Allow"
      principals {
        type        = "AWS"
        identifiers = var.writer_role_arns
      }
      actions = [
        "secretsmanager:GetSecretValue",
        "secretsmanager:DescribeSecret",
        "secretsmanager:PutSecretValue",
        "secretsmanager:UpdateSecret",
        "secretsmanager:GetResourcePolicy"
      ]
      resources = [local.secret_arn]
    }
  }

  dynamic "statement" {
    for_each = length(var.admin_role_arns) > 0 ? [1] : []
    content {
      sid    = "AllowAdmin"
      effect = "Allow"
      principals {
        type        = "AWS"
        identifiers = var.admin_role_arns
      }
      actions = [
        "secretsmanager:*"
      ]
      resources = [local.secret_arn]
    }
  }
}

resource "aws_secretsmanager_secret_policy" "this" {
  count = var.create && (
    length(var.reader_role_arns) > 0 ||
    length(var.writer_role_arns) > 0 ||
    length(var.admin_role_arns) > 0
  ) ? 1 : 0

  secret_arn = local.secret_arn
  policy     = data.aws_iam_policy_document.secret_policy[0].json
}