variable "name" {
  description = "Nombre lógico de la instancia o grupo"
  type        = string
}

variable "project_name" {
  description = "Nombre del proyecto"
  type        = string
}

variable "environment" {
  description = "Ambiente (dev, qc, uat, pdn)"
  type        = string
}

variable "vpc_id" {
  description = "ID de la VPC"
  type        = string
}

variable "subnet_ids" {
  description = "Subnets donde se crean las instancias — resueltas por el engine"
  type        = list(string)
}

variable "os_type" {
  description = "Tipo de SO: linux o windows"
  type        = string
  default     = "linux"

  validation {
    condition     = contains(["linux", "windows"], var.os_type)
    error_message = "os_type debe ser linux o windows"
  }
}

variable "ami_id" {
  description = "ID de la AMI. null = ultima AMI segun os_type"
  type        = string
  default     = null
}

variable "instance_type" {
  description = "Tipo de instancia EC2"
  type        = string
  default     = "t3.micro"
}

variable "eni_id" {
  description = "ID del ENI a usar. null = sin ENI (IP dinámica)"
  type        = string
  default     = null
}

variable "key_name" {
  description = "Nombre del Key Pair para SSH/RDP. null = sin key pair"
  type        = string
  default     = null
}

variable "enable_ssm" {
  description = "Habilitar acceso via SSM Session Manager"
  type        = bool
  default     = false
}

variable "enable_rdp" {
  description = "Habilitar acceso RDP. Solo para Windows"
  type        = bool
  default     = false
}

variable "root_volume_size" {
  description = "Tamaño del volumen root en GB"
  type        = number
  default     = 20
}

variable "root_volume_type" {
  description = "Tipo del volumen root"
  type        = string
  default     = "gp3"
}

variable "root_volume_encrypted" {
  description = "Encriptar volumen root"
  type        = bool
  default     = true
}

variable "ebs_volumes" {
  description = "Volúmenes EBS adicionales"
  type = list(object({
    device_name = string
    size        = optional(number, 20)
    type        = optional(string, "gp3")
    encrypted   = optional(bool, true)
  }))
  default = []
}

variable "user_data_script" {
  description = "Nombre del script en scripts/userdata/. Ej: ecs-agent.sh. null = sin script predefinido"
  type        = string
  default     = null
}

variable "user_data_vars" {
  description = "Variables a inyectar en el script via templatefile(). Solo si user_data_script != null"
  type        = map(string)
  default     = {}
}

variable "user_data" {
  description = "Script de user data inline. Se concatena después de user_data_script si ambos existen"
  type        = string
  default     = null
}

variable "create_asg" {
  description = "true = crea un ASG, false = instancia standalone"
  type        = bool
  default     = false
}

variable "asg_min_size" {
  description = "Mínimo de instancias en el ASG"
  type        = number
  default     = 1
}

variable "asg_max_size" {
  description = "Máximo de instancias en el ASG"
  type        = number
  default     = 2
}

variable "asg_desired_size" {
  description = "Número deseado de instancias en el ASG"
  type        = number
  default     = 1
}

variable "on_demand_base_capacity" {
  description = "Número base de instancias On-Demand en el ASG"
  type        = number
  default     = 1
}

variable "on_demand_percentage" {
  description = "Porcentaje de instancias On-Demand sobre la base"
  type        = number
  default     = 100
}

variable "spot_instance_pools" {
  description = "Número de pools de Spot instances"
  type        = number
  default     = 2
}

variable "additional_instance_types" {
  description = "Tipos de instancia adicionales para mixed instances policy"
  type        = list(string)
  default     = []
}

variable "additional_sg_ids" {
  description = "IDs de Security Groups adicionales"
  type        = list(string)
  default     = []
}

variable "ingress_rules" {
  description = "Reglas de ingress adicionales para el SG"
  type = list(object({
    from_port   = number
    to_port     = number
    protocol    = string
    cidr        = optional(string, "10.0.0.0/8")
    description = optional(string, "")
  }))
  default = []
}

variable "ecs_cluster_name" {
  description = "Nombre completo del cluster ECS donde registrar la instancia. Resuelto por el engine desde el nombre corto del config. null = sin integración ECS"
  type        = string
  default     = null
}

variable "secrets" {
  description = "Lista de nombres de secrets que esta instancia puede leer. Ej: ['db-credentials', 'ssh-keys']"
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Tags adicionales"
  type        = map(string)
  default     = {}
}
