variable "name" {
  description = "Nombre lógico del WebSocket API — resulta en wsapi-{project_name}-{name}"
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
  description = "true = crea el WebSocket API, false = referencia uno existente por nombre"
  type        = bool
  default     = true
}

variable "existing_api_name" {
  description = "Nombre del WebSocket API existente en AWS. El módulo lo busca via data source. Requerido si create = false"
  type        = string
  default     = null
}

variable "description" {
  description = "Descripción del WebSocket API"
  type        = string
  default     = null
}

variable "route_selection_expression" {
  description = "Expresión para seleccionar la ruta según el contenido del mensaje"
  type        = string
  default     = "$request.body.action"
}


variable "create_stage" {
  description = "Crear el stage del API"
  type        = bool
  default     = true
}

variable "auto_deploy" {
  description = "Desplegar automáticamente cuando hay cambios en el API"
  type        = bool
  default     = true
}

variable "log_retention_days" {
  description = "Días de retención de logs en CloudWatch"
  type        = number
  default     = 30
}


variable "enable_vpc_link" {
  description = "Crear VPC Link v2 para integración con NLB interno"
  type        = bool
  default     = false
}

variable "nlb_arn" {
  description = "ARN del NLB para el VPC Link. Requerido si enable_vpc_link = true"
  type        = string
  default     = null
}

variable "vpc_id" {
  description = "ID de la VPC. Requerido si enable_vpc_link = true"
  type        = string
  default     = null
}

variable "subnet_ids" {
  description = "Subnets para el VPC Link. Requerido si enable_vpc_link = true"
  type        = list(string)
  default     = []
}


variable "ingress_cidr" {
  description = "CIDR permitido en el SG del VPC Link"
  type        = string
  default     = "10.0.0.0/8"
}

variable "ingress_port" {
  description = "Puerto de ingress del SG del VPC Link"
  type        = number
  default     = 443
}


variable "tags" {
  description = "Tags adicionales"
  type        = map(string)
  default     = {}
}
