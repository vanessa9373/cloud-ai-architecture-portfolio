variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name, used as a prefix for resource names"
  type        = string
  default     = "cicd-pipeline"
}

variable "ecr_repository_name" {
  description = "Name of the shared ECR repository used across staging and production"
  type        = string
  default     = "widget-inventory-api"
}

variable "github_org" {
  description = "GitHub org/user that owns the repository allowed to assume the deploy role"
  type        = string
  default     = "vanessa9373"
}

variable "github_repo" {
  description = "GitHub repository name allowed to assume the deploy role"
  type        = string
  default     = "cicd-pipeline-automation"
}
