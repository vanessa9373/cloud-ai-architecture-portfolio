variable "name" {
  description = "Project name used in resource naming"
  type        = string
}

variable "environment" {
  description = "Deployment environment"
  type        = string
}

variable "orders_table_arn" {
  description = "ARN of the DynamoDB orders table"
  type        = string
}

variable "orders_table_name" {
  description = "Name of the DynamoDB orders table"
  type        = string
}

variable "intake_queue_arn" {
  description = "ARN of the SQS intake queue (for event source mapping)"
  type        = string
}

variable "intake_queue_url" {
  description = "URL of the SQS intake queue (passed to validator as env var)"
  type        = string
}

variable "sns_topic_arn" {
  description = "ARN of the SNS topic (passed to processor as env var)"
  type        = string
}

variable "runtime" {
  description = "Lambda runtime"
  type        = string
  default     = "python3.12"
}

variable "architecture" {
  description = "Lambda CPU architecture — arm64 is 20% cheaper than x86_64"
  type        = string
  default     = "arm64"
}
