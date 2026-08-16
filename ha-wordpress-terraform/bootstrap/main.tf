# ─── BOOTSTRAP — Run this ONCE before anything else ───────────────────────────
# This creates the S3 bucket and DynamoDB table for Terraform remote state.
# After running this, the main ha-wordpress config can use the S3 backend.
#
# HOW TO RUN:
#   cd bootstrap
#   terraform init
#   terraform apply
# ──────────────────────────────────────────────────────────────────────────────

terraform {
  required_version = ">= 1.6"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  # Bootstrap uses LOCAL backend — it cannot use S3 (S3 doesn't exist yet!)
}

provider "aws" {
  region = "us-east-1"
}

# ─── S3 Bucket for Terraform State ────────────────────────────────────────────
# This stores the tfstate file — Terraform's record of what it has created.
resource "aws_s3_bucket" "terraform_state" {
  bucket = "vanessa-terraform-state"

  lifecycle {
    prevent_destroy = true  # Prevents accidental deletion of state
  }

  tags = {
    Name      = "Terraform State Bucket"
    ManagedBy = "Bootstrap"
    Owner     = "Vanessa Awo"
  }
}

# Enable versioning — keeps history of state files so you can roll back
resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Encrypt state file at rest — state files contain sensitive values (DB passwords, etc.)
resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Block all public access — state files should NEVER be public
resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket                  = aws_s3_bucket.terraform_state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ─── DynamoDB Table for State Locking ─────────────────────────────────────────
# When two people run terraform apply at the same time, locking prevents conflicts.
# Only one terraform operation can hold the lock at a time.
resource "aws_dynamodb_table" "terraform_locks" {
  name         = "terraform-state-lock"
  billing_mode = "PAY_PER_REQUEST"  # Only pay when locks are actually used
  hash_key     = "LockID"           # This exact name is required by Terraform

  attribute {
    name = "LockID"
    type = "S"  # S = String
  }

  tags = {
    Name      = "Terraform State Lock Table"
    ManagedBy = "Bootstrap"
    Owner     = "Vanessa Awo"
  }
}

# ─── Outputs ──────────────────────────────────────────────────────────────────
output "state_bucket_name" {
  value       = aws_s3_bucket.terraform_state.id
  description = "Use this bucket name in the backend config of your main Terraform project"
}

output "lock_table_name" {
  value       = aws_dynamodb_table.terraform_locks.name
  description = "Use this table name in the backend config of your main Terraform project"
}
