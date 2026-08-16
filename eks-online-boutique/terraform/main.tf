terraform {
  required_version = ">= 1.6"
  required_providers {
    aws        = { source = "hashicorp/aws",        version = "~> 5.0" }
    kubernetes = { source = "hashicorp/kubernetes",  version = "~> 2.0" }
    helm       = { source = "hashicorp/helm",        version = "~> 2.0" }
  }
  backend "s3" {
    bucket         = "vanessa-terraform-state"
    key            = "eks-online-boutique/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-state-lock"
    encrypt        = true
  }
}

provider "aws" {
  region = var.aws_region
  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      Owner       = "Vanessa Awo"
      ManagedBy   = "Terraform"
    }
  }
}

data "aws_availability_zones" "available" { state = "available" }
data "aws_caller_identity" "current"      {}
data "aws_region" "current"               {}

# ─── VPC ──────────────────────────────────────────────────────────────────────
module "vpc" {
  source = "./modules/vpc"

  project_name         = var.project_name
  environment          = var.environment
  vpc_cidr             = var.vpc_cidr
  availability_zones   = slice(data.aws_availability_zones.available.names, 0, 3)
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  cluster_name         = local.cluster_name
}

# ─── EKS Cluster ──────────────────────────────────────────────────────────────
module "eks" {
  source = "./modules/eks"

  cluster_name       = local.cluster_name
  kubernetes_version = var.kubernetes_version
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
  node_instance_type = var.node_instance_type
  node_min_size      = var.node_min_size
  node_max_size      = var.node_max_size
  node_desired_size  = var.node_desired_size
  account_id         = data.aws_caller_identity.current.account_id
  region             = data.aws_region.current.name
}

# ─── ECR Repositories (one per microservice) ─────────────────────────────────
module "ecr" {
  source = "./modules/ecr"

  services    = local.microservices
  environment = var.environment
}

# ─── IRSA Roles (IAM Roles for Service Accounts) ─────────────────────────────
module "irsa" {
  source = "./modules/irsa"

  cluster_name    = local.cluster_name
  oidc_issuer_url = module.eks.cluster_oidc_issuer_url
  account_id      = data.aws_caller_identity.current.account_id
}

# ─── Locals ───────────────────────────────────────────────────────────────────
locals {
  cluster_name = "${var.project_name}-${var.environment}"
  microservices = [
    "frontend", "productcatalogservice", "cartservice", "checkoutservice",
    "paymentservice", "emailservice", "shippingservice", "currencyservice",
    "recommendationservice", "adservice", "loadgenerator"
  ]
}

# ─── Outputs ──────────────────────────────────────────────────────────────────
output "cluster_name"      { value = module.eks.cluster_name }
output "cluster_endpoint"  { value = module.eks.cluster_endpoint }
output "ecr_repo_urls"     { value = module.ecr.repository_urls }
output "kubeconfig_command" {
  value = "aws eks update-kubeconfig --name ${module.eks.cluster_name} --region ${var.aws_region}"
}
