output "service_name" {
  description = "Nombre del servicio ECS"
  value       = aws_ecs_service.this.name
}

output "service_arn" {
  description = "ARN del servicio ECS"
  value       = aws_ecs_service.this.id
}

output "task_definition_arn" {
  description = "ARN de la task definition"
  value       = aws_ecs_task_definition.this.arn
}

output "container_sg_id" {
  description = "ID del SG del contenedor"
  value       = aws_security_group.container.id
}

output "target_group_arn" {
  description = "ARN del target group. null si no tiene ELB"
  value       = try(aws_lb_target_group.this[0].arn, null)
}

output "log_group_name" {
  description = "Nombre del log group en CloudWatch"
  value       = aws_cloudwatch_log_group.this.name
}

output "task_role_arn" {
  description = "ARN del task role del servicio"
  value       = var.task_role_arn != null ? var.task_role_arn : aws_iam_role.task[0].arn
}