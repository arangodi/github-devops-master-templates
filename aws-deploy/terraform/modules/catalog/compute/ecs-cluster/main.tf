locals {
  safe_environment = replace(lower(var.environment), ".", "-")
  cluster_name     = lower("ecs-${var.project_name}-${var.name}")

  common_tags = merge({
    Name         = local.cluster_name
    project_name = var.project_name
    module       = "catalog/compute/ecs-cluster"
  }, var.tags)
}

#################################################
# ECS CLUSTER
#################################################
resource "aws_ecs_cluster" "this" {
  name = local.cluster_name

  setting {
    name  = "containerInsights"
    value = var.is_production ? "enabled" : "disabled"
  }

  tags = local.common_tags
}

resource "aws_ecs_cluster_capacity_providers" "this" {
  cluster_name       = aws_ecs_cluster.this.name
  capacity_providers = ["FARGATE", "FARGATE_SPOT"]

  default_capacity_provider_strategy {
    capacity_provider = "FARGATE"
    weight            = var.is_production ? 1 : 0
    base              = 1
  }

  default_capacity_provider_strategy {
    capacity_provider = "FARGATE_SPOT"
    weight            = var.is_production ? 0 : 1
  }
}

#################################################
# SECURITY GROUP INTERNO DEL CLUSTER
#################################################
resource "aws_security_group" "internal" {
  name        = "secg-${var.project_name}-container-internal"
  description = "SG interno para comunicacion entre contenedores ${var.project_name}"
  vpc_id      = var.vpc_id

  tags = merge(local.common_tags, {
    Name = "secg-${var.project_name}-${var.name}-container-internal"
  })
}

resource "aws_vpc_security_group_ingress_rule" "internal" {
  security_group_id            = aws_security_group.internal.id
  referenced_security_group_id = aws_security_group.internal.id
  ip_protocol                  = "-1"
  description                  = "Comunicacion interna entre contenedores del cluster"
}

resource "aws_vpc_security_group_egress_rule" "internal" {
  security_group_id = aws_security_group.internal.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
  description       = "Todo el trafico saliente"
}

#################################################
# IAM — EXECUTION ROLE
#################################################
resource "aws_iam_role" "execution" {
  name = "iam-${var.project_name}-${var.name}-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = merge(local.common_tags, {
    Name = "iam-${var.project_name}-${var.name}-execution-role"
  })
}

resource "aws_iam_role_policy_attachment" "execution" {
  role       = aws_iam_role.execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

#################################################
# IAM — AUTOSCALING ROLE
#################################################
resource "aws_iam_role" "autoscaling" {
  name = "iam-${var.project_name}-${var.name}-autoscaling-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "application-autoscaling.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = merge(local.common_tags, {
    Name = "iam-${var.project_name}-${var.name}-autoscaling-role"
  })
}

resource "aws_iam_role_policy_attachment" "autoscaling" {
  role       = aws_iam_role.autoscaling.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceAutoscaleRole"
}