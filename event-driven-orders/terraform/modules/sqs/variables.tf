variable "name" {
  description = "Project name used in resource naming"
  type        = string
}

variable "environment" {
  description = "Deployment environment"
  type        = string
}

variable "visibility_timeout" {
  description = "Seconds a message is hidden after being received (must match Lambda timeout)"
  type        = number
  default     = 30
}

variable "max_receive_count" {
  description = "Number of processing attempts before a message moves to DLQ"
  type        = number
  default     = 3
}
