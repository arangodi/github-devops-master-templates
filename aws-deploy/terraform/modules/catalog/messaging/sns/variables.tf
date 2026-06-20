variable "name" {
  description = "Nombre del topic SNS"
  type        = string
}

variable "project_name" {
  description = "Nombre del proyecto"
  type        = string
}

variable "environment" {
  description = "Ambiente (dev, qa, pdn, uat)"
  type        = string
}

variable "account" {
  description = "Nombre de la cuenta AWS"
  type        = string
}

variable "fifo" {
  description = "Indica si el topic es FIFO"
  type        = bool
  default     = false
}

variable "content_based_deduplication" {
  description = "Indica si el topic usa content-based deduplication"
  type        = bool
  default     = false
}

variable "kms_master_key_id" {
  description = "ID de la llave KMS"
  type        = string
  default     = null
}

variable "policy_statements" {
  description = "Statements IAM para la política del topic. Si resources es null, se usa el ARN del topic."
  type = list(object({
    sid         = optional(string)
    effect      = string
    actions     = list(string)
    not_actions = optional(list(string))
    resources   = optional(list(string))
    principals = list(object({
      type        = string
      identifiers = list(string)
    }))
    conditions = optional(list(object({
      test     = string
      variable = string
      values   = list(string)
    })), [])
  }))
  default = []
}

variable "subscriptions" {
  description = "Subscripciones al topic"
  type        = list(object({
    protocol             = string
    endpoint             = string
    filter_policy        = optional(string, null)
    filter_policy_scope  = optional(string, null)
    raw_message_delivery = optional(bool, false)
    redrive_policy       = optional(string, null)
  }))
  default     = []
}

variable "tags" {
  description = "Tags adicionales"
  type        = map(string)
  default     = {}
}