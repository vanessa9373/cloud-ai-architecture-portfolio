output "table_arn" {
  description = "ARN of the orders DynamoDB table — used by Lambda IAM policy"
  value       = aws_dynamodb_table.orders.arn
}

output "table_name" {
  description = "Name of the orders DynamoDB table — passed as Lambda env var"
  value       = aws_dynamodb_table.orders.name
}
