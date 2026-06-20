variable "name" {
  description = "Nombre de la tabla (sufijo). Se construye: dynamodb-{project_name}-{name}"
  type        = string
}

variable "create" {
  description = "true = crea la tabla, false = referencia una existente"
  type        = bool
  default     = true
}

variable "existing_table_name" {
  description = "Nombre de la tabla existente. Solo si create = false"
  type        = string
  default     = null
}

variable "project_name" {
  description = "Nombre del proyecto"
  type        = string
}

variable "environment" {
  description = "Ambiente (dev, qa, uat, pdn)"
  type        = string
}

variable "account" {
  description = "Nombre de la cuenta AWS"
  type        = string
}

variable "billing_mode" {
  description = "Billing mode: PROVISIONED o PAY_PER_REQUEST. null = auto (PAY_PER_REQUEST si no autoscaling, PROVISIONED si autoscaling)"
  type        = string
  default     = null
  validation {
    condition = var.billing_mode == null ? true : contains(["PROVISIONED", "PAY_PER_REQUEST"], var.billing_mode)
    error_message = "billing_mode debe ser PROVISIONED, PAY_PER_REQUEST, o null"
  }
}

variable "table_class" {
  description = "Clase de la tabla: STANDARD o STANDARD_INFREQUENT_ACCESS"
  type        = string
  default     = "STANDARD"
  validation {
    condition     = contains(["STANDARD", "STANDARD_INFREQUENT_ACCESS"], var.table_class)
    error_message = "table_class debe ser STANDARD o STANDARD_INFREQUENT_ACCESS"
  }
}

variable "hash_key" {
  description = "Partition key (hash key) - REQUERIDO"
  type        = string
}

variable "hash_key_type" {
  description = "Tipo del hash key: S (string), N (number), B (binary)"
  type        = string
  default     = "S"
  validation {
    condition     = contains(["S", "N", "B"], var.hash_key_type)
    error_message = "hash_key_type debe ser S, N, o B"
  }
}

variable "range_key" {
  description = "Sort key (range key) - OPCIONAL"
  type        = string
  default     = null
}

variable "range_key_type" {
  description = "Tipo del range key: S (string), N (number), B (binary)"
  type        = string
  default     = "S"
  validation {
    condition     = contains(["S", "N", "B"], var.range_key_type)
    error_message = "range_key_type debe ser S, N, o B"
  }
}

variable "attributes" {
  description = "Atributos adicionales para GSI y LSI"
  type = list(object({
    name = string
    type = string  # S, N, B
  }))
  default = []
}

variable "read_capacity" {
  description = "Read capacity units. Solo para PROVISIONED"
  type        = number
  default     = 5
}

variable "write_capacity" {
  description = "Write capacity units. Solo para PROVISIONED"
  type        = number
  default     = 5
}

variable "enable_autoscaling" {
  description = "Habilitar auto-scaling. Solo para PROVISIONED"
  type        = bool
  default     = false
}

variable "autoscaling_read_max_capacity" {
  description = "Capacidad máxima de read para auto-scaling"
  type        = number
  default     = 100
}

variable "autoscaling_write_max_capacity" {
  description = "Capacidad máxima de write para auto-scaling"
  type        = number
  default     = 100
}

variable "autoscaling_read_target" {
  description = "Target de utilización para read capacity (%)"
  type        = number
  default     = 70
}

variable "autoscaling_write_target" {
  description = "Target de utilización para write capacity (%)"
  type        = number
  default     = 70
}

variable "autoscaling_scale_in_cooldown" {
  description = "Cooldown en segundos para scale in"
  type        = number
  default     = 60
}

variable "autoscaling_scale_out_cooldown" {
  description = "Cooldown en segundos para scale out"
  type        = number
  default     = 60
}

variable "global_secondary_indexes" {
  description = "Lista de Global Secondary Indexes"
  type = list(object({
    name               = string
    hash_key           = string
    range_key          = optional(string)
    projection_type    = string  
    non_key_attributes = optional(list(string))
    read_capacity      = optional(number)
    write_capacity     = optional(number)
    enable_autoscaling = optional(bool)
    autoscaling_read_max_capacity  = optional(number)
    autoscaling_write_max_capacity = optional(number)
  }))
  default = []
}

variable "local_secondary_indexes" {
  description = "Lista de Local Secondary Indexes"
  type = list(object({
    name               = string
    range_key          = string
    projection_type    = string  # ALL, KEYS_ONLY, INCLUDE
    non_key_attributes = optional(list(string))
  }))
  default = []
}

variable "stream_enabled" {
  description = "Habilitar DynamoDB Streams"
  type        = bool
  default     = false
}

variable "stream_view_type" {
  description = "Tipo de stream: NEW_IMAGE, OLD_IMAGE, NEW_AND_OLD_IMAGES, KEYS_ONLY"
  type        = string
  default     = "NEW_AND_OLD_IMAGES"
  validation {
    condition     = contains(["NEW_IMAGE", "OLD_IMAGE", "NEW_AND_OLD_IMAGES", "KEYS_ONLY"], var.stream_view_type)
    error_message = "stream_view_type debe ser NEW_IMAGE, OLD_IMAGE, NEW_AND_OLD_IMAGES, o KEYS_ONLY"
  }
}

variable "ttl_enabled" {
  description = "Habilitar Time To Live"
  type        = bool
  default     = false
}

variable "ttl_attribute_name" {
  description = "Nombre del atributo que contiene el timestamp TTL (epoch seconds)"
  type        = string
  default     = "ttl"
}

variable "point_in_time_recovery_enabled" {
  description = "Habilitar Point-in-Time Recovery"
  type        = bool
  default     = true
}

variable "encryption_enabled" {
  description = "Habilitar encryption at rest"
  type        = bool
  default     = true
}

variable "kms_key_arn" {
  description = "ARN de la KMS key para encryption. null = AWS managed key"
  type        = string
  default     = null
}

variable "deletion_protection_enabled" {
  description = "Enable DynamoDB deletion protection"
  type    = bool
  default = false
}

variable "tags" {
  description = "Tags adicionales"
  type        = map(string)
  default     = {}
}
