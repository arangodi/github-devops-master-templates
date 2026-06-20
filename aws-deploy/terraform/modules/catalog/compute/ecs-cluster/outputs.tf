output "arn" {
  description = "ARN del cluster ECS"
  value       = aws_ecs_cluster.this.arn
}

output "name" {
  description = "Nombre del cluster ECS"
  value       = aws_ecs_cluster.this.name
}

output "id" {
  description = "ID del cluster ECS"
  value       = aws_ecs_cluster.this.id
}

output "internal_sg_id" {
  description = "ID del SG interno del cluster"
  value       = aws_security_group.internal.id
}

output "execution_role_arn" {
  description = "ARN del execution role"
  value       = aws_iam_role.execution.arn
}

output "autoscaling_role_arn" {
  description = "ARN del autoscaling role"
  value       = aws_iam_role.autoscaling.arn
}