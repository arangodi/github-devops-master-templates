data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  safe_environment = replace(lower(var.environment), ".", "-")

  # Patrón igual al CloudFormation: ecr-{project}-{stage}-{name}
  repo_name = lower("ecr-${var.project_name}-${var.name}")

  common_tags = merge({
    Name         = local.repo_name
    project_name = var.project_name
    #Ambiente     = var.environment
    module       = "catalog/compute/ecr"
  }, var.tags)
}

#################################################
# ECR REPOSITORY
#################################################
resource "aws_ecr_repository" "this" {
  count = var.create ? 1 : 0

  name                 = local.repo_name
  image_tag_mutability = var.image_tag_mutability
  
  image_scanning_configuration {
    scan_on_push = var.scan_on_push
  }

  encryption_configuration {
    encryption_type = var.encryption_type
    kms_key         = var.encryption_type == "KMS" ? var.kms_key_arn : null
  }

  tags = local.common_tags
}

#################################################
# SSM PARAMETER STORE — version de la imagen
#################################################
resource "aws_ssm_parameter" "image_version" {
  count = var.create && var.create_ssm_parameter ? 1 : 0

  name        = "${lower(var.project_name)}-${var.name}-image-version"
  description = "Deployed version for image ${local.repo_name}"
  type        = "String"
  value       = "latest"

  lifecycle {
    ignore_changes = [value]
  }

  tags = merge(local.common_tags, {
    Name = "${lower(var.project_name)}-${var.name}-image-version" 
  })
}

#################################################
# LIFECYCLE POLICY
#################################################
resource "aws_ecr_lifecycle_policy" "this" {
  count = var.create && var.lifecycle_policy != null ? 1 : 0

  repository = aws_ecr_repository.this[0].name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Mantener las ultimas ${var.lifecycle_policy.keep_last_images} imagenes tagged"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["v"]
          countType     = "imageCountMoreThan"
          countNumber   = var.lifecycle_policy.keep_last_images
        }
        action = { type = "expire" }
      },
      {
        rulePriority = 2
        description  = "Expirar imagenes sin tag despues de ${var.lifecycle_policy.expire_untagged_after_days} dias"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = var.lifecycle_policy.expire_untagged_after_days
        }
        action = { type = "expire" }
      }
    ]
  })
}

#################################################
# REPOSITORY POLICY
#################################################
resource "aws_ecr_repository_policy" "this" {
  count = var.create && length(var.allow_account_ids) > 0 ? 1 : 0

  repository = aws_ecr_repository.this[0].name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "AllowCrossAccountPull"
      Effect = "Allow"
      Principal = {
        AWS = [
          for account_id in var.allow_account_ids :
          "arn:aws:iam::${account_id}:root"
        ]
      }
      Action = [
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchGetImage",
        "ecr:BatchCheckLayerAvailability"
      ]
    }]
  })
}