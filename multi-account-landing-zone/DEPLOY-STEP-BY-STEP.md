# Project 2: Multi-Account AWS Landing Zone — Deployment Guide

> **Goal:** Build the enterprise governance foundation — AWS Organizations, SCPs, centralized security, and network isolation.
> **⚠️ WARNING:** This project modifies your AWS Organization. Use a dedicated learning AWS account.
> **Time to complete:** ~30 minutes
> **AWS Cost:** ~$0/month for Organizations structure. GuardDuty ~$4/month. Transit Gateway ~$33/month (destroy when done).

---

## Why Multi-Account Architecture?

Imagine one AWS account like one big office with no walls. If one person causes a problem (runaway costs, security breach), it affects everyone.

Multi-account is like separate floors in a building:
- Security team is on floor 1 (Security account) — they see everything
- Production apps are on floor 2 (Workloads-Prod account) — isolated from dev
- Developers are on floor 3 (Workloads-Dev account) — can't touch prod
- Shared tools are on floor 4 (Shared Services) — everyone can use them

---

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────┐
│                   Management Account                     │
│   AWS Organizations Root                                │
│   SCPs (Service Control Policies) — the guardrails      │
│   IAM Identity Center (SSO) — one login for all accounts│
└────────────┬────────────────────────────────────────────┘
             │
     ┌───────┴────────────────────────────────┐
     │                                        │
     ▼                                        ▼
┌──────────────┐                    ┌──────────────────────┐
│ Security OU  │                    │  Workloads OU        │
│              │                    │                      │
│ ┌──────────┐ │   Transit Gateway  │ ┌──────────────────┐ │
│ │Security  │ │   Hub-and-Spoke    │ │  Prod Account    │ │
│ │Account   │◄├───────────────────►│  (isolated VPC)  │ │
│ │GuardDuty │ │                    │ └──────────────────┘ │
│ │Sec Hub   │ │                    │ ┌──────────────────┐ │
│ └──────────┘ │                    │ │  Dev Account     │ │
│ ┌──────────┐ │                    │  (isolated VPC)  │ │
│ │Log       │ │                    │ └──────────────────┘ │
│ │Archive   │ │                    └──────────────────────┘
│ │Account   │ │
│ └──────────┘ │
└──────────────┘

8 SCPs enforced EVERYWHERE:
✗ DenyRootUser           → No one can use root credentials
✗ RequireIMDSv2          → Prevents credential theft via EC2 metadata
✗ AllowedRegionsOnly     → Resources only in us-east-1, us-west-2
✗ DenyPublicS3           → No public S3 buckets allowed
✗ RequireEncryption      → All EBS volumes must be encrypted
✗ DenyLargeInstances     → No instances larger than t3/m5 without approval
✗ RequireTagging         → All resources must have Project/Environment tags
✗ DenyDisableCloudTrail  → CloudTrail logging cannot be disabled
```

---

## What Are SCPs? (Service Control Policies)

SCPs are permission guardrails at the organization level. They override individual IAM permissions.

**Example:** Even if a developer has `s3:PutBucketAcl` permission in their IAM policy, the `DenyPublicS3` SCP prevents them from making any S3 bucket public. The SCP wins.

**Interview answer:** "SCPs are the outermost security boundary — they apply to every account in the organization regardless of what IAM policies say. I deployed 8 SCPs covering root user access, IMDS version enforcement, region restriction, public S3 prevention, encryption requirements, instance size limits, resource tagging, and CloudTrail protection."

---

## Prerequisites

```
[ ] AWS Account with Organizations enabled (or permission to enable it)
[ ] You must be in the MANAGEMENT account (root of the organization)
[ ] AWS CLI configured with management account credentials
[ ] Terraform >= 1.6
```

**Check if Organizations is already enabled:**
```bash
aws organizations describe-organization
# If you see "Organization not found" → Organizations is not enabled ye
# Enable it in AWS Console → AWS Organizations → Create organization
```

---

## Step 1: Bootstrap

```bash
cd multi-account-landing-zone/bootstrap
terraform ini
terraform apply
```

---

## Step 2: Configure Variables

```bash
cd ..
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
```

Edit `terraform/terraform.tfvars`:
```hcl
organization_name  = "vanessa-learning-org"
management_email   = "your-management-email@gmail.com"
security_email     = "your-security-email@gmail.com"
log_archive_email  = "your-logs-email@gmail.com"
allowed_regions    = ["us-east-1", "us-west-2"]
alert_email        = "your-email@gmail.com"
```

---

## Step 3: Understand the Terraform Structure

```
multi-account-landing-zone/terraform/
├── envs/root/
│   ├── main.tf          ← Deploy from HERE (root environment)
│   └── scps.tf          ← All 8 Service Control Policies
└── modules/
    ├── organizations/   ← Creates OUs and member accounts
    ├── security-hub/    ← Enables GuardDuty + Security Hub
    ├── networking/      ← Transit Gateway hub-and-spoke
    └── identity/        ← IAM Identity Center (SSO)
