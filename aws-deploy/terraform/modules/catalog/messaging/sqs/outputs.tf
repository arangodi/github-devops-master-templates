output "id" {
  description = "Identificador de la cola (en SQS equivale a la URL de la cola)"
  value       = aws_sqs_queue.this.id
}

output "arn" {
  description = "ARN de la cola SQS"
  value       = aws_sqs_queue.this.arn
}

output "name" {
  description = "Nombre de la cola SQS"
  value       = aws_sqs_queue.this.name
}
