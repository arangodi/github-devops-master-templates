variable "environment_vars" {
  description = "Variables de entorno para el contenedor principal"
  type        = map(string)
  default     = {}
}

variable "name" {
  description = "Nombre del servicio"
  type        = string
}

variable "project_name" {
  description = "Nombre del proyecto"
  type        = string
}

variable "cluster_name" {
  description = "Nombre del cluster ECS"
  type        = string
}

variable "vpc_id" {
  description = "ID de la VPC"
  type        = string
}

variable "subnet_ids" {
  description = "Subnets EC2 donde corren las tareas"
  type        = list(string)
}

variable "internal_sg_id" {
  description = "SG interno del cluster para comunicacion entre contenedores"
  type        = string
}

variable "cpu" {
  description = "CPU units de la task definition"
  type        = number
  default     = 256
}

variable "memory" {
  description = "Memoria de la task definition (ej: 0.5GB, 1GB)"
  type        = string
  default     = "0.5GB"
}

variable "image_repo_uri" {
  description = "URI del repositorio de imagen"
  type        = string
}

variable "image_version" {
  description = "Version de la imagen a desplegar"
  type        = string
  default     = "latest"
}

variable "container_port" {
  description = "Puerto del contenedor"
  type        = number
  default     = 8080
}

variable "execution_role_arn" {
  description = "ARN del execution role de ECS"
  type        = string
}


variable "enable_container_health_check" {
  description = "Deshabilitar health check a nivel de contenedor"
  type        = bool
  default     = true
}

variable "health_check_path" {
  description = "Path del health check"
  type        = string
  default     = "/"
}

variable "desired_count" {
  description = "Numero de tareas deseadas"
  type        = number
  default     = 1
}

variable "health_check_grace_period" {
  description = "Segundos de gracia antes del health check del servicio"
  type        = number
  default     = 60
}

variable "elb_listener_arn" {
  description = "ARN del listener del ELB. null = sin ELB"
  type        = string
  default     = null
}

variable "elb_sg_id" {
  description = "SG del ELB para permitir trafico al contenedor. null = sin LB"
  type        = string
  default     = null
}

variable "base_path" {
  description = "Path base para la regla del listener"
  type        = string
  default     = "/"
}

variable "listener_priority" {
  description = "Prioridad de la regla en el listener"
  type        = number
  default     = 1
}

variable "namespace_id" {
  description = "ID del namespace de Service Discovery. null = sin service discovery"
  type        = string
  default     = null
}

variable "min_containers" {
  description = "Minimo de tareas para autoscaling"
  type        = number
  default     = 2
}

variable "max_containers" {
  description = "Maximo de tareas para autoscaling"
  type        = number
  default     = 4
}

variable "autoscaling_target_value" {
  description = "Porcentaje de CPU para autoscaling"
  type        = number
  default     = 80
}

variable "autoscaling_role_arn" {
  description = "ARN del rol de autoscaling"
  type        = string
}

variable "log_retention_days" {
  description = "Dias de retención de logs en CloudWatch"
  type        = number
  default     = 30
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

variable "task_role_create" {
  description = "true = el módulo crea el task role, false = usa task_role_arn existente"
  type        = bool
  default     = true
}

variable "task_role_arn" {
  description = "ARN del task role existente. Solo si task_role_create = false"
  type        = string
  default     = null
}

variable "task_managed_policies" {
  description = "Lista de ARNs de managed policies adicionales al task role"
  type        = list(string)
  default     = []
}

variable "s3_bucket_names" {
  description = "Lista de nombres de buckets S3 específicos. [] = acceso a todos los S3 de la cuenta"
  type        = list(string)
  default     = []
}

variable "s3_actions" {
  description = "Acciones S3 permitidas cuando se restringen buckets específicos"
  type        = list(string)
  default = [
    "s3:GetObject",
    "s3:ListBucket"
  ]
}

variable "account" {
  description = "Nombre de la cuenta AWS"
  type        = string
}

variable "secrets" {
  description = "Lista de nombres de secrets que este servicio puede leer. Ej: ['db-credentials', 'api-jwt-key']"
  type        = list(string)
  default     = []
}

variable "image_version_ssm_parameter" {
  description = "Nombre del parámetro SSM que contiene la versión de la imagen"
  type        = string
  default     = null
}

variable "use_placeholder_image" {
  description = "Si true, usa imagen placeholder hasta que exista una real en el ECR"
  type        = bool
  default     = false
}

variable "placeholder_image" {
  description = "Imagen placeholder a usar si use_placeholder_image es true"
  type        = string
  default     = "public.ecr.aws/nginx/nginx:alpine"
}

variable "nlb_arn" {
  description = "ARN del NLB. Si se especifica crea un target group TCP y listener en el puerto del container. No requiere listener_arn previo — el servicio crea su propio listener"
  type        = string
  default     = null
}

variable "secrets_arns" {
  description = "Mapa de ARNs completos de secrets {nombre: arn}. Usado para evitar wildcard en container definitions"
  type        = map(string)
  default     = {}
}

variable "launch_type" {
  description = "Tipo de lanzamiento: FARGATE o EC2. EC2 requiere instancias registradas en el cluster via ecs_cluster_name en el módulo EC2"
  type        = string
  default     = "FARGATE"

  validation {
    condition     = contains(["FARGATE", "EC2"], var.launch_type)
    error_message = "launch_type debe ser FARGATE o EC2"
  }
}

variable "efs_volumes" {
  description = "Volúmenes EFS a montar en el container. El engine los resuelve desde los outputs del storage"
  type = list(object({
    name            = string            
    file_system_id  = string           
    access_point_id = optional(string) 
    mount_path      = string           
    read_only       = optional(bool, false)
  }))
  default = []
}

variable "target_groups" {
  description = "Lista de target groups a crear — uno por container expuesto. Si está vacío usa elb_listener_arn (comportamiento actual con un solo TG)"
  type = list(object({
    container_name    = string
    container_port    = number
    path              = string
    listener_priority = number
    health_check_path = optional(string, "/")
    protocol          = optional(string, "HTTP")
  }))
  default = []
}

variable "containers" {
  description = "Containers adicionales en la misma task definition"
  type = list(object({
    name           = string
    image          = string
    cpu            = optional(number)
    memory         = optional(number)
    essential      = optional(bool, true)
    privileged     = optional(bool, false)
    container_port = optional(number)
    environment    = optional(map(string), {})
    mount_paths = optional(list(object({
      source_volume  = string
      container_path = string
      read_only      = optional(bool, false)
    })), [])
    depends_on_containers = optional(list(object({
      container_name = string
      condition      = string
    })), [])
    linux_parameters = optional(object({
      capabilities = optional(object({
        add  = optional(list(string), [])
        drop = optional(list(string), [])
      }))
    }), null)
  }))
  default = []
}