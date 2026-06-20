data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  table_name = var.create ? lower(replace("ddb-${var.project_name}-${var.name}", "_", "-")) : var.existing_table_name

  billing_mode = var.billing_mode != null ? var.billing_mode : (
    var.enable_autoscaling ? "PROVISIONED" : "PAY_PER_REQUEST"
  )

  is_provisioned = local.billing_mode == "PROVISIONED"

  common_tags = merge({
    Name         = local.table_name
    project_name = var.project_name
    environment  = var.environment
    module       = "catalog/storage/dynamodb"
  }, var.tags)


  base_attributes = concat(
    [
      {
        name = var.hash_key
        type = var.hash_key_type
      }
    ],

    var.range_key != null ? [
      {
        name = var.range_key
        type = var.range_key_type
      }
    ] : []
  )

  gsi_attributes = flatten([
    for gsi in var.global_secondary_indexes : concat(
      [
        {
          name = gsi.hash_key
          type = lookup(gsi, "hash_key_type", "S")
        }
      ],

      lookup(gsi, "range_key", null) != null ? [
        {
          name = gsi.range_key
          type = lookup(gsi, "range_key_type", "S")
        }
      ] : []
    )
  ])

  lsi_attributes = flatten([
    for lsi in var.local_secondary_indexes : [
      {
        name = lsi.range_key
        type = lookup(lsi, "range_key_type", "S")
      }
    ]
  ])

  all_attributes_raw = concat(
    local.base_attributes,
    local.gsi_attributes,
    local.lsi_attributes,
    var.attributes
  )

  all_attributes = values({
    for attr in local.all_attributes_raw :
    attr.name => attr
  })
}


resource "aws_dynamodb_table" "this" {
  count = var.create ? 1 : 0

  name         = local.table_name
  billing_mode = local.billing_mode
  hash_key     = var.hash_key
  range_key    = var.range_key != null ? var.range_key : null
  table_class  = var.table_class

  read_capacity  = local.is_provisioned ? var.read_capacity : null
  write_capacity = local.is_provisioned ? var.write_capacity : null

  stream_enabled   = var.stream_enabled
  stream_view_type = var.stream_enabled ? var.stream_view_type : null

  dynamic "attribute" {
    for_each = local.all_attributes

    content {
      name = attribute.value.name
      type = attribute.value.type
    }
  }

  dynamic "ttl" {
    for_each = var.ttl_enabled ? [1] : []

    content {
      enabled        = true
      attribute_name = var.ttl_attribute_name
    }
  }

  dynamic "global_secondary_index" {
    for_each = var.global_secondary_indexes

    content {
      name            = global_secondary_index.value.name
      hash_key        = global_secondary_index.value.hash_key
      range_key       = lookup(global_secondary_index.value, "range_key", null)
      projection_type = global_secondary_index.value.projection_type

      non_key_attributes = (
        global_secondary_index.value.projection_type == "INCLUDE"
        ? lookup(global_secondary_index.value, "non_key_attributes", null)
        : null
      )

      read_capacity = (
        local.is_provisioned
        ? lookup(global_secondary_index.value, "read_capacity", var.read_capacity)
        : null
      )

      write_capacity = (
        local.is_provisioned
        ? lookup(global_secondary_index.value, "write_capacity", var.write_capacity)
        : null
      )
    }
  }

  dynamic "local_secondary_index" {
    for_each = var.local_secondary_indexes

    content {
      name            = local_secondary_index.value.name
      range_key       = local_secondary_index.value.range_key
      projection_type = local_secondary_index.value.projection_type

      non_key_attributes = (
        local_secondary_index.value.projection_type == "INCLUDE"
        ? lookup(local_secondary_index.value, "non_key_attributes", null)
        : null
      )
    }
  }

  point_in_time_recovery {
    enabled = var.point_in_time_recovery_enabled
  }


  server_side_encryption {
    enabled = var.encryption_enabled

    kms_key_arn = var.encryption_enabled ? var.kms_key_arn : null
  }


  deletion_protection_enabled = var.deletion_protection_enabled


  tags = local.common_tags

  lifecycle {
    ignore_changes = [
      read_capacity,
      write_capacity,
    ]
  }
}

# ========================================
# DATA SOURCE — EXISTING TABLE
# ========================================

data "aws_dynamodb_table" "existing" {
  count = var.create ? 0 : 1

  name = var.existing_table_name
}

# ========================================
# AUTO-SCALING — TABLE READ
# ========================================

