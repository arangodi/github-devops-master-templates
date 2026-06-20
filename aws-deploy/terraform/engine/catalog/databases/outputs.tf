output "dynamodb_tables" {
  description = "Información de tablas DynamoDB creadas"
  value = {
    for name, table in module.dynamodb_tables : name => {
      table_name                      = table.table_name
      table_arn                       = table.table_arn
      table_id                        = table.table_id
      stream_arn                      = table.stream_arn
      stream_label                    = table.stream_label
      hash_key                        = table.hash_key
      range_key                       = table.range_key
      billing_mode                    = table.billing_mode
      global_secondary_indexes        = table.global_secondary_indexes
      local_secondary_indexes         = table.local_secondary_indexes
      autoscaling_enabled             = table.autoscaling_enabled
      point_in_time_recovery_enabled  = table.point_in_time_recovery_enabled
      encryption_enabled              = table.encryption_enabled
      
      # IAM Policies pre-construidas
      table_policy_read   = table.table_policy_read
      table_policy_write  = table.table_policy_write
      table_policy_full   = table.table_policy_full
      stream_policy       = table.stream_policy
    }
  }
}