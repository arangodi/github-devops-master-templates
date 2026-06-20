variable "name" {
  description = "Nombre lógico del ENI"
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


variable "subnet_id" {
  description = "ID de la subnet"
  type        = string
}

variable "private_ip" {
  description = "IP privada fija. null = AWS asigna automáticamente pero se mantiene fija"
  type        = string
  default     = null
}

variable "security_group_ids" {
  description = "IDs de Security Groups asociados al ENI"
  type        = list(string)
  default     = []
}

variable "description" {
  description = "Descripción del ENI"
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags adicionales"
  type        = map(string)
  default     = {}
}