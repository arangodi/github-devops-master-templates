variable "name" {
  description = "Nombre lógico del certificado — usado para identificarlo en outputs"
  type        = string
}

variable "create" {
  description = "true = crea el certificado, false = referencia uno existente"
  type        = bool
  default     = true
}

variable "domain" {
  description = "Dominio principal del certificado. Requerido si create = true"
  type        = string
  default     = null
}

variable "subject_alternative_names" {
  description = "Dominios alternativos del certificado"
  type        = list(string)
  default     = []
}

variable "validation_method" {
  description = "Metodo de validacion: DNS o EMAIL"
  type        = string
  default     = "DNS"

  validation {
    condition     = contains(["DNS", "EMAIL"], var.validation_method)
    error_message = "validation_method debe ser DNS o EMAIL"
  }
}

variable "existing_arn" {
  description = "ARN del certificado existente. Requerido si create = false"
  type        = string
  default     = null
}

variable "project_name" {
  description = "Nombre de la cuenta AWS"
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

variable "create_zone" {
  description = "true = crea la zona Route53, false = usa una existente"
  type        = bool
  default     = false
}

variable "vpc_id" {
  description = "ID de la VPC para la zona privada de Route53. Requerido si create_zone = true"
  type        = string
  default     = null
}

variable "apex_domain" {
  description = "Apex del dominio para la zona Route53. Si null se infiere del domain"
  type        = string
  default     = null
}