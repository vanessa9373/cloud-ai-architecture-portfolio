output "validator_invoke_arn" {
  description = "Invoke ARN of the validator Lambda — used by API Gateway integration"
  value       = aws_lambda_function.validator.invoke_arn
}

output "validator_function_name" {
  description = "Name of the validator Lambda — used by API Gateway permission + monitoring"
  value       = aws_lambda_function.validator.function_name
}

output "processor_function_name" {
  description = "Name of the processor Lambda — used by monitoring alarms"
  value       = aws_lambda_function.processor.function_name
}
