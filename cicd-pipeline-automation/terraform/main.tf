# Root module — provisions one environment (staging or production) of
# the app: VPC, ALB, and ECS Fargate service. Apply once per environment
# with -var-file=environments/<env>.tfvars. Shared account-level
# resources (ECR repo, GitHub OIDC deploy role) live in terraform/global
# and are applied once, not per environment.

module "vpc" {
  source = "./modules/vpc"

  project_name       = var.project_name
  environment        = var.environment
  vpc_cidr           = var.vpc_cidr
  availability_zones = var.availability_zones
}

module "alb" {
  source = "./modules/alb"

  project_name      = var.project_name
  environment       = var.environment
  vpc_id            = module.vpc.vpc_id
  public_subnet_ids = module.vpc.public_subnet_ids
  container_port    = var.container_port
}

module "ecs" {
  source = "./modules/ecs"

  project_name          = var.project_name
  environment           = var.environment
  service_name          = "widget-inventory-api-${var.environment}"
  vpc_id                = module.vpc.vpc_id
  private_subnet_ids    = module.vpc.private_subnet_ids
  alb_security_group_id = module.alb.alb_security_group_id
  target_group_arn      = module.alb.target_group_arn
  container_name        = "widget-inventory-api"
  container_image       = var.container_image
  container_port        = var.container_port
  task_cpu              = var.task_cpu
  task_memory           = var.task_memory
  desired_count         = var.desired_count
}
