output "target_group_arn" {
  description = "ARN del target group que apunta al ALB"
  value       = aws_lb_target_group.this.arn
}

output "listener_arn" {
  description = "ARN del listener del NLB hacia el ALB"
  value       = aws_lb_listener.this.arn
}
