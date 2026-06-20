variable "name" {
  description = "Nombre lógico del filesystem — resulta en efs-{project_name}-{name}"
  type        = string
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

variable "vpc_id" {
  description = "ID de la VPC"
  type        = string
}

variable "subnet_ids" {
  description = "Subnets donde se crean los mount targets (una por AZ)"
  type        = list(string)
}

variable "create" {
  description = "true = crea el filesystem, false = referencia uno existente"
  type        = bool
  default     = true
}

variable "existing_filesystem_id" {
  description = "ID del filesystem existente. Requerido si create = false"
  type        = string
  default     = null
}

variable "performance_mode" {
  description = "Modo de performance: generalPurpose o maxIO"
  type        = string
  default     = "generalPurpose"

  validation {
    condition     = contains(["generalPurpose", "maxIO"], var.performance_mode)
    error_message = "performance_mode debe ser generalPurpose o maxIO"
  }
}

variable "throughput_mode" {
  description = "Modo de throughput: bursting, provisioned o elastic"
  type        = string
  default     = "bursting"

  validation {
    condition     = contains(["bursting", "provisioned", "elastic"], var.throughput_mode)
    error_message = "throughput_mode debe ser bursting, provisioned o elastic"
  }
}

variable "provisioned_throughput_in_mibps" {
  description = "Throughput provisionado en MiB/s. Solo si throughput_mode = provisioned"
  type        = number
  default     = null
}

variable "transition_to_ia" {
  description = "Días antes de mover archivos a Infrequent Access. null = sin transición"
  type        = string
  default     = null

  validation {
    condition = var.transition_to_ia == null ? true : contains([
      "AFTER_7_DAYS", "AFTER_14_DAYS", "AFTER_30_DAYS",
      "AFTER_60_DAYS", "AFTER_90_DAYS"
    ], var.transition_to_ia)
    error_message = "transition_to_ia debe ser AFTER_7_DAYS, AFTER_14_DAYS, AFTER_30_DAYS, AFTER_60_DAYS, AFTER_90_DAYS o null"
  }
}

variable "encryption_enabled" {
  description = "Habilitar encripción at rest"
  type        = bool
  default     = true
}

variable "kms_key_arn" {
  description = "ARN de la KMS key. null = AWS managed key"
  type        = string
  default     = null
}

variable "enable_backup" {
  description = "Habilitar AWS Backup para el filesystem"
  type        = bool
  default     = true
}


variable "access_points" {
  description = "Lista de access points — uno por servicio ECS que monta el filesystem"
  type = list(object({
    name        = string
    path        = optional(string, "/")
    uid         = optional(number, 1000)
    gid         = optional(number, 1000)
    permissions = optional(string, "755")
  }))
  default = []
}

variable "tags" {
  description = "Tags adicionales"
  type        = map(string)
  default     = {}
}
