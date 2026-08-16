resource "aws_sqs_queue" "dlq" {
  name                        = "${var.name}-orders-dlq-${var.environment}.fifo"
  fifo_queue                  = true
  content_based_deduplication = true
  message_retention_seconds   = 1209600 # 14 days — max retention for investigation

  tags = {
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

resource "aws_sqs_queue" "intake" {
  name                        = "${var.name}-orders-intake-${var.environment}.fifo"
  fifo_queue                  = true
  content_based_deduplication = true
  visibility_timeout_seconds  = var.visibility_timeout

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dlq.arn
    maxReceiveCount     = var.max_receive_count
  })

  tags = {
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

resource "aws_sns_topic" "order_confirmations" {
  name                        = "${var.name}-order-confirmations-${var.environment}.fifo"
  fifo_topic                  = true
  content_based_deduplication = true

  tags = {
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}
