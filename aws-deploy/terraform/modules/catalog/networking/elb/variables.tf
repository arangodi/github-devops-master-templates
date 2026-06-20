variable "name" {
  description = "Nombre que indica el proposito"
  type        = string
}

variable "create" {
  description = "true = crea el ELB, false = referencia uno existente"
  type        = bool
  default     = true
}

variable "existing_listener_arn" {
  description = "ARN del listener existente. Solo si create = false"
  type        = string
  default     = null
}

variable "existing_sg_id" {
  description = "ID del SG del ELB existente. Solo si create = false"
  type        = string
  default     = null
}

variable "existing_arn" {
  description = "ARN del ELB existente. Solo si create = false"
  type        = string
  default     = null
}

variable "load_balancer_type" {
  description = "Tipo de load balancer: application o network"
  type        = string
  default     = "application"

  validation {
    condition     = contains(["application", "network"], var.load_balancer_type)
    error_message = "load_balancer_type debe ser application o network"
  }
}

variable "deletion_protection" {
  description = "Habilitar protección ante borrado"
  type        = bool
  default     = true
}

variable "vpc_id" {
  description = "ID de la VPC"
  type        = string
}

variable "subnet_ids" {
  description = "Subnets donde se despliega el ELB (subnets ELB)"
  type        = list(string)
}

variable "certificate_arn" {
  description = "ARN del certificado ACM para HTTPS"
  type        = string
  default = null
}

variable "port" {
  description = "Puerto del listener"
  type        = number
  default     = 443
}

variable "internal" {
  description = "true = internal, false = internet-facing"
  type        = bool
  default     = true
}

variable "idle_timeout" {
  description = "Idle timeout en segundos"
  type        = number
  default     = 60
}

variable "ssl_policy" {
  description = "SSL policy del listener HTTPS"
  type        = string
  default     = "ELBSecurityPolicy-TLS13-1-2-Ext2-2021-06"
}

variable "ingress_cidr" {
  description = "CIDR permitido en el SG del LB"
  type        = string
  default     = "10.0.0.0/8"
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

variable "account" {
  description = "Nombre de la cuenta AWS"
  type        = string
}

variable "default_target_group_arn" {
  description = "ARN del target group por defecto para el listener del NLB. Solo si load_balancer_type = network"
  type        = string
  default     = null
}

variable "subnet_group" {
  description = "Grupo de subnets a usar: EC2 para ELB interno, ELB para ELB público"
  type        = string
  default     = "EC2"
}