resource "aws_appautoscaling_target" "read" {
  count = var.create && var.enable_autoscaling && local.is_provisioned ? 1 : 0

  max_capacity       = var.autoscaling_read_max_capacity
  min_capacity       = var.read_capacity
  resource_id        = "table/${aws_dynamodb_table.this[0].name}"
  scalable_dimension = "dynamodb:table:ReadCapacityUnits"
  service_namespace  = "dynamodb"
}

resource "aws_appautoscaling_policy" "read" {
  count = var.create && var.enable_autoscaling && local.is_provisioned ? 1 : 0

  name               = "${local.table_name}-read-autoscaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.read[0].resource_id
  scalable_dimension = aws_appautoscaling_target.read[0].scalable_dimension
  service_namespace  = aws_appautoscaling_target.read[0].service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "DynamoDBReadCapacityUtilization"
    }

    target_value       = var.autoscaling_read_target
    scale_in_cooldown  = var.autoscaling_scale_in_cooldown
    scale_out_cooldown = var.autoscaling_scale_out_cooldown
  }
}

# ========================================
# AUTO-SCALING — TABLE WRITE
# ========================================

resource "aws_appautoscaling_target" "write" {
  count = var.create && var.enable_autoscaling && local.is_provisioned ? 1 : 0

  max_capacity       = var.autoscaling_write_max_capacity
  min_capacity       = var.write_capacity
  resource_id        = "table/${aws_dynamodb_table.this[0].name}"
  scalable_dimension = "dynamodb:table:WriteCapacityUnits"
  service_namespace  = "dynamodb"
}

resource "aws_appautoscaling_policy" "write" {
  count = var.create && var.enable_autoscaling && local.is_provisioned ? 1 : 0

  name               = "${local.table_name}-write-autoscaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.write[0].resource_id
  scalable_dimension = aws_appautoscaling_target.write[0].scalable_dimension
  service_namespace  = aws_appautoscaling_target.write[0].service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "DynamoDBWriteCapacityUtilization"
    }

    target_value       = var.autoscaling_write_target
    scale_in_cooldown  = var.autoscaling_scale_in_cooldown
    scale_out_cooldown = var.autoscaling_scale_out_cooldown
  }
}

# ========================================
# AUTO-SCALING — GSI READ
# ========================================

resource "aws_appautoscaling_target" "gsi_read" {
  for_each = var.create && var.enable_autoscaling && local.is_provisioned ? {
    for gsi in var.global_secondary_indexes : gsi.name => gsi
    if lookup(gsi, "enable_autoscaling", true) != false
  } : {}

  max_capacity       = lookup(each.value, "autoscaling_read_max_capacity", var.autoscaling_read_max_capacity)
  min_capacity       = lookup(each.value, "read_capacity", var.read_capacity)
  resource_id        = "table/${aws_dynamodb_table.this[0].name}/index/${each.key}"
  scalable_dimension = "dynamodb:index:ReadCapacityUnits"
  service_namespace  = "dynamodb"
}

resource "aws_appautoscaling_policy" "gsi_read" {
  for_each = aws_appautoscaling_target.gsi_read

  name               = "${local.table_name}-${each.key}-read-autoscaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = each.value.resource_id
  scalable_dimension = each.value.scalable_dimension
  service_namespace  = each.value.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "DynamoDBReadCapacityUtilization"
    }

    target_value       = var.autoscaling_read_target
    scale_in_cooldown  = var.autoscaling_scale_in_cooldown
    scale_out_cooldown = var.autoscaling_scale_out_cooldown
  }
}

# ========================================
# AUTO-SCALING — GSI WRITE
# ========================================

resource "aws_appautoscaling_target" "gsi_write" {
  for_each = var.create && var.enable_autoscaling && local.is_provisioned ? {
    for gsi in var.global_secondary_indexes : gsi.name => gsi
    if lookup(gsi, "enable_autoscaling", true) != false
  } : {}

  max_capacity       = lookup(each.value, "autoscaling_write_max_capacity", var.autoscaling_write_max_capacity)
  min_capacity       = lookup(each.value, "write_capacity", var.write_capacity)
  resource_id        = "table/${aws_dynamodb_table.this[0].name}/index/${each.key}"
  scalable_dimension = "dynamodb:index:WriteCapacityUnits"
  service_namespace  = "dynamodb"
}

resource "aws_appautoscaling_policy" "gsi_write" {
  for_each = aws_appautoscaling_target.gsi_write

  name               = "${local.table_name}-${each.key}-write-autoscaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = each.value.resource_id
  scalable_dimension = each.value.scalable_dimension
  service_namespace  = each.value.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "DynamoDBWriteCapacityUtilization"
    }

    target_value       = var.autoscaling_write_target
    scale_in_cooldown  = var.autoscaling_scale_in_cooldown
    scale_out_cooldown = var.autoscaling_scale_out_cooldown
  }
}