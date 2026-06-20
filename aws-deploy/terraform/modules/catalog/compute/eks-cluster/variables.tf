variable "name" {
  description = "Nombre del cluster EKS"
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

variable "kubernetes_version" {
  description = "Version de Kubernetes. null = usa la ultima version disponible"
  type        = string
  default     = null
}

variable "vpc_id" {
  description = "ID de la VPC"
  type        = string
}

variable "subnet_ids" {
  description = "Subnets EC2 para los nodos del cluster"
  type        = list(string)
}

variable "enable_irsa" {
  description = "Habilitar IRSA (IAM Roles for Service Accounts)"
  type        = bool
  default     = false
}

variable "node_groups" {
  description = "Managed Node Groups del cluster"
  type = list(object({
    name           = string
    instance_types = optional(list(string), ["t3.medium"])
    min_size       = optional(number, 1)
    max_size       = optional(number, 3)
    desired_size   = optional(number, 2)
    disk_size      = optional(number, 20)
    capacity_type  = optional(string, "ON_DEMAND")
    labels         = optional(map(string), {})
    taints = optional(list(object({
      key    = string
      value  = string
      effect = string
    })), [])
  }))
  default = []
}

variable "fargate_profiles" {
  description = "Fargate Profiles del cluster"
  type = list(object({
    name      = string
    namespace = optional(string, "default")
    labels    = optional(map(string), {})
  }))
  default = []
}

variable "addon_coredns_version" {
  description = "Version del add-on CoreDNS. null = version por defecto"
  type        = string
  default     = null
}

variable "addon_kube_proxy_version" {
  description = "Version del add-on kube-proxy. null = version por defecto"
  type        = string
  default     = null
}

variable "addon_vpc_cni_version" {
  description = "Version del add-on vpc-cni. null = version por defecto"
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags adicionales"
  type        = map(string)
  default     = {}
}

variable "authentication_mode" {
  description = "Modo de autenticacion del cluster: CONFIG_MAP, API o API_AND_CONFIG_MAP"
  type        = string
  default     = "API_AND_CONFIG_MAP"

  validation {
    condition     = contains(["CONFIG_MAP", "API", "API_AND_CONFIG_MAP"], var.authentication_mode)
    error_message = "authentication_mode debe ser CONFIG_MAP, API o API_AND_CONFIG_MAP"
  }
}

variable "access_entries" {
  description = "Lista de access entries para el cluster EKS"
  type = list(object({
    principal_arn     = string
    type              = optional(string, "STANDARD")
    kubernetes_groups = optional(list(string), [])
    policy_associations = optional(list(object({
      policy_arn   = string
      access_scope = optional(string, "cluster")
      namespaces   = optional(list(string), [])
    })), [])
  }))
  default = []
}

variable "enable_load_balancer_controller" {
  description = "Crear IAM Role y Policy para AWS Load Balancer Controller. Requiere enable_irsa: true"
  type        = bool
  default     = false
}

variable "secrets" {
  description = "Lista de nombres de secrets que este servicio puede leer. Ej: ['db-credentials', 'api-jwt-key']"
  type        = list(string)
  default     = []
}