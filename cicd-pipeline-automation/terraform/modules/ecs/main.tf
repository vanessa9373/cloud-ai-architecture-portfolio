# ─────────────────────────────────────────────────────────────────────────────
# ECS MODULE — Fargate cluster, task definition, and service.
#
# Automatic rollback: the service's deployment_circuit_breaker watches
# each rolling deployment, and if new tasks fail to reach a healthy
# steady state, ECS itself stops the rollout and redeploys the previous
# task definition — no pipeline code required. scripts/rollback.sh in
# the GitHub Actions workflow is the explicit, scriptable fallback on
# top of this for the app-level smoke test.
# ─────────────────────────────────────────────────────────────────────────────

resource "aws_ecs_cluster" "main" {
  name = "${var.project_name}-cluster-${var.environment}"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = { Name = "${var.project_name}-cluster-${var.environment}" }
}

resource "aws_cloudwatch_log_group" "app" {
  name              = "/ecs/${var.service_name}"
  retention_in_days = 30
}

# ─── TASK EXECUTION ROLE (pulls image from ECR, ships logs to CloudWatch) ────
resource "aws_iam_role" "execution" {
  name = "${var.service_name}-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "execution" {
  role       = aws_iam_role.execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# ─── TASK ROLE (what the running app itself is allowed to call) ─────────────
resource "aws_iam_role" "task" {
  name = "${var.service_name}-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
    }]
  })
}

# ─── TASK DEFINITION ──────────────────────────────────────────────────────────
resource "aws_ecs_task_definition" "app" {
  family                   = var.service_name
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.task_cpu
  memory                   = var.task_memory
  execution_role_arn       = aws_iam_role.execution.arn
  task_role_arn            = aws_iam_role.task.arn

  container_definitions = jsonencode([
    {
      name      = var.container_name
      image     = var.container_image
      essential = true
      portMappings = [{
        containerPort = var.container_port
        protocol      = "tcp"
      }]
      environment = [
        { name = "APP_ENV", value = var.environment },
        { name = "PORT", value = tostring(var.container_port) },
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.app.name
          "awslogs-region"        = data.aws_region.current.name
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])

  # CI/CD deploy workflow overwrites the container image on every
  # release; Terraform shouldn't fight it between applies.
  lifecycle {
    ignore_changes = [container_definitions]
  }
}

data "aws_region" "current" {}

# ─── SERVICE SECURITY GROUP (only the ALB may reach the tasks) ──────────────
resource "aws_security_group" "service" {
  name_prefix = "${var.service_name}-"
  vpc_id      = var.vpc_id

  ingress {
    description     = "From ALB"
    from_port       = var.container_port
    to_port         = var.container_port
    protocol        = "tcp"
    security_groups = [var.alb_security_group_id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  lifecycle {
    create_before_destroy = true
  }

  tags = { Name = "${var.service_name}-sg" }
}

# ─── SERVICE ──────────────────────────────────────────────────────────────────
resource "aws_ecs_service" "app" {
  name            = var.service_name
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.app.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets         = var.private_subnet_ids
    security_groups = [aws_security_group.service.id]
  }

  load_balancer {
    target_group_arn = var.target_group_arn
    container_name   = var.container_name
    container_port   = var.container_port
  }

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  deployment_minimum_healthy_percent = 100
  deployment_maximum_percent         = 200

  # The deploy workflow updates the task definition revision directly;
  # Terraform shouldn't revert those releases on the next apply.
  lifecycle {
    ignore_changes = [task_definition]
  }
}
