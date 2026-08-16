# ─── 8 Service Control Policies ───────────────────────────────────────────────
# SCPs are organization-wide guardrails that override individual IAM policies.

# SCP 1: Deny Root User
resource "aws_organizations_policy" "deny_root_user" {
  name        = "DenyRootUser"
  description = "Prevent use of root credentials in all member accounts"
  type        = "SERVICE_CONTROL_POLICY"
  content = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid = "DenyRootUser"; Effect = "Deny"; Action = "*"; Resource = "*"
      Condition = { StringLike = { "aws:PrincipalArn" = ["arn:aws:iam::*:root"] } }
    }]
  })
}
resource "aws_organizations_policy_attachment" "deny_root_user" {
  policy_id = aws_organizations_policy.deny_root_user.id
  target_id = data.aws_organizations_organization.org.roots[0].id
}

# SCP 2: Require IMDSv2 — prevents SSRF credential theft at EC2 metadata endpoint
resource "aws_organizations_policy" "require_imdsv2" {
  name = "RequireIMDSv2"; type = "SERVICE_CONTROL_POLICY"
  description = "All EC2 instances must use IMDSv2"
  content = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid = "DenyIMDSv1"; Effect = "Deny"
      Action = "ec2:RunInstances"; Resource = "arn:aws:ec2:*:*:instance/*"
      Condition = { StringNotEquals = { "ec2:MetadataHttpTokens" = "required" } }
    }]
  })
}
resource "aws_organizations_policy_attachment" "require_imdsv2" {
  policy_id = aws_organizations_policy.require_imdsv2.id
  target_id = data.aws_organizations_organization.org.roots[0].id
}

# SCP 3: Allowed Regions Only — data residency compliance
resource "aws_organizations_policy" "allowed_regions" {
  name = "AllowedRegionsOnly"; type = "SERVICE_CONTROL_POLICY"
  description = "Resources can only be created in us-east-1 and us-west-2"
  content = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid = "DenyOutsideApprovedRegions"; Effect = "Deny"
      NotAction = ["iam:*", "organizations:*", "route53:*", "cloudfront:*", "waf:*", "support:*", "budgets:*"]
      Resource = "*"
      Condition = { StringNotEquals = { "aws:RequestedRegion" = ["us-east-1", "us-west-2"] } }
    }]
  })
}
resource "aws_organizations_policy_attachment" "allowed_regions" {
  policy_id = aws_organizations_policy.allowed_regions.id
  target_id = data.aws_organizations_organization.org.roots[0].id
}

# SCP 4: Deny Public S3 — eliminates data breach via public bucket misconfiguration
resource "aws_organizations_policy" "deny_public_s3" {
  name = "DenyPublicS3"; type = "SERVICE_CONTROL_POLICY"
  description = "No S3 bucket in the org can be made public"
  content = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid = "DenyPublicACL"; Effect = "Deny"
      Action = ["s3:PutBucketAcl", "s3:PutObjectAcl"]; Resource = "*"
      Condition = { StringEquals = { "s3:x-amz-acl" = ["public-read", "public-read-write", "authenticated-read"] } }
    }]
  })
}
resource "aws_organizations_policy_attachment" "deny_public_s3" {
  policy_id = aws_organizations_policy.deny_public_s3.id
  target_id = data.aws_organizations_organization.org.roots[0].id
}

# SCP 5: Require EBS Encryption
resource "aws_organizations_policy" "require_ebs_encryption" {
  name = "RequireEBSEncryption"; type = "SERVICE_CONTROL_POLICY"
  description = "All EBS volumes must be encrypted at rest"
  content = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid = "DenyUnencryptedEBS"; Effect = "Deny"
      Action = "ec2:RunInstances"; Resource = "arn:aws:ec2:*:*:volume/*"
      Condition = { Bool = { "ec2:Encrypted" = false } }
    }]
  })
}
resource "aws_organizations_policy_attachment" "require_ebs_encryption" {
  policy_id = aws_organizations_policy.require_ebs_encryption.id
  target_id = data.aws_organizations_organization.org.roots[0].id
}

# SCP 6: Deny Disable CloudTrail — attacker first move is disabling audit logs
resource "aws_organizations_policy" "deny_disable_cloudtrail" {
  name = "DenyDisableCloudTrail"; type = "SERVICE_CONTROL_POLICY"
  description = "Prevent CloudTrail from being disabled"
  content = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid = "DenyCloudTrailModification"; Effect = "Deny"
      Action = ["cloudtrail:DeleteTrail", "cloudtrail:StopLogging", "cloudtrail:UpdateTrail"]
      Resource = "*"
    }]
  })
}
resource "aws_organizations_policy_attachment" "deny_disable_cloudtrail" {
  policy_id = aws_organizations_policy.deny_disable_cloudtrail.id
  target_id = data.aws_organizations_organization.org.roots[0].id
}

# SCP 7: Require Resource Tagging
resource "aws_organizations_policy" "require_tags" {
  name = "RequireTagging"; type = "SERVICE_CONTROL_POLICY"
  description = "All resources must have Project and Environment tags"
  content = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid = "RequireTags"; Effect = "Deny"
      Action = ["ec2:RunInstances", "rds:CreateDBInstance", "lambda:CreateFunction", "s3:CreateBucket"]
      Resource = "*"
      Condition = { "Null" = { "aws:RequestTag/Project" = true, "aws:RequestTag/Environment" = true } }
    }]
  })
}
resource "aws_organizations_policy_attachment" "require_tags" {
  policy_id = aws_organizations_policy.require_tags.id
  target_id = data.aws_organizations_organization.org.roots[0].id
}

# SCP 8: Deny Large Instances Without Approval
resource "aws_organizations_policy" "deny_large_instances" {
  name = "DenyLargeInstances"; type = "SERVICE_CONTROL_POLICY"
  description = "Block very large instance types without explicit approval"
  content = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid = "DenyLargeEC2"; Effect = "Deny"; Action = "ec2:RunInstances"
      Resource = "arn:aws:ec2:*:*:instance/*"
      Condition = { StringLike = { "ec2:InstanceType" = ["*.4xlarge", "*.8xlarge", "*.12xlarge", "*.16xlarge", "x1.*", "p3.*", "p4.*"] } }
    }]
  })
}
resource "aws_organizations_policy_attachment" "deny_large_instances" {
  policy_id = aws_organizations_policy.deny_large_instances.id
  target_id = aws_organizations_organizational_unit.workloads.id
}
