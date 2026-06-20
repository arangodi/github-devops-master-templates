output "cluster_name" {
  description = "Nombre del cluster EKS"
  value       = aws_eks_cluster.this.name
}

output "cluster_arn" {
  description = "ARN del cluster EKS"
  value       = aws_eks_cluster.this.arn
}

output "cluster_endpoint" {
  description = "Endpoint del cluster EKS"
  value       = aws_eks_cluster.this.endpoint
}

output "cluster_ca" {
  description = "Certificate Authority del cluster"
  value       = aws_eks_cluster.this.certificate_authority[0].data
}

output "cluster_sg_id" {
  description = "ID del SG del cluster"
  value       = aws_security_group.cluster.id
}

output "node_role_arn" {
  description = "ARN del rol de los nodos"
  value       = aws_iam_role.node.arn
}

output "oidc_provider_arn" {
  description = "ARN del OIDC provider para IRSA"
  value       = var.enable_irsa ? aws_iam_openid_connect_provider.cluster[0].arn : null
}

output "oidc_provider_url" {
  description = "URL del OIDC provider para IRSA"
  value       = var.enable_irsa ? aws_iam_openid_connect_provider.cluster[0].url : null
}

output "lbc_role_arn" {
  description = "ARN del IAM Role para AWS Load Balancer Controller"
  value       = var.enable_load_balancer_controller && var.enable_irsa ? aws_iam_role.lbc[0].arn : null
}