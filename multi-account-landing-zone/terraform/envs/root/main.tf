terraform {
  required_version = ">= 1.6"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
  }
  backend "s3" {
    bucket         = "vanessa-terraform-state"
    key            = "landing-zone/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-state-lock"
    encrypt        = true
  }
}

provider "aws" {
  region = var.aws_region
  default_tags {
    tags = {
      Project   = "multi-account-landing-zone"
      ManagedBy = "Terraform"
      Owner     = "Vanessa Awo"
    }
  }
}

# ─── Variables ─────────────────────────────────────────────────────────────────
variable "aws_region"          { default = "us-east-1" }
variable "organization_name"   { default = "vanessa-learning-org" }
variable "management_email"    {}
variable "security_email"      {}
variable "log_archive_email"   {}
variable "allowed_regions"     { default = ["us-east-1", "us-west-2"] }
variable "alert_email"         {}

# ─── AWS Organizations Structure ──────────────────────────────────────────────

# Get the root of the organization
data "aws_organizations_organization" "org" {}

# Security OU — contains Security and Log Archive accounts
resource "aws_organizations_organizational_unit" "security" {
  name      = "Security"
  parent_id = data.aws_organizations_organization.org.roots[0].id
  tags = { Name = "Security OU" }
}

# Infrastructure OU — contains Networking, Shared Services
resource "aws_organizations_organizational_unit" "infrastructure" {
  name      = "Infrastructure"
  parent_id = data.aws_organizations_organization.org.roots[0].id
  tags = { Name = "Infrastructure OU" }
}

# Workloads OU — contains Prod and Dev accounts
resource "aws_organizations_organizational_unit" "workloads" {
  name      = "Workloads"
  parent_id = data.aws_organizations_organization.org.roots[0].id
  tags = { Name = "Workloads OU" }
}

# Sandbox OU — for experimenting (more permissive SCPs)
resource "aws_organizations_organizational_unit" "sandbox" {
  name      = "Sandbox"
  parent_id = data.aws_organizations_organization.org.roots[0].id
  tags = { Name = "Sandbox OU" }
}

# ─── Member Accounts ──────────────────────────────────────────────────────────

# Security Account — hosts GuardDuty, Security Hub, centralized alerting
resource "aws_organizations_account" "security" {
  name      = "security-account"
  email     = var.security_email
  parent_id = aws_organizations_organizational_unit.security.id
  tags = { Name = "Security Account", Environment = "shared" }
}

# Log Archive Account — immutable CloudTrail + VPC Flow Logs destination
resource "aws_organizations_account" "log_archive" {
  name      = "log-archive-account"
  email     = var.log_archive_email
  parent_id = aws_organizations_organizational_unit.security.id
  tags = { Name = "Log Archive Account", Environment = "shared" }
}

# ─── CloudTrail — Organization-wide audit logging ─────────────────────────────
# Records every API call across ALL accounts in the organization
resource "aws_cloudtrail" "org_trail" {
  name                          = "org-cloudtrail"
  s3_bucket_name                = aws_s3_bucket.cloudtrail.id
  is_multi_region_trail         = true   # Captures all regions
  include_global_service_events = true   # Captures IAM, STS, etc.
  is_organization_trail         = true   # Captures all accounts in org
  enable_log_file_validation    = true   # Detects if logs are tampered
  kms_key_id                    = aws_kms_key.cloudtrail.arn
  tags = { Name = "Organization CloudTrail" }
}

# S3 bucket for CloudTrail logs
resource "aws_s3_bucket" "cloudtrail" {
  bucket = "org-cloudtrail-logs-${data.aws_caller_identity.current.account_id}"
  tags = { Name = "CloudTrail Logs Bucket" }
}

resource "aws_s3_bucket_public_access_block" "cloudtrail" {
  bucket                  = aws_s3_bucket.cloudtrail.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# KMS key for CloudTrail log encryption
resource "aws_kms_key" "cloudtrail" {
  description             = "CloudTrail encryption key"
  deletion_window_in_days = 30
  enable_key_rotation     = true
  tags = { Name = "CloudTrail KMS Key" }
}

data "aws_caller_identity" "current" {}

# ─── GuardDuty — Threat Detection ────────────────────────────────────────────
# GuardDuty analyzes CloudTrail, VPC Flow Logs, and DNS logs for threats
resource "aws_guardduty_detector" "main" {
  enable = true
  datasources {
    s3_logs { enable = true }
    kubernetes { audit_logs { enable = true } }
    malware_protection { scan_ec2_instance_with_findings { ebs_volumes { enable = true } } }
  }
  tags = { Name = "Organization GuardDuty" }
}

# GuardDuty findings → SNS → Email alert
resource "aws_cloudwatch_event_rule" "guardduty_findings" {
  name        = "guardduty-high-severity"
  description = "Alert on HIGH and CRITICAL GuardDuty findings"
  event_pattern = jsonencode({
    source      = ["aws.guardduty"]
    detail-type = ["GuardDuty Finding"]
    detail = { severity = [{ numeric = [">=", 7] }] }  # High (7+) and Critical (9+)
  })
}

resource "aws_sns_topic" "security_alerts" {
  name = "security-alerts"
  tags = { Name = "Security Alerts Topic" }
}

resource "aws_sns_topic_subscription" "security_email" {
  topic_arn = aws_sns_topic.security_alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

resource "aws_cloudwatch_event_target" "guardduty_to_sns" {
  rule = aws_cloudwatch_event_rule.guardduty_findings.name
  arn  = aws_sns_topic.security_alerts.arn
}

# ─── Outputs ──────────────────────────────────────────────────────────────────
output "organization_id"       { value = data.aws_organizations_organization.org.id }
output "security_ou_id"        { value = aws_organizations_organizational_unit.security.id }
output "workloads_ou_id"       { value = aws_organizations_organizational_unit.workloads.id }
output "security_account_id"   { value = aws_organizations_account.security.id }
output "log_archive_account_id" { value = aws_organizations_account.log_archive.id }
output "cloudtrail_bucket"     { value = aws_s3_bucket.cloudtrail.id }
output "guardduty_detector_id" { value = aws_guardduty_detector.main.id }
