variable "name" {
  description = "Nombre lógico del servicio/ruta"
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

variable "apigw_id" {
  description = "ID del REST API Gateway — output del módulo base"
  type        = string
}

variable "apigw_root_resource_id" {
  description = "ID del resource raíz — output del módulo base"
  type        = string
}

variable "apigw_stage_name" {
  description = "Nombre del stage — output del módulo base"
  type        = string
}

variable "vpc_link_id" {
  description = "ID del VPC Link — output del módulo base"
  type        = string
  default     = null
}

variable "authorizer_id" {
  description = "ID del autorizador Cognito — output del módulo base"
  type        = string
  default     = null
}

variable "integration_uri" {
  description = "URI de integración con el NLB"
  type        = string
}

variable "nlb_arn" {
  description = "ARN del NLB para el VPC Link"
  type        = string
}

variable "http_method" {
  description = "Método HTTP del método del API Gateway"
  type        = string
  default     = "ANY"
}

variable "integration_http_method" {
  description = "Método HTTP de la integración"
  type        = string
  default     = "ANY"
}

variable "paths" {
  description = "Lista de paths a crear. Soporta hasta 9 niveles de profundidad"
  type = list(object({
    key             = string
    path_part       = string
    methods         = list(string)
    parent_key      = string
    integration_uri = optional(string, null)
    integration_path = optional(string, null)
    api_key_required = optional(bool, false)
    existing_resource_id = optional(string, null)
  }))
  default = []
}

variable "create_proxy" {
  description = "Crear recurso {proxy+} directamente"
  type        = bool
  default     = false
}

variable "proxy_methods" {
  description = "Métodos HTTP para el proxy"
  type        = list(string)
  default     = ["ANY"]
}

variable "proxy_parent_key" {
  description = "Key del recurso padre bajo el cual se crea el {proxy+}"
  type        = string
  default     = null
}

variable "authorization" {
  description = "Tipo de autorización: NONE o COGNITO_USER_POOLS"
  type        = string
  default     = "NONE"

  validation {
    condition     = contains(["NONE", "COGNITO_USER_POOLS"], var.authorization)
    error_message = "authorization debe ser NONE o COGNITO_USER_POOLS"
  }
}

variable "integration_type" {
  description = "Tipo de integración: HTTP_PROXY, HTTP, AWS_PROXY, MOCK"
  type        = string
  default     = "HTTP_PROXY"

  validation {
    condition     = contains(["HTTP_PROXY", "HTTP", "AWS_PROXY", "MOCK"], var.integration_type)
    error_message = "integration_type debe ser HTTP_PROXY, HTTP, AWS_PROXY o MOCK"
  }
}

variable "connection_type" {
  description = "Tipo de conexión: VPC_LINK o INTERNET. VPC_LINK requiere vpc_link_id"
  type        = string
  default     = "VPC_LINK"

  validation {
    condition     = contains(["VPC_LINK", "INTERNET"], var.connection_type)
    error_message = "connection_type debe ser VPC_LINK o INTERNET"
  }
}

variable "cognito_token_endpoint" {
  description = "URL del endpoint /oauth2/token de Cognito — provisto por el módulo base"
  type        = string
  default     = null
}

variable "cognito_authorize_endpoint" {
  description = "URL del endpoint /oauth2/authorize de Cognito — provisto por el módulo base"
  type        = string
  default     = null
}

variable "cognito_userinfo_endpoint" {
  description = "URL del endpoint /oauth2/userInfo de Cognito — provisto por el módulo base"
  type        = string
  default     = null
}

variable "cognito_revoke_endpoint" {
  description = "URL del endpoint /oauth2/revoke de Cognito — provisto por el módulo base"
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags adicionales"
  type        = map(string)
  default     = {}
}