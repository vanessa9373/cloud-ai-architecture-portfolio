variable "table_name" {
  description = "Base name of the DynamoDB table (environment suffix will be appended)"
  type        = string
}

variable "environment" {
  description = "Deployment environment (production, staging, dev)"
  type        = string
}
