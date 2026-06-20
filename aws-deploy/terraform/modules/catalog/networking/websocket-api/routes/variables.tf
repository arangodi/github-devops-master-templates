variable "name" {
  description = "Nombre lógico del grupo de rutas"
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

variable "api_id" {
  description = "ID del WebSocket API — output del módulo base"
  type        = string
}

variable "vpc_link_id" {
  description = "ID del VPC Link v2 — output del módulo base. null = sin VPC Link"
  type        = string
  default     = null
}

variable "integration_uri" {
  description = "URI del backend. Ej: http://nlb-dns/api"
  type        = string
}

variable "integration_type" {
  description = "Tipo de integración: HTTP_PROXY o AWS_PROXY"
  type        = string
  default     = "HTTP_PROXY"

  validation {
    condition     = contains(["HTTP_PROXY", "AWS_PROXY"], var.integration_type)
    error_message = "integration_type debe ser HTTP_PROXY o AWS_PROXY"
  }
}

variable "connection_type" {
  description = "Tipo de conexión: VPC_LINK o INTERNET"
  type        = string
  default     = "VPC_LINK"

  validation {
    condition     = contains(["VPC_LINK", "INTERNET"], var.connection_type)
    error_message = "connection_type debe ser VPC_LINK o INTERNET"
  }
}

variable "integration_method" {
  description = "Método HTTP de la integración con el backend"
  type        = string
  default     = "ANY"
}


variable "routes" {
  description = "Lista de rutas WebSocket a crear"
  type = list(object({
    key              = string
    route_key        = string        
    integration_uri  = optional(string) 
    authorization_type = optional(string, "NONE")
  }))
  default = []
}

variable "tags" {
  description = "Tags adicionales"
  type        = map(string)
  default     = {}
}
