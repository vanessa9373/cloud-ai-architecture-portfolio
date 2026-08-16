output "api_endpoint" {
  description = "API Gateway invoke URL"
  value       = module.api_gateway.invoke_url
}

output "orders_table_name" {
  description = "DynamoDB orders table name"
  value       = module.dynamodb.table_name
}

output "intake_queue_url" {
  description = "SQS order intake queue URL"
  value       = module.sqs.intake_queue_url
}

output "dlq_url" {
  description = "SQS dead-letter queue URL"
  value       = module.sqs.dlq_url
}

output "validator_function_name" {
  description = "Order Validator Lambda function name"
  value       = module.lambda.validator_function_name
}

output "processor_function_name" {
  description = "Order Processor Lambda function name"
  value       = module.lambda.processor_function_name
}
