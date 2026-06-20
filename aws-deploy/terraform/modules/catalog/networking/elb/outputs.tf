output "arn" {
  description = "ARN del ELB"
  value       = var.create ? aws_lb.this[0].arn : var.existing_arn
}

output "dns_name" {
  description = "DNS name del ELB"
  value       = var.create ? aws_lb.this[0].dns_name : null
}

output "listener_arn" {
  description = "ARN del listener. null si es NLB sin target group"
  value = var.create ? (
    var.load_balancer_type == "application" ? aws_lb_listener.this[0].arn :
    length(aws_lb_listener.network) > 0 ? aws_lb_listener.network[0].arn :
    null
  ) : var.existing_listener_arn
}

output "security_group_id" {
  description = "ID del SG del ELB. null si es NLB"
  value = var.create ? (
    var.load_balancer_type == "application" ? aws_security_group.this[0].id :
    null
  ) : var.existing_sg_id
}

output "zone_id" {
  description = "Zone ID del ELB para Route53"
  value       = var.create ? aws_lb.this[0].zone_id : null
}