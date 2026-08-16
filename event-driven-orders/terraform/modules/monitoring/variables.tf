variable "name" {
  description = "Project name used in resource naming"
  type        = string
}

variable "environment" {
  description = "Deployment environment"
  type        = string
}

variable "dlq_arn" {
  description = "ARN of the dead letter queue"
  type        = string
}

variable "dlq_name" {
  description = "Name of the dead letter queue (used in alarm metric dimension)"
  type        = string
}

variable "validator_function_name" {
  description = "Name of the validator Lambda function"
  type        = string
}

variable "processor_function_name" {
  description = "Name of the processor Lambda function"
  type        = string
}

variable "alert_email" {
  description = "Email address to receive CloudWatch alarm notifications"
  type        = string
  sensitive   = true
}
