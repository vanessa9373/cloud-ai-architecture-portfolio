variable "name" {
  description = "Project name used in resource naming"
  type        = string
}

variable "environment" {
  description = "Deployment environment"
  type        = string
}

variable "validator_lambda_invoke_arn" {
  description = "Invoke ARN of the validator Lambda function"
  type        = string
}

variable "validator_lambda_name" {
  description = "Name of the validator Lambda function (for permission grant)"
  type        = string
}

variable "throttle_burst_limit" {
  description = "Maximum concurrent requests API Gateway will allow (burst)"
  type        = number
  default     = 1000
}

variable "throttle_rate_limit" {
  description = "Steady-state requests per second API Gateway will allow"
  type        = number
  default     = 500
}
