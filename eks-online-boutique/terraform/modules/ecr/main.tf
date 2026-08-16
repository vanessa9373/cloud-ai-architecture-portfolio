# ECR Module — creates one private container registry per microservice
#
# ECR = Elastic Container Registry
# Like Docker Hub, but private and inside AWS
# Each microservice needs its own repo

variable "services"    { type = list(string) }
variable "environment" {}

resource "aws_ecr_repository" "services" {
  for_each = toset(var.services)  # Creates one repo per service name

  name                 = "${each.key}"
  image_tag_mutability = "MUTABLE"   # Allow overwriting tags (e.g., "latest")

  # Scan images for CVEs when pushed
  image_scanning_configuration {
    scan_on_push = true
  }

  # Encrypt images at rest
  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = { Name = each.key, Environment = var.environment }
}

# Lifecycle policy: keep only the 10 most recent images per repo
# Prevents storage costs from accumulating over time
resource "aws_ecr_lifecycle_policy" "services" {
  for_each   = aws_ecr_repository.services
  repository = each.value.name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep only 10 most recent images"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 10
      }
      action = { type = "expire" }
    }]
  })
}

output "repository_urls" {
  value = { for k, v in aws_ecr_repository.services : k => v.repository_url }
}
