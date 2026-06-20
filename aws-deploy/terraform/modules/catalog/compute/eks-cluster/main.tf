data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

data "aws_eks_cluster_versions" "available" {}

locals {
  safe_environment = replace(lower(var.environment), ".", "-")
  cluster_name     = lower("eks-${var.project_name}-${var.name}")

  common_tags = merge({
    Name         = local.cluster_name
    project_name = var.project_name
    module       = "catalog/compute/eks-cluster"
  }, var.tags)
}

#################################################
# IAM — CLUSTER ROLE
#################################################
resource "aws_iam_role" "cluster" {
  name = "iam-${var.project_name}-eks-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "eks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "cluster_policy" {
  role       = aws_iam_role.cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

#################################################
# IAM — NODE ROLE
#################################################
resource "aws_iam_role" "node" {
  name = "iam-${var.project_name}-eks-node-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "node_worker" {
  role       = aws_iam_role.node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "node_cni" {
  role       = aws_iam_role.node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "node_ecr" {
  role       = aws_iam_role.node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

#################################################
# IAM — FARGATE ROLE
#################################################
resource "aws_iam_role" "fargate" {
  count = length(var.fargate_profiles) > 0 ? 1 : 0

  name = "iam-${var.project_name}-eks-fargate-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "eks-fargate-pods.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "fargate" {
  count = length(var.fargate_profiles) > 0 ? 1 : 0

  role       = aws_iam_role.fargate[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSFargatePodExecutionRolePolicy"
}

#################################################
# IAM — AWS LOAD BALANCER CONTROLLER
#################################################
resource "aws_iam_policy" "lbc" {
  count = var.enable_load_balancer_controller ? 1 : 0

  name        = "iam-${var.project_name}-eks-lbc-policy"
  description = "Politica para AWS Load Balancer Controller en ${local.cluster_name}"
  policy      = file("${path.module}/policies/lbc_policy.json")

  tags = local.common_tags
}

resource "aws_iam_role" "lbc" {
  count = var.enable_load_balancer_controller && var.enable_irsa ? 1 : 0

  name = "iam-${var.project_name}-eks-lbc-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = {
        Federated = aws_iam_openid_connect_provider.cluster[0].arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${replace(aws_eks_cluster.this.identity[0].oidc[0].issuer, "https://", "")}:sub" = "system:serviceaccount:kube-system:aws-load-balancer-controller"
          "${replace(aws_eks_cluster.this.identity[0].oidc[0].issuer, "https://", "")}:aud" = "sts.amazonaws.com"
        }
      }
    }]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "lbc" {
  count = var.enable_load_balancer_controller && var.enable_irsa ? 1 : 0

  role       = aws_iam_role.lbc[0].name
  policy_arn = aws_iam_policy.lbc[0].arn
}

#################################################
# SECURITY GROUP DEL CLUSTER
#################################################
resource "aws_security_group" "cluster" {
  name        = "secg-${var.project_name}-eks-cluster"
  description = "SG del cluster EKS ${var.project_name}"
  vpc_id      = var.vpc_id

  tags = merge(local.common_tags, {
    Name = "secg-${var.project_name}-eks-cluster"
  })
}

resource "aws_vpc_security_group_ingress_rule" "cluster" {
  security_group_id            = aws_security_group.cluster.id
  referenced_security_group_id = aws_security_group.cluster.id
  ip_protocol                  = "-1"
  description                  = "Comunicacion interna del cluster"
}

resource "aws_vpc_security_group_ingress_rule" "cluster_https" {
  security_group_id = aws_security_group.cluster.id
  cidr_ipv4         = "10.0.0.0/8"
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
  description       = "HTTPS acceso al cluster desde red interna"
}

resource "aws_vpc_security_group_egress_rule" "cluster" {
  security_group_id = aws_security_group.cluster.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
  description       = "Todo el trafico saliente"
}

#################################################
# EKS CLUSTER
#################################################
resource "aws_eks_cluster" "this" {
  name     = local.cluster_name
  role_arn = aws_iam_role.cluster.arn
  version  = var.kubernetes_version

  access_config {
    authentication_mode                         = var.authentication_mode
    bootstrap_cluster_creator_admin_permissions = true
  }

  vpc_config {
    subnet_ids              = var.subnet_ids
    security_group_ids      = [aws_security_group.cluster.id]
    endpoint_private_access = true
    endpoint_public_access  = false
  }

  tags = local.common_tags

  depends_on = [
    aws_iam_role_policy_attachment.cluster_policy
  ]
}

#################################################
# IRSA — OIDC PROVIDER
#################################################
data "tls_certificate" "cluster" {
  count = var.enable_irsa ? 1 : 0
  url   = aws_eks_cluster.this.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "cluster" {
  count = var.enable_irsa ? 1 : 0

  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.cluster[0].certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.this.identity[0].oidc[0].issuer

  tags = local.common_tags
}

#################################################
# MANAGED NODE GROUPS
#################################################
resource "aws_eks_node_group" "this" {
  for_each = { for ng in var.node_groups : ng.name => ng }

  cluster_name    = aws_eks_cluster.this.name
  version         = aws_eks_cluster.this.version
  node_group_name = lower("${each.value.name}")
  node_role_arn   = aws_iam_role.node.arn
  subnet_ids      = var.subnet_ids
  instance_types  = try(each.value.instance_types, ["t3.medium"])
  disk_size       = try(each.value.disk_size, 20)
  capacity_type   = try(each.value.capacity_type, "ON_DEMAND")

  scaling_config {
    min_size     = try(each.value.min_size, 1)
    max_size     = try(each.value.max_size, 3)
    desired_size = try(each.value.desired_size, 2)
  }

  labels = try(each.value.labels, {})

  dynamic "taint" {
    for_each = try(each.value.taints, [])
    content {
      key    = taint.value.key
      value  = taint.value.value
      effect = taint.value.effect
    }
  }

  tags = merge(local.common_tags, {
    Name = lower("eks-${var.project_name}-${each.value.name}-ng")
  })

  depends_on = [
    aws_iam_role_policy_attachment.node_worker,
    aws_iam_role_policy_attachment.node_cni,
    aws_iam_role_policy_attachment.node_ecr
  ]
}

#################################################
# FARGATE PROFILES
#################################################
resource "aws_eks_fargate_profile" "this" {
  for_each = { for fp in var.fargate_profiles : fp.name => fp }

  cluster_name           = aws_eks_cluster.this.name
  fargate_profile_name   = lower("${each.value.name}-fargate")
  pod_execution_role_arn = aws_iam_role.fargate[0].arn
  subnet_ids             = var.subnet_ids

  selector {
    namespace = try(each.value.namespace, "default")
    labels    = try(each.value.labels, {})
  }

  tags = merge(local.common_tags, {
    Name = lower("${var.project_name}-${each.value.name}-fargate")
  })

  depends_on = [aws_iam_role_policy_attachment.fargate]
}

#################################################
# ADD-ONS
#################################################
resource "aws_eks_addon" "coredns" {
  cluster_name  = aws_eks_cluster.this.name
  addon_name    = "coredns"
  addon_version = var.addon_coredns_version

  tags = local.common_tags

  depends_on = [aws_eks_node_group.this]
}

resource "aws_eks_addon" "kube_proxy" {
  cluster_name  = aws_eks_cluster.this.name
  addon_name    = "kube-proxy"
  addon_version = var.addon_kube_proxy_version

  tags = local.common_tags

  depends_on = [aws_eks_node_group.this]
}

resource "aws_eks_addon" "vpc_cni" {
  cluster_name  = aws_eks_cluster.this.name
  addon_name    = "vpc-cni"
  addon_version = var.addon_vpc_cni_version

  tags = local.common_tags

  depends_on = [aws_eks_node_group.this]
}

#################################################
# ACCESS ENTRIES
#################################################
resource "aws_eks_access_entry" "this" {
  for_each = { for e in var.access_entries : e.principal_arn => e }

  cluster_name      = aws_eks_cluster.this.name
  principal_arn     = each.value.principal_arn
  type              = try(each.value.type, "STANDARD")
  kubernetes_groups = try(each.value.kubernetes_groups, [])

  tags = local.common_tags

  depends_on = [aws_eks_cluster.this]
}

resource "aws_eks_access_policy_association" "this" {
  for_each = {
    for pair in flatten([
      for e in var.access_entries : [
        for p in try(e.policy_associations, []) : {
          key           = "${e.principal_arn}|${p.policy_arn}"
          principal_arn = e.principal_arn
          policy_arn    = p.policy_arn
          access_scope  = try(p.access_scope, "cluster")
          namespaces    = try(p.namespaces, [])
        }
      ]
    ]) : pair.key => pair
  }

  cluster_name  = aws_eks_cluster.this.name
  principal_arn = each.value.principal_arn
  policy_arn    = each.value.policy_arn

  access_scope {
    type       = each.value.access_scope
    namespaces = each.value.access_scope == "namespace" ? each.value.namespaces : []
  }

  depends_on = [aws_eks_access_entry.this]
}

#################################################
# PERMISOS PARA SECRETS MANAGER (Node Role)
#################################################
resource "aws_iam_role_policy" "secrets_access" {
  count = length(var.secrets) > 0 ? 1 : 0

  name = "${var.project_name}-${var.name}-secrets"
  role = aws_iam_role.node.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = [
          for secret_name in var.secrets :
          "arn:aws:secretsmanager:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:secret:${lower(var.project_name)}/${local.safe_environment}/${secret_name}-*"
        ]
      }
    ]
  })

  depends_on = [aws_iam_role.node]
}