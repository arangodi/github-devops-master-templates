variable "name" {
  description = "Nombre lógico del secret — resulta en {project}-{env}-{name}"
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

variable "create" {
  description = "true = crea el secret, false = referencia uno existente"
  type        = bool
  default     = true
}

variable "existing_secret_arn" {
  description = "ARN del secret existente. Requerido si create: false"
  type        = string
  default     = null
}

variable "description" {
  description = "Descripción del secret"
  type        = string
  default     = null
}

variable "kms_key_id" {
  description = "ARN o ID de la KMS key. null = key por defecto de AWS"
  type        = string
  default     = null
}

variable "recovery_window_days" {
  description = "Dias de ventana de recuperacion antes de eliminar el secret (0 = eliminacion inmediata)"
  type        = number
  default     = 0

  validation {
    condition     = var.recovery_window_days == 0 || (var.recovery_window_days >= 7 && var.recovery_window_days <= 30)
    error_message = "recovery_window_days debe ser 0 (inmediato) o entre 7 y 30 dias"
  }
}

variable "secret_type" {
  description = "Tipo de secret: string o binary"
  type        = string
  default     = "string"

  validation {
    condition     = contains(["string", "binary"], var.secret_type)
    error_message = "secret_type debe ser string o binary"
  }
}

variable "enable_rotation" {
  description = "Habilitar rotacion automatica del secret"
  type        = bool
  default     = false
}

variable "rotation_lambda_arn" {
  description = "ARN de la Lambda que rota el secret. Requerido si enable_rotation: true"
  type        = string
  default     = null
}

variable "rotation_days" {
  description = "Cada cuantos dias rotar el secret"
  type        = number
  default     = 30
}

variable "rotation_duration" {
  description = "Duracion de la ventana de rotacion en horas (ej: 2h)"
  type        = string
  default     = "2h"
}

variable "create_reader_role" {
  description = "Crear un rol IAM que pueda leer este secret"
  type        = bool
  default     = false
}

variable "reader_role_name" {
  description = "Nombre del rol reader. null = genera {project}-{env}-{name}-reader"
  type        = string
  default     = null
}

variable "reader_role_trusted_services" {
  description = "Servicios de AWS que pueden asumir el reader role (ej: lambda.amazonaws.com, ecs-tasks.amazonaws.com)"
  type        = list(string)
  default     = ["lambda.amazonaws.com"]
}

variable "reader_role_trusted_arns" {
  description = "ARNs de roles/usuarios que pueden asumir el reader role (ej: cross-account)"
  type        = list(string)
  default     = []
}

variable "create_writer_role" {
  description = "Crear un rol IAM que pueda escribir este secret"
  type        = bool
  default     = false
}

variable "writer_role_name" {
  description = "Nombre del rol writer. null = genera {project}-{env}-{name}-writer"
  type        = string
  default     = null
}

variable "writer_role_trusted_services" {
  description = "Servicios de AWS que pueden asumir el writer role"
  type        = list(string)
  default     = ["lambda.amazonaws.com"]
}

variable "writer_role_trusted_arns" {
  description = "ARNs de roles/usuarios que pueden asumir el writer role"
  type        = list(string)
  default     = []
}

variable "reader_role_arns" {
  description = "Lista de ARNs de IAM Roles que pueden LEER el secret (resource policy)"
  type        = list(string)
  default     = []
}

variable "writer_role_arns" {
  description = "Lista de ARNs de IAM Roles que pueden ESCRIBIR el secret (resource policy)"
  type        = list(string)
  default     = []
}

variable "admin_role_arns" {
  description = "Lista de ARNs de IAM Roles con acceso COMPLETO al secret (resource policy)"
  type        = list(string)
  default     = []
}

variable "secret_value" {
  description = "Valor inicial del secret. Puede ser un objeto (se convierte a JSON) o string. null = secret vacío"
  type        = any
  default     = null
  sensitive   = true
}

variable "tags" {
  description = "Tags adicionales"
  type        = map(string)
  default     = {}
}
