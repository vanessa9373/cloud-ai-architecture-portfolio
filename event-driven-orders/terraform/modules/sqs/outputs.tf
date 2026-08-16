output "intake_queue_arn" {
  description = "ARN of the intake FIFO queue — used by Lambda event source mapping"
  value       = aws_sqs_queue.intake.arn
}

output "intake_queue_url" {
  description = "URL of the intake FIFO queue — used by validator Lambda env var"
  value       = aws_sqs_queue.intake.id
}

output "dlq_arn" {
  description = "ARN of the dead letter queue — used by CloudWatch alarm"
  value       = aws_sqs_queue.dlq.arn
}

output "dlq_name" {
  description = "Name of the dead letter queue — used by CloudWatch alarm"
  value       = aws_sqs_queue.dlq.name
}

output "dlq_url" {
  description = "URL of the dead letter queue — used in root outputs for visibility"
  value       = aws_sqs_queue.dlq.id
}

output "sns_topic_arn" {
  description = "ARN of the SNS topic — used by processor Lambda env var"
  value       = aws_sns_topic.order_confirmations.arn
}
