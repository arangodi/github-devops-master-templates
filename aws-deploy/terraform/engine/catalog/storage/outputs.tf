#################################################
# OUTPUTS / S3
#################################################
output "s3_buckets" {
  description = "Buckets S3 creados"
  value = {
    for name, bucket in module.s3_buckets : name => {
      # Identidad
      bucket_id                   = bucket.bucket_id
      bucket_name                 = bucket.bucket_name
      bucket_arn                  = bucket.bucket_arn

      # Acceso
      bucket_domain_name          = bucket.bucket_domain_name
      bucket_regional_domain_name = bucket.bucket_regional_domain_name
      bucket_region               = bucket.bucket_region

      # Configuración
      versioning_enabled          = try(local.s3_buckets_map[name].versioning, false)
      encryption_enabled          = try(local.s3_buckets_map[name].encryption, true)
      block_public_access         = try(local.s3_buckets_map[name].block_public_access, true)
      logging_enabled             = try(local.s3_buckets_map[name].logging, null) != null
      replication_enabled         = try(local.s3_buckets_map[name].replication, null) != null
      notifications_enabled       = try(local.s3_buckets_map[name].notifications, null) != null
      lifecycle_rules_count       = length(try(local.s3_buckets_map[name].lifecycle_rules, []))
    }
  }
}

#################################################
# OUTPUTS / EFS
#################################################
output "efs_filesystems" {
  description = "Filesystems EFS creados con toda la información para integración"
  value = {
    for name, fs in module.efs_filesystems : name => {

      filesystem_id      = fs.filesystem_id
      filesystem_arn     = fs.filesystem_arn
      filesystem_dns_name = fs.filesystem_dns_name

      security_group_id    = fs.security_group_id
      mount_target_ids     = fs.mount_target_ids
      mount_target_dns_names = fs.mount_target_dns_names

      access_point_ids  = fs.access_point_ids
      access_point_arns = fs.access_point_arns

      ecs_volume_config = fs.ecs_volume_config
      ec2_mount_command = fs.ec2_mount_command
      eks_csi_config    = fs.eks_csi_config
    }
  }
}

output "efs_filesystem_ids" {
  description = "Mapa de nombre → filesystem_id"
  value = {
    for name, fs in module.efs_filesystems : name => fs.filesystem_id
  }
}

output "efs_access_point_ids" {
  description = "Mapa de nombre → access_point_ids"
  value = {
    for name, fs in module.efs_filesystems : name => fs.access_point_ids
  }
}

output "efs_security_group_ids" {
  description = "Mapa de nombre → security_group_id"
  value = {
    for name, fs in module.efs_filesystems : name => fs.security_group_id
  }
}
