variable "bucket_name" {
  description = "Nombre del bucket S3"
  type        = string
}

variable "versioning" {
  description = "Habilitar versionamiento del bucket"
  type        = bool
  default     = false
}

variable "encryption" {
  description = "Habilitar encripción SSE-S3 del bucket"
  type        = bool
  default     = true
}

variable "block_public_access" {
  description = "Bloquear todo acceso público al bucket"
  type        = bool
  default     = true
}

variable "bucket_policy" {
  description = "JSON de la política del bucket. null = no se crea política"
  type        = string
  default     = null
}

variable "lifecycle_rules" {
  description = "Lista de reglas de ciclo de vida del bucket"
  type = list(object({
    id      = string
    enabled = bool
    
    filter = optional(object({
      prefix                   = optional(string)
      object_size_greater_than = optional(number)
      object_size_less_than    = optional(number)
      tags                     = optional(map(string))
    }))
    
    transitions = optional(list(object({
      days          = number
      storage_class = string  # STANDARD_IA, INTELLIGENT_TIERING, GLACIER_IR, GLACIER, DEEP_ARCHIVE
    })), [])
    

    expiration = optional(object({
      days                         = optional(number)
      expired_object_delete_marker = optional(bool)
    }))
    
    noncurrent_version_transitions = optional(list(object({
      storage_class    = string
      noncurrent_days  = number
      newer_noncurrent_versions = optional(number)
    })), [])
    

    noncurrent_version_expiration = optional(object({
      noncurrent_days           = number
      newer_noncurrent_versions = optional(number)
    }))
    
    abort_incomplete_multipart_upload = optional(object({
      days_after_initiation = number
    }))
  }))
  default = []
}

variable "logging" {
  description = "Configuración de logging. null = no se habilita"
  type = object({
    target_bucket = string
    target_prefix = optional(string, "logs/")
  })
  default = null
}

variable "notifications" {
  description = "Notificaciones S3 a Lambda, SQS o SNS. null = no se crean"
  type = object({
    lambda_arn = optional(string, null)
    sqs_arn    = optional(string, null)
    sns_arn    = optional(string, null)
    events     = optional(list(string), ["s3:ObjectCreated:*"])
    prefix     = optional(string, "")
    suffix     = optional(string, "")
  })
  default = null
}

variable "replication" {
  description = "Replicación a otro bucket. null = no se habilita"
  type = object({
    role_arn           = string
    destination_bucket = string
    destination_region = string
    replicate_delete   = optional(bool, false)
  })
  default = null
}

variable "tags" {
  description = "Tags adicionales del bucket"
  type        = map(string)
  default     = {}
}

variable "project_name" {
  description = "Nombre de la cuenta AWS"
  type        = string
}

variable "environment" {
  description = "Ambiente (dev, qa, pdn, uat)"
  type        = string
}

