resource "aws_sns_topic" "alerts" {
  name = "${var.name}-alerts-${var.environment}"

  tags = {
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

resource "aws_sns_topic_subscription" "email_alert" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
  # After apply, AWS sends a confirmation email — you MUST click "Confirm subscription"
}

############################
# Alarm 1: Any messages in DLQ = orders failed 3 times
############################
resource "aws_cloudwatch_metric_alarm" "dlq_messages" {
  alarm_name          = "${var.name}-dlq-messages-${var.environment}"
  alarm_description   = "Orders are failing processing and landing in the DLQ"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "ApproximateNumberOfMessagesVisible"
  namespace           = "AWS/SQS"
  period              = 60
  statistic           = "Sum"
  threshold           = 0

  dimensions = {
    QueueName = var.dlq_name
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
  ok_actions    = [aws_sns_topic.alerts.arn]

  tags = {
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

############################
# Alarm 2: Validator Lambda errors
############################
resource "aws_cloudwatch_metric_alarm" "validator_errors" {
  alarm_name          = "${var.name}-validator-errors-${var.environment}"
  alarm_description   = "Validator Lambda is throwing unhandled errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 60
  statistic           = "Sum"
  threshold           = 5

  dimensions = {
    FunctionName = var.validator_function_name
  }

  alarm_actions = [aws_sns_topic.alerts.arn]

  tags = {
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

############################
# Alarm 3: Processor Lambda errors
############################
resource "aws_cloudwatch_metric_alarm" "processor_errors" {
  alarm_name          = "${var.name}-processor-errors-${var.environment}"
  alarm_description   = "Processor Lambda is throwing unhandled errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 60
  statistic           = "Sum"
  threshold           = 5

  dimensions = {
    FunctionName = var.processor_function_name
  }

  alarm_actions = [aws_sns_topic.alerts.arn]

  tags = {
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

############################
# Alarm 4: Processor throttles
############################
resource "aws_cloudwatch_metric_alarm" "processor_throttles" {
  alarm_name          = "${var.name}-processor-throttles-${var.environment}"
  alarm_description   = "Processor Lambda is being throttled — increase concurrency limit"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  metric_name         = "Throttles"
  namespace           = "AWS/Lambda"
  period              = 60
  statistic           = "Sum"
  threshold           = 10

  dimensions = {
    FunctionName = var.processor_function_name
  }

  alarm_actions = [aws_sns_topic.alerts.arn]

  tags = {
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

############################
# CloudWatch Dashboard
############################
resource "aws_cloudwatch_dashboard" "orders" {
  dashboard_name = "${var.name}-${var.environment}"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0; y = 0; width = 12; height = 6
        properties = {
          title  = "Lambda Invocations"
          period = 60
          metrics = [
            ["AWS/Lambda", "Invocations", "FunctionName", var.validator_function_name],
            ["AWS/Lambda", "Invocations", "FunctionName", var.processor_function_name],
          ]
        }
      },
      {
        type   = "metric"
        x      = 12; y = 0; width = 12; height = 6
        properties = {
          title  = "Lambda Errors"
          period = 60
          metrics = [
            ["AWS/Lambda", "Errors", "FunctionName", var.validator_function_name],
            ["AWS/Lambda", "Errors", "FunctionName", var.processor_function_name],
          ]
        }
      },
      {
        type   = "metric"
        x      = 0; y = 6; width = 12; height = 6
        properties = {
          title  = "DLQ Depth (should always be 0)"
          period = 60
          metrics = [
            ["AWS/SQS", "ApproximateNumberOfMessagesVisible", "QueueName", var.dlq_name],
          ]
        }
      },
    ]
  })
}
