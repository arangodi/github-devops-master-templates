variable "project_name" {
  description = "Nombre del proyecto — el namespace queda como {project_name}.net"
  type        = string
}

variable "create" {
  description = "true = crea el namespace, false = referencia uno existente"
  type        = bool
  default     = true
}

variable "vpc_id" {
  description = "ID de la VPC donde se crea el namespace privado"
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