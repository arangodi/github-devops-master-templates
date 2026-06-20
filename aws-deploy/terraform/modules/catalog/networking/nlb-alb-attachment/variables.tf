variable "nlb_arn" {
  description = "ARN del NLB ya creado"
  type        = string
}

variable "alb_arn" {
  description = "ARN del ALB destino ya creado"
  type        = string
}

variable "port" {
  description = "Puerto del listener del NLB y del target group hacia el ALB"
  type        = number
  default     = 80
}

variable "certificate_arn" {
  description = "ARN del certificado ACM. Si se especifica, el listener del NLB usa TLS en vez de TCP"
  type        = string
  default     = null
}

variable "ssl_policy" {
  description = "SSL policy del listener TLS"
  type        = string
  default     = "ELBSecurityPolicy-TLS13-1-2-Ext2-2021-06"
}

variable "vpc_id" {
  description = "ID de la VPC"
  type        = string
}

variable "project_name" {
  description = "Nombre del proyecto"
  type        = string
}

variable "name" {
  description = "Nombre lógico del NLB — usado para nombrar el target group"
  type        = string
}

variable "health_check_path" {
  description = "Path del health check hacia el ALB. Por defecto / con matcher amplio para tolerar fixed-response 400"
  type        = string
  default     = "/"
}

variable "tags" {
  description = "Tags adicionales"
  type        = map(string)
  default     = {}
}
