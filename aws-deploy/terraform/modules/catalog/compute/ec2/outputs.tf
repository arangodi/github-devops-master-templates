output "instance_id" {
  description = "ID de la instancia EC2. null si es ASG"
  value       = var.create_asg ? null : try(aws_instance.this[0].id, null)
}

output "private_ip" {
  description = "IP privada de la instancia. null si es ASG"
  value       = var.create_asg ? null : try(aws_instance.this[0].private_ip, null)
}

output "asg_name" {
  description = "Nombre del ASG. null si es standalone"
  value       = var.create_asg ? aws_autoscaling_group.this[0].name : null
}

output "asg_arn" {
  description = "ARN del ASG. null si es standalone"
  value       = var.create_asg ? aws_autoscaling_group.this[0].arn : null
}

output "security_group_id" {
  description = "ID del SG de la instancia"
  value       = aws_security_group.this.id
}

output "iam_role_arn" {
  description = "ARN del IAM role de la instancia"
  value       = aws_iam_role.this.arn
}

output "launch_template_id" {
  description = "ID del Launch Template"
  value       = aws_launch_template.this.id
}

output "launch_template_version" {
  description = "Versión más reciente del Launch Template"
  value       = aws_launch_template.this.latest_version
}