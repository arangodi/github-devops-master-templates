variable "config_file" {
  description = "Path al archivo YAML de configuración del proyecto"
  type        = string
}

variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "project_name" {
  description = "Nombre de la cuenta AWS"
  type        = string
}

variable "environment" {
  description = "Ambiente (dev, qa, pdn, uat)"
  type        = string
}

variable "account" {
  description = "Nombre de la cuenta AWS"
  type        = string
}