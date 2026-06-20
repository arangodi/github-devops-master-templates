#################################################
# CERTIFICADOS ACM
#################################################
module "certificates" {
  for_each = { for c in local.certificates : c.name => c }

  source = "../../../modules/catalog/security/acm"

  name        = each.value.name
  create      = try(each.value.create, true)
  create_zone = try(each.value.create_zone, false)
  domain      = each.value.domain
  apex_domain = var.apex_domain

  subject_alternative_names = try(each.value.subject_alternative_names, [])
  validation_method         = try(each.value.validation_method, "DNS")
  existing_arn              = try(each.value.arn, null)
  vpc_id                    = try(each.value.create_zone, false) ? local.network.vpc_id : null

  project_name = var.project_name
  environment  = var.environment
  tags = try(each.value.tags, {})
}

#################################################
# SECRETS MANAGER
#################################################
module "secrets" {
  for_each = local.secrets_map

  source = "../../../modules/catalog/security/secrets-manager"

  name         = each.value.name
  project_name = var.project_name
  environment  = var.environment
  account      = var.account

  create              = try(each.value.create, true)
  existing_secret_arn = try(each.value.existing_secret_arn, null)
  description         = try(each.value.description, "Secret ${each.value.name} para ${var.project_name}-${var.environment}")
  kms_key_id          = try(each.value.kms_key_id, null)
  recovery_window_days = try(each.value.recovery_window_days,var.environment == "pdn" ? 15 : 0)
  secret_type         = try(each.value.secret_type, "string")

  enable_rotation     = try(each.value.enable_rotation, false)
  rotation_lambda_arn = try(each.value.rotation_lambda_arn, null)
  rotation_days       = try(each.value.rotation_days, 30)
  rotation_duration   = try(each.value.rotation_duration, "2h")

  reader_role_arns = try(each.value.reader_role_arns, [])
  writer_role_arns = try(each.value.writer_role_arns, [])
  admin_role_arns  = try(each.value.admin_role_arns, [])

  secret_value = try(each.value.secret_value, null)

  tags = merge(local.project_tags, try(each.value.tags, {}))
}