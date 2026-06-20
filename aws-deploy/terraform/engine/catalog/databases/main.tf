locals {
    dynamodb_tables = try(local.config.catalog.databases.dynamodb_tables, [])
}

# ========================================
# DynamoDB
# ========================================
module "dynamodb_tables" {
    for_each = { for table in local.dynamodb_tables : table.name => table }

    source = "../../../modules/catalog/databases/dynamodb"

    name                  = each.value.name
    create                = try(each.value.create, true)
    existing_table_name   = try(each.value.existing_table_name, null)
    
    # Keys
    hash_key      = each.value.hash_key
    hash_key_type = try(each.value.hash_key_type, "S")
    range_key     = try(each.value.range_key, null)
    range_key_type = try(each.value.range_key_type, "S")
    
    
    attributes = try(each.value.attributes, [])
    

    billing_mode = try(each.value.billing_mode, null)
    table_class  = try(each.value.table_class, "STANDARD")
    
    read_capacity  = try(each.value.read_capacity, 5)
    write_capacity = try(each.value.write_capacity, 5)
    
    enable_autoscaling              = try(each.value.enable_autoscaling, false)
    autoscaling_read_max_capacity   = try(each.value.autoscaling_read_max_capacity, 100)
    autoscaling_write_max_capacity  = try(each.value.autoscaling_write_max_capacity, 100)
    autoscaling_read_target         = try(each.value.autoscaling_read_target, 70)
    autoscaling_write_target        = try(each.value.autoscaling_write_target, 70)
    autoscaling_scale_in_cooldown   = try(each.value.autoscaling_scale_in_cooldown, 60)
    autoscaling_scale_out_cooldown  = try(each.value.autoscaling_scale_out_cooldown, 60)
    
    global_secondary_indexes = try(each.value.global_secondary_indexes, [])
    local_secondary_indexes  = try(each.value.local_secondary_indexes, [])
    
    stream_enabled   = try(each.value.stream_enabled, false)
    stream_view_type = try(each.value.stream_view_type, "NEW_AND_OLD_IMAGES")
    
    ttl_enabled        = try(each.value.ttl_enabled, false)
    ttl_attribute_name = try(each.value.ttl_attribute_name, "ttl")
    
    point_in_time_recovery_enabled = try(each.value.point_in_time_recovery_enabled, true)
    
    encryption_enabled = try(each.value.encryption_enabled, true)
    kms_key_arn        = try(each.value.kms_key_arn, null)


    deletion_protection_enabled = try(each.value.deletion_protection_enabled, false)
  
    environment  = var.environment
    project_name = local.config.project_name
    account      = var.account
    tags         = merge(local.project_tags, try(each.value.tags, {}))
}
