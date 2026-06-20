#################################################
# STORAGE / S3
#################################################
module "s3_buckets" {
  for_each = { for b in local.s3_buckets : b.name => b }

  source = "../../../modules/catalog/storage/s3-bucket"

  bucket_name         = each.value.name
  versioning          = try(each.value.versioning, false)
  encryption          = try(each.value.encryption, true)
  block_public_access = try(each.value.block_public_access, true)
  bucket_policy       = try(each.value.bucket_policy, null)
  lifecycle_rules     = try(each.value.lifecycle_rules, [])
  logging             = try(each.value.logging, null)
  notifications       = try(each.value.notifications, null)
  replication         = try(each.value.replication, null)
  tags                = merge(local.project_tags, try(each.value.tags, {}))
  project_name        = var.project_name
  environment         = var.environment
}

#################################################
# STORAGE / EFS
#################################################
module "efs_filesystems" {
  for_each = { for f in local.efs_filesystems : f.name => f }

  source = "../../../modules/catalog/storage/efs"

  name = each.value.name

  project_name = var.project_name
  environment  = var.environment
  account      = var.account

  vpc_id     = local.network.vpc_id
  subnet_ids = try(local.network.subnets_by_component["EC2"], local.network.private_subnets)

  create                 = try(each.value.create, true)
  existing_filesystem_id = try(each.value.existing_filesystem_id, null)

  performance_mode                = try(each.value.performance_mode, "generalPurpose")
  throughput_mode                 = try(each.value.throughput_mode, "bursting")
  provisioned_throughput_in_mibps = try(each.value.provisioned_throughput_in_mibps, null)

  transition_to_ia = try(each.value.transition_to_ia, null)

  enable_backup = try(each.value.enable_backup, true)

  encryption_enabled = try(each.value.encryption_enabled, true)
  kms_key_arn        = try(each.value.kms_key_arn, null)

  access_points = try(each.value.access_points, [])

  tags = merge(local.project_tags, try(each.value.tags, {}))
}
