# ─────────────────────────────────────────────────────────────────────────────
# ECR MODULE — one repository, scan-on-push, and a lifecycle policy that
# keeps the pipeline from accumulating unbounded untagged images.
# ─────────────────────────────────────────────────────────────────────────────

resource "aws_ecr_repository" "main" {
  name                 = var.repository_name
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = { Name = "${var.project_name}-${var.repository_name}" }
}

resource "aws_ecr_lifecycle_policy" "main" {
  repository = aws_ecr_repository.main.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Expire untagged images after 7 days"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 7
        }
        action = { type = "expire" }
      },
      {
        rulePriority = 2
        description  = "Keep the last 20 tagged images"
        selection = {
          tagStatus      = "tagged"
          tagPatternList = ["*"]
          countType      = "imageCountMoreThan"
          countNumber    = 20
        }
        action = { type = "expire" }
      }
    ]
  })
}
