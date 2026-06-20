output "secret_arn" {
  description = "ARN del secret"
  value       = local.secret_arn
}

output "secret_name" {
  description = "Nombre del secret en AWS"
  value       = var.create ? aws_secretsmanager_secret.this[0].name : null
}

output "secret_id" {
  description = "ID del secret"
  value       = var.create ? aws_secretsmanager_secret.this[0].id : null
}

output "rotation_enabled" {
  description = "Si la rotacion automatica esta habilitada"
  value       = var.create && var.enable_rotation
}

output "reader_role_arn" {
  description = "ARN del rol reader (si se creó con create_reader_role: true)"
  value       = var.create_reader_role ? aws_iam_role.reader[0].arn : null
}

output "reader_role_name" {
  description = "Nombre del rol reader (si se creó)"
  value       = var.create_reader_role ? aws_iam_role.reader[0].name : null
}

output "writer_role_arn" {
  description = "ARN del rol writer (si se creó con create_writer_role: true)"
  value       = var.create_writer_role ? aws_iam_role.writer[0].arn : null
}

output "writer_role_name" {
  description = "Nombre del rol writer (si se creó)"
  value       = var.create_writer_role ? aws_iam_role.writer[0].name : null
}
