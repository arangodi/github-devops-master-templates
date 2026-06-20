variable "name" {
  description = "Capa de aplicacion - resulta en ecr-{project}-{environment}-{name}"
  type        = string
}

variable "create" {
  description = "true = crea el repositorio, false = referencia uno existente"
  type        = bool
  default     = true
}

variable "existing_uri" {
  description = "URI del repositorio existente. Requerido si create = false"
  type        = string
  default     = null
}

variable "image_tag_mutability" {
  description = "MUTABLE o IMMUTABLE"
  type        = string
  default     = "MUTABLE"

  validation {
    condition     = contains(["MUTABLE", "IMMUTABLE"], var.image_tag_mutability)
    error_message = "image_tag_mutability debe ser MUTABLE o IMMUTABLE"
  }
}

variable "scan_on_push" {
  description = "Escanear imagen al hacer push"
  type        = bool
  default     = true
}

variable "encryption_type" {
  description = "Tipo de encripcion: AES256 o KMS"
  type        = string
  default     = "KMS"

  validation {
    condition     = contains(["AES256", "KMS"], var.encryption_type)
    error_message = "encryption_type debe ser AES256 o KMS"
  }
}

variable "kms_key_arn" {
  description = "ARN de la llave KMS. null = usa la key por defecto de AWS"
  type        = string
  default     = null
}

variable "lifecycle_policy" {
  description = "Politica de ciclo de vida del repositorio. null = sin politica"
  type = object({
    keep_last_images           = optional(number, 10)
    expire_untagged_after_days = optional(number, 7)
  })
  default = null
}

variable "allow_account_ids" {
  description = "IDs de cuentas AWS que pueden hacer pull de este repositorio"
  type        = list(string)
  default     = []
}

variable "project_name" {
  description = "Nombre del proyecto"
  type        = string
}

variable "environment" {
  description = "Ambiente (dev, qa, pdn, uat)"
  type        = string
}

variable "tags" {
  description = "Tags adicionales"
  type        = map(string)
  default     = {}
}

variable "account" {
  description = "Nombre de la cuenta AWS"
  type        = string
}

variable "create_ssm_parameter" {
  description = "Whether to create SSM parameter for image version (useful for ECS, not for EKS)"
  type        = bool
  default     = true
}

variable "image_version" {
  description = "Initial image version"
  type        = string
  default     = "latest"
}