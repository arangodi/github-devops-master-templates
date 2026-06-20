locals {
  bucket_name = "s3-${var.project_name}-${var.bucket_name}"
  common_tags = merge({
    project_name = var.project_name
    #Ambiente     = var.environment
    module       = "catalog/storage/s3-bucket"
  }, var.tags)
}

#################################################
# BUCKET BASE
#################################################
resource "aws_s3_bucket" "this" {
  bucket = local.bucket_name
  tags   = local.common_tags
}

#################################################
# BLOQUEO DE ACCESO PUBLICO
#################################################
resource "aws_s3_bucket_public_access_block" "this" {
  bucket = aws_s3_bucket.this.id

  block_public_acls       = var.block_public_access
  block_public_policy     = var.block_public_access
  ignore_public_acls      = var.block_public_access
  restrict_public_buckets = var.block_public_access
}

#################################################
# VERSIONAMIENTO
#################################################
resource "aws_s3_bucket_versioning" "this" {
  bucket = aws_s3_bucket.this.id

  versioning_configuration {
    status = var.versioning ? "Enabled" : "Suspended"
  }
}

#################################################
# ENCRIPCION
#################################################
resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  count  = var.encryption ? 1 : 0
  bucket = aws_s3_bucket.this.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

#################################################
# BUCKET POLICY
#################################################
resource "aws_s3_bucket_policy" "this" {
  count  = var.bucket_policy != null ? 1 : 0
  bucket = aws_s3_bucket.this.id
  policy = var.bucket_policy

  depends_on = [aws_s3_bucket_public_access_block.this]
}

#################################################
# LIFECYCLE RULES
#################################################
resource "aws_s3_bucket_lifecycle_configuration" "this" {
  count  = length(var.lifecycle_rules) > 0 ? 1 : 0
  bucket = aws_s3_bucket.this.id

  dynamic "rule" {
    for_each = var.lifecycle_rules
    
    content {
      id     = rule.value.id
      status = rule.value.enabled ? "Enabled" : "Disabled"


      filter {
        prefix                   = try(rule.value.filter.prefix, null)
        object_size_greater_than = try(rule.value.filter.object_size_greater_than, null)
        object_size_less_than    = try(rule.value.filter.object_size_less_than, null)
        
        dynamic "and" {
          for_each = (
            try(rule.value.filter.prefix, null) != null && try(rule.value.filter.tags, null) != null
          ) || (
            try(rule.value.filter.prefix, null) != null && (
              try(rule.value.filter.object_size_greater_than, null) != null || 
              try(rule.value.filter.object_size_less_than, null) != null
            )
          ) || (
            try(rule.value.filter.tags, null) != null && (
              try(rule.value.filter.object_size_greater_than, null) != null || 
              try(rule.value.filter.object_size_less_than, null) != null
            )
          ) ? [1] : []
          
          content {
            prefix                   = try(rule.value.filter.prefix, null)
            object_size_greater_than = try(rule.value.filter.object_size_greater_than, null)
            object_size_less_than    = try(rule.value.filter.object_size_less_than, null)
            tags                     = try(rule.value.filter.tags, null)
          }
        }
      }

      dynamic "transition" {
        for_each = try(rule.value.transitions, [])
        
        content {
          days          = transition.value.days
          storage_class = transition.value.storage_class
        }
      }

      dynamic "expiration" {
        for_each = try(rule.value.expiration, null) != null ? [rule.value.expiration] : []
        
        content {
          days                         = try(expiration.value.days, null)
          expired_object_delete_marker = try(expiration.value.expired_object_delete_marker, null)
        }
      }

      dynamic "noncurrent_version_transition" {
        for_each = try(rule.value.noncurrent_version_transitions, [])
        
        content {
          noncurrent_days           = noncurrent_version_transition.value.noncurrent_days
          storage_class             = noncurrent_version_transition.value.storage_class
          newer_noncurrent_versions = try(noncurrent_version_transition.value.newer_noncurrent_versions, null)
        }
      }

      dynamic "noncurrent_version_expiration" {
        for_each = try(rule.value.noncurrent_version_expiration, null) != null ? [rule.value.noncurrent_version_expiration] : []
        
        content {
          noncurrent_days           = noncurrent_version_expiration.value.noncurrent_days
          newer_noncurrent_versions = try(noncurrent_version_expiration.value.newer_noncurrent_versions, null)
        }
      }

      dynamic "abort_incomplete_multipart_upload" {
        for_each = try(rule.value.abort_incomplete_multipart_upload, null) != null ? [rule.value.abort_incomplete_multipart_upload] : []
        
        content {
          days_after_initiation = abort_incomplete_multipart_upload.value.days_after_initiation
        }
      }
    }
  }
}

#################################################
# LOGGING
#################################################
resource "aws_s3_bucket_logging" "this" {
  count  = var.logging != null ? 1 : 0
  bucket = aws_s3_bucket.this.id

  target_bucket = var.logging.target_bucket
  target_prefix = var.logging.target_prefix
}

#################################################
# NOTIFICACIONES
#################################################
resource "aws_s3_bucket_notification" "this" {
  count  = var.notifications != null ? 1 : 0
  bucket = aws_s3_bucket.this.id

  dynamic "lambda_function" {
    for_each = var.notifications.lambda_arn != null ? [1] : []
    content {
      lambda_function_arn = var.notifications.lambda_arn
      events              = var.notifications.events
      filter_prefix       = var.notifications.prefix
      filter_suffix       = var.notifications.suffix
    }
  }

  dynamic "queue" {
    for_each = var.notifications.sqs_arn != null ? [1] : []
    content {
      queue_arn     = var.notifications.sqs_arn
      events        = var.notifications.events
      filter_prefix = var.notifications.prefix
      filter_suffix = var.notifications.suffix
    }
  }

  dynamic "topic" {
    for_each = var.notifications.sns_arn != null ? [1] : []
    content {
      topic_arn     = var.notifications.sns_arn
      events        = var.notifications.events
      filter_prefix = var.notifications.prefix
      filter_suffix = var.notifications.suffix
    }
  }
}

#################################################
# REPLICACION
#################################################
resource "aws_s3_bucket_replication_configuration" "this" {
  count  = var.replication != null ? 1 : 0
  bucket = aws_s3_bucket.this.id
  role   = var.replication.role_arn

  rule {
    id     = "replication-rule"
    status = "Enabled"

    destination {
      bucket        = var.replication.destination_bucket
      storage_class = "STANDARD"
    }

    dynamic "delete_marker_replication" {
      for_each = var.replication.replicate_delete ? [1] : []
      content {
        status = "Enabled"
      }
    }
  }

  depends_on = [aws_s3_bucket_versioning.this]
}