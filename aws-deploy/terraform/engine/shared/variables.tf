variable "config_file" {
  description = "Path al archivo YAML de configuración del proyecto"
  type        = string
}

variable "aws_region" {
  type    = string
  default = "us-east-1"
}