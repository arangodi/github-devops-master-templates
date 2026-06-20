variable "name" {
  description = "Nombre lógico de la instancia"
  type        = string
}

variable "project_name" {
  description = "Nombre del proyecto"
  type        = string
}

variable "environment" {
  description = "Ambiente (dev, qc, uat, pdn)"
  type        = string
}

variable "account" {
  description = "Nombre de la cuenta AWS"
  type        = string
}

variable "fifo" {
  description = "Indica si la cola es FIFO (true) o estándar (false)"
  type        = bool
  default     = false
}

variable "content_based_deduplication" {
  description = "Solo aplica a colas FIFO: deduplicación por contenido"
  type        = bool
  default     = false
}

variable "visibility_timeout" {
  description = "Tiempo de visibilidad en segundos"
  type        = number
  default     = 30
}

variable "message_retention_seconds" {
  description = "Tiempo de retención de mensajes en segundos"
  type        = number
  default     = 345600
}

variable "delay_seconds" {
  description = "Tiempo de retraso en segundos"
  type        = number
  default     = 0
}

variable "maximum_message_size" {
  description = "Tamaño máximo del mensaje en bytes"
  type        = number
  default     = 262144
}

variable "receive_message_wait_time_seconds" {
  description = "Tiempo de espera para recibir mensajes en segundos (long polling)"
  type        = number
  default     = 0
}

variable "dead_letter_queue" {
  description = "Configuración de la cola de mensajes no entregados (dead letter queue)"
  type = object({
    target_arn        = string
    max_receive_count = number
  })
  default = null
}

variable "tags" {
  description = "Tags adicionales"
  type        = map(string)
  default     = {}
}
