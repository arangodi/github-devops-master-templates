variable "name" {
  description = "Nombre del cluster — resulta en ecs-{name}-{environment}-cluster"
  type        = string
}

variable "project_name" {
  description = "Nombre del proyecto"
  type        = string
}

variable "vpc_id" {
  description = "ID de la VPC"
  type        = string
}

variable "is_production" {
  description = "true = habilita container insights y usa FARGATE sobre FARGATE_SPOT"
  type        = bool
  default     = false
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