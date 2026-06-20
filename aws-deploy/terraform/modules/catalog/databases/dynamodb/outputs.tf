output "table_name" {
    description = "Nombre de la tabla DynamoDB"
    value       = var.create ? aws_dynamodb_table.this[0].name : data.aws_dynamodb_table.existing[0].name
}

output "table_arn" {
    description = "ARN de la tabla DynamoDB"
    value       = var.create ? aws_dynamodb_table.this[0].arn : data.aws_dynamodb_table.existing[0].arn
}

output "table_id" {
    description = "ID de la tabla DynamoDB"
    value       = var.create ? aws_dynamodb_table.this[0].id : data.aws_dynamodb_table.existing[0].id
}

output "stream_arn" {
    description = "ARN del stream de DynamoDB (si está habilitado)"
    value       = var.create && var.stream_enabled ? aws_dynamodb_table.this[0].stream_arn : null
}

output "stream_label" {
    description = "Label del stream de DynamoDB (si está habilitado)"
    value       = var.create && var.stream_enabled ? aws_dynamodb_table.this[0].stream_label : null
}

output "hash_key" {
    description = "Nombre del partition key (hash key)"
    value       = var.hash_key
}

output "range_key" {
    description = "Nombre del sort key (range key)"
    value       = var.range_key
}

output "billing_mode" {
    description = "Billing mode de la tabla"
    value       = var.create ? aws_dynamodb_table.this[0].billing_mode : data.aws_dynamodb_table.existing[0].billing_mode
}

output "global_secondary_indexes" {
    description = "Lista de GSI names"
    value       = [for gsi in var.global_secondary_indexes : gsi.name]
}

output "local_secondary_indexes" {
    description = "Lista de LSI names"
    value       = [for lsi in var.local_secondary_indexes : lsi.name]
}

output "autoscaling_enabled" {
    description = "Si el auto-scaling está habilitado"
    value       = var.enable_autoscaling
}

output "point_in_time_recovery_enabled" {
    description = "Si PITR está habilitado"
    value       = var.point_in_time_recovery_enabled
}

output "encryption_enabled" {
    description = "Si encryption está habilitado"
    value       = var.encryption_enabled
}

output "table_policy_read" {
    description = "Statement de IAM policy para read access"
    value = {
      effect = "Allow"
      actions = [
        "dynamodb:GetItem",
        "dynamodb:BatchGetItem",
        "dynamodb:Query",
        "dynamodb:Scan",
        "dynamodb:DescribeTable",
      ]
      resources = [
        var.create ? aws_dynamodb_table.this[0].arn : data.aws_dynamodb_table.existing[0].arn,
        "${var.create ? aws_dynamodb_table.this[0].arn : data.aws_dynamodb_table.existing[0].arn}/index/*"
      ]
    }
}

output "table_policy_write" {
    description = "Statement de IAM policy para write access"
    value = {
      effect = "Allow"
      actions = [
        "dynamodb:PutItem",
        "dynamodb:UpdateItem",
        "dynamodb:DeleteItem",
        "dynamodb:BatchWriteItem",
      ]
      resources = [
        var.create ? aws_dynamodb_table.this[0].arn : data.aws_dynamodb_table.existing[0].arn,
      ]
    }
}

output "table_policy_full" {
    description = "Statement de IAM policy para full access"
    value = {
      effect = "Allow"
      actions = [
        "dynamodb:*",
      ]
      resources = [
        var.create ? aws_dynamodb_table.this[0].arn : data.aws_dynamodb_table.existing[0].arn,
        "${var.create ? aws_dynamodb_table.this[0].arn : data.aws_dynamodb_table.existing[0].arn}/index/*"
      ]
    }
}

output "stream_policy" {
    description = "Statement de IAM policy para stream access (Lambda triggers)"
    value = var.stream_enabled ? {
      effect = "Allow"
      actions = [
        "dynamodb:GetRecords",
        "dynamodb:GetShardIterator",
        "dynamodb:DescribeStream",
        "dynamodb:ListStreams",
      ]
      resources = [
        var.create ? aws_dynamodb_table.this[0].stream_arn : null
      ]
    } : null
}

output "deletion_protection_enabled" {
    description = "Si la tabla tiene protección contra borrado"
    value       = var.deletion_protection_enabled
}
