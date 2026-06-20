locals {
  common_tags = merge({
    Name         = lower("${var.project_name}-${var.name}-alb-tg")
    project_name = var.project_name
    module       = "catalog/networking/nlb-alb-attachment"
  }, var.tags)
}

#################################################
# TARGET GROUP — tipo ALB, protocolo TCP
#################################################
resource "aws_lb_target_group" "this" {
  name        = lower("${var.project_name}-${var.name}-alb-tg")
  port        = var.port
  protocol    = "TCP"
  target_type = "alb"
  vpc_id      = var.vpc_id

  health_check {
    protocol            = "HTTP"
    path                = var.health_check_path
    interval            = 30
    healthy_threshold   = 2
    unhealthy_threshold = 2
    matcher             = "200-499"
  }

  tags = local.common_tags
}

#################################################
# ATTACHMENT — registra el ALB como target
#################################################
resource "aws_lb_target_group_attachment" "this" {
  target_group_arn = aws_lb_target_group.this.arn
  target_id        = var.alb_arn
  port             = var.port
}

#################################################
# LISTENER DEL NLB — reenvía hacia el ALB
#################################################
resource "aws_lb_listener" "this" {
  load_balancer_arn = var.nlb_arn
  port               = var.port
  protocol           = var.certificate_arn != null ? "TLS" : "TCP"
  certificate_arn    = var.certificate_arn != null ? var.certificate_arn : null
  ssl_policy         = var.certificate_arn != null ? var.ssl_policy : null

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this.arn
  }

  tags = local.common_tags
}
