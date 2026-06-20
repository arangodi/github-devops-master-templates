output "id" {
  description = "ID del topic SNS"
  value       = aws_sns_topic.this.id
}

output "arn" {
  description = "ARN del topic SNS"
  value       = aws_sns_topic.this.arn
}

output "name" {
  description = "Nombre del topic SNS"
  value       = aws_sns_topic.this.name
}
