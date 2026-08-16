module "ecr" {
  source = "../modules/ecr"

  project_name    = var.project_name
  repository_name = var.ecr_repository_name
}
