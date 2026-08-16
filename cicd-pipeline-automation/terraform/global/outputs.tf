output "ecr_repository_url" { value = module.ecr.repository_url }
output "github_deploy_role_arn" {
  description = "Set this as the AWS_DEPLOY_ROLE_ARN secret in the GitHub repo"
  value       = aws_iam_role.github_deploy.arn
}
