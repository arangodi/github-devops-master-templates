variable "name" {
  description = "Nombre lógico del API Gateway"
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

variable "description" {
  description = "Descripción del API Gateway"
  type        = string
  default     = null
}

variable "existing_api_name" {
  description = "Nombre del API Gateway existente. El data source obtiene el ID y root_resource_id automáticamente"
  type        = string
  default     = null
}

variable "existing_custom_domain_name" {
  description = "Nombre de un custom domain existente"
  type        = string
  default     = null
}

variable "endpoint_type" {
  description = "Tipo de endpoint: REGIONAL, EDGE o PRIVATE"
  type        = string
  default     = "REGIONAL"

  validation {
    condition     = contains(["REGIONAL", "EDGE", "PRIVATE"], var.endpoint_type)
    error_message = "endpoint_type debe ser REGIONAL, EDGE o PRIVATE"
  }
}

variable "custom_domain_security_policy" {
  description = "Política de seguridad TLS para el custom domain: TLS_1_0 o TLS_1_2"
  type        = string
  default     = "TLS_1_2"

  validation {
    condition     = contains(["TLS_1_0", "TLS_1_2"], var.custom_domain_security_policy)
    error_message = "custom_domain_security_policy debe ser TLS_1_0 o TLS_1_2"
  }
}

variable "vpc_endpoint_ids" {
  description = "IDs de VPC endpoints. Solo si endpoint_type = PRIVATE"
  type        = list(string)
  default     = []
}

variable "enable_cognito" {
  description = "Habilitar Cognito User Pool y autorizador"
  type        = bool
  default     = false
}

variable "client_name" {
  description = "Nombre del cliente OAuth2 en Cognito — resulta en {project}-{env}-{client_name}-client"
  type        = string
  default     = null
}

variable "existing_user_pool_id" {
  description = "ID de un Cognito User Pool existente. Si se declara no crea uno nuevo"
  type        = string
  default     = null
}

variable "cognito_domain_prefix" {
  description = "Prefijo del dominio de Cognito"
  type        = string
  default     = ""
}

variable "enable_cognito_domain" {
  description = "Crear dominio para el Cognito User Pool"
  type        = bool
  default     = false
}

variable "access_token_validity" {
  description = "Duración del access token en minutos"
  type        = number
  default     = 60
}

variable "id_token_validity" {
  description = "Duración del ID token en minutos"
  type        = number
  default     = 60
}

variable "refresh_token_validity" {
  description = "Duración del refresh token en días"
  type        = number
  default     = 30
}

variable "enable_token_revocation" {
  description = "Habilitar revocación de tokens"
  type        = bool
  default     = true
}

variable "enable_client_credentials" {
  description = "Habilitar flujo client_credentials en Cognito"
  type        = bool
  default     = false
}

variable "resource_servers" {
  description = "Lista de resource servers para Cognito"
  type = list(object({
    identifier = string
    name       = string
    scopes = list(object({
      name        = string
      description = string
    }))
  }))
  default = []
}

variable "enable_vpc_link" {
  description = "Crear VPC Link para integración con NLB"
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

variable "create_stage" {
  description = "Crear el stage del API"
  type        = bool
  default     = true
}

variable "logging_level" {
  description = "Nivel de logging: OFF, ERROR o INFO"
  type        = string
  default     = "INFO"

  validation {
    condition     = contains(["OFF", "ERROR", "INFO"], var.logging_level)
    error_message = "logging_level debe ser OFF, ERROR o INFO"
  }
}

variable "enable_method_metrics" {
  description = "Habilitar métricas por método"
  type        = bool
  default     = true
}

variable "enable_data_trace" {
  description = "Habilitar traza de datos. Solo para debugging"
  type        = bool
  default     = false
}

variable "log_retention_days" {
  description = "Días de retención de logs en CloudWatch"
  type        = number
  default     = 30
}

variable "enable_dummy_endpoint" {
  description = "Crear endpoint dummy para el deployment inicial"
  type        = bool
  default     = true
}

variable "enable_api_key" {
  description = "Crear API Key y Usage Plan"
  type        = bool
  default     = true
}

variable "quota_limit" {
  description = "Límite de requests por periodo"
  type        = number
  default     = 1000
}

variable "quota_period" {
  description = "Periodo del quota: DAY, WEEK o MONTH"
  type        = string
  default     = "MONTH"

  validation {
    condition     = contains(["DAY", "WEEK", "MONTH"], var.quota_period)
    error_message = "quota_period debe ser DAY, WEEK o MONTH"
  }
}

variable "throttle_rate_limit" {
  description = "Rate limit de requests por segundo"
  type        = number
  default     = 10
}

variable "throttle_burst_limit" {
  description = "Burst limit de requests"
  type        = number
  default     = 2
}

variable "enable_custom_domain" {
  description = "Habilitar custom domain"
  type        = bool
  default     = false
}

variable "custom_domain_name" {
  description = "Nombre del dominio custom"
  type        = string
  default     = ""
}

variable "custom_domain_base_path" {
  description = "Base path del custom domain"
  type        = string
  default     = "(none)"
}

variable "custom_domain_certificate_arn" {
  description = "ARN del certificado ACM para el custom domain"
  type        = string
  default     = null
}

variable "cloudwatch_role_arn" {
  description = "ARN del IAM Role para logs de API Gateway. null = sin logs"
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags adicionales"
  type        = map(string)
  default     = {}
}