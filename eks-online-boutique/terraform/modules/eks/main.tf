# EKS Module — creates the Kubernetes cluster and managed node group
#
# KEY CONCEPTS:
# - Managed Node Group: AWS manages the EC2 instances (patching, replacement)
# - OIDC Provider: enables IRSA (Pods can assume IAM roles)
# - Cluster Autoscaler vs Karpenter: we use Karpenter (faster, cheaper)

variable "cluster_name"       {}
variable "kubernetes_version" {}
variable "vpc_id"             {}
variable "private_subnet_ids" { type = list(string) }
variable "node_instance_type" {}
variable "node_min_size"      { type = number }
variable "node_max_size"      { type = number }
variable "node_desired_size"  { type = number }
variable "account_id"         {}
variable "region"             {}

# ─── IAM Role for EKS Control Plane ──────────────────────────────────────────
resource "aws_iam_role" "cluster" {
  name = "${var.cluster_name}-cluster-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "eks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "cluster_AmazonEKSClusterPolicy" {
  role       = aws_iam_role.cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

# ─── EKS Cluster ─────────────────────────────────────────────────────────────
resource "aws_eks_cluster" "main" {
  name     = var.cluster_name
  role_arn = aws_iam_role.cluster.arn
  version  = var.kubernetes_version

  vpc_config {
    subnet_ids              = var.private_subnet_ids
    endpoint_private_access = true
    endpoint_public_access  = true   # Set to false in production
  }

  # Enable CloudWatch logging for control plane
  enabled_cluster_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  depends_on = [aws_iam_role_policy_attachment.cluster_AmazonEKSClusterPolicy]
  tags = { Name = var.cluster_name }
}

# ─── OIDC Provider (required for IRSA) ───────────────────────────────────────
# This allows Kubernetes service accounts to assume IAM roles
data "tls_certificate" "cluster" {
  url = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "cluster" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.cluster.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

# ─── IAM Role for Node Group ──────────────────────────────────────────────────
resource "aws_iam_role" "nodes" {
  name = "${var.cluster_name}-nodes-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "nodes_AmazonEKSWorkerNodePolicy" {
  role       = aws_iam_role.nodes.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "nodes_AmazonEKS_CNI_Policy" {
  role       = aws_iam_role.nodes.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "nodes_AmazonEC2ContainerRegistryReadOnly" {
  role       = aws_iam_role.nodes.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

# ─── Managed Node Group ───────────────────────────────────────────────────────
resource "aws_eks_node_group" "main" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${var.cluster_name}-nodes"
  node_role_arn   = aws_iam_role.nodes.arn
  subnet_ids      = var.private_subnet_ids

  instance_types = [var.node_instance_type]

  scaling_config {
    min_size     = var.node_min_size
    max_size     = var.node_max_size
    desired_size = var.node_desired_size
  }

  update_config { max_unavailable = 1 }

  labels = { role = "general" }

  depends_on = [
    aws_iam_role_policy_attachment.nodes_AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.nodes_AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.nodes_AmazonEC2ContainerRegistryReadOnly,
  ]
  tags = { Name = "${var.cluster_name}-nodes" }
}

# ─── Outputs ──────────────────────────────────────────────────────────────────
output "cluster_name"            { value = aws_eks_cluster.main.name }
output "cluster_endpoint"        { value = aws_eks_cluster.main.endpoint }
output "cluster_ca_certificate"  { value = aws_eks_cluster.main.certificate_authority[0].data }
output "cluster_oidc_issuer_url" { value = aws_eks_cluster.main.identity[0].oidc[0].issuer }
output "oidc_provider_arn"       { value = aws_iam_openid_connect_provider.cluster.arn }