```

---

## Step 4: Deploy Phase 1 — Organizations Structure

```bash
cd terraform/envs/roo
terraform ini
terraform plan
terraform apply
# This creates: Root OU → Security OU + Workloads OU + Infrastructure OU
# Takes ~5-10 minutes (account creation is slow)
```

**What gets created:**
- AWS Organization with 4 OUs
- Security Account (dedicated to GuardDuty, Security Hub)
- Log Archive Account (dedicated CloudTrail + S3 logs)
- Shared Services Account (DNS, patching tools)
- Workloads-Prod and Workloads-Dev accounts

---

## Step 5: Verify SCPs Are Applied

```bash
# List all SCPs in your organization
aws organizations list-policies --filter SERVICE_CONTROL_POLICY
  --query 'Policies[].{Name:Name, Id:Id}'
  --output table

# Verify a specific SCP is attached to an OU
aws organizations list-policies-for-targe
  --target-id ROOT_ID
  --filter SERVICE_CONTROL_POLICY
  --query 'Policies[].Name'
```

---

## Step 6: Test SCP Enforcemen

Test that `DenyPublicS3` works from a member account:

```bash
# Switch to a workloads accoun
aws sts assume-role
  --role-arn "arn:aws:iam::WORKLOADS_ACCOUNT_ID:role/OrganizationAccountAccessRole"
  --role-session-name "test-session"

# Try to create a public S3 bucket (this should FAIL with AccessDenied)
aws s3api create-bucket --bucket test-public-bucket --acl public-read
# Expected: AccessDeniedException (SCP blocked it — SUCCESS!)
```

---

## Step 7: Understand Transit Gateway

Transit Gateway is the network hub. Instead of VPC peering (which requires a mesh of connections), Transit Gateway is a central router:

```
Without Transit Gateway (VPC Peering — messy):
Prod-VPC ←→ Dev-VPC
Prod-VPC ←→ Security-VPC
Dev-VPC  ←→ Security-VPC
(n accounts = n*(n-1)/2 connections)

With Transit Gateway (Hub-and-spoke — clean):
Prod-VPC ─┐
Dev-VPC  ─┼─► Transit Gateway ─── Security-VPC
Infra-VPC ─┘
(n accounts = n connections)
```

---

## Step 8: DESTROY When Done

```bash
terraform destroy
# Type "yes"
# Note: Member accounts can take 90 days to fully close after deletion
```

---

## The 8 SCPs — What Each One Does

### SCP 1: DenyRootUser
```json
{
  "Effect": "Deny",
  "Action": "*",
  "Resource": "*",
  "Condition": {
    "StringLike": {"aws:PrincipalArn": "arn:aws:iam::*:root"}
  }
}
```
**What it does:** Prevents anyone from using the root user of any account.
**Why:** Root has unlimited permissions with no restrictions. AWS recommends never using root.

### SCP 2: RequireIMDSv2
```json
{
  "Effect": "Deny",
  "Action": "ec2:RunInstances",
  "Resource": "arn:aws:ec2:*:*:instance/*",
  "Condition": {
    "StringNotEquals": {"ec2:MetadataHttpTokens": "required"}
  }
}
```
**What it does:** All new EC2 instances must use IMDSv2 (Instance Metadata Service v2).
**Why:** IMDSv1 is vulnerable to SSRF attacks. An attacker could steal EC2 credentials via the metadata endpoint. IMDSv2 requires a signed token, blocking this attack.

### SCP 3: AllowedRegionsOnly
```json
{
  "Effect": "Deny",
  "Action": "*",
  "Resource": "*",
  "Condition": {
    "StringNotEquals": {
      "aws:RequestedRegion": ["us-east-1", "us-west-2"]
    }
  }
}
```
**What it does:** Resources can only be created in approved regions.
**Why:** Data residency compliance. Prevents accidental deployment to regions in restricted jurisdictions.

---

## What to Say in an Interview

> "The multi-account landing zone is the governance foundation every organization needs before scaling on AWS. I designed AWS Organizations with four OUs — Management, Security, Infrastructure, and Workloads — across ten plus accounts. I deployed eight SCPs including DenyRootUser, RequireIMDSv2, AllowedRegionsOnly, and DenyPublicS3. These SCPs override individual IAM policies — even if someone's IAM policy allows creating a public S3 bucket, the DenyPublicS3 SCP at the organization level prevents it. I implemented Transit Gateway hub-and-spoke for network isolation between Prod and Dev, and centralized GuardDuty and Security Hub across all accounts for unified threat detection."
