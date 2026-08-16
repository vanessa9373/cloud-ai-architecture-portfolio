data "archive_file" "validator_zip" {
  type        = "zip"
  source_file = "${path.module}/functions/validator/handler.py"
  output_path = "${path.module}/functions/validator.zip"
}

data "archive_file" "processor_zip" {
  type        = "zip"
  source_file = "${path.module}/functions/processor/handler.py"
  output_path = "${path.module}/functions/processor.zip"
}

############################
# IAM — Validator Lambda role
############################
resource "aws_iam_role" "validator" {
  name = "${var.name}-validator-role-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = {
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

resource "aws_iam_role_policy_attachment" "validator_basic" {
  role       = aws_iam_role.validator.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "validator_sqs" {
  name = "sqs-send"
  role = aws_iam_role.validator.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["sqs:SendMessage"]
      Resource = [var.intake_queue_arn]
    }]
  })
}

############################
# IAM — Processor Lambda role
############################
resource "aws_iam_role" "processor" {
  name = "${var.name}-processor-role-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = {
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

resource "aws_iam_role_policy_attachment" "processor_basic" {
  role       = aws_iam_role.processor.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "processor_permissions" {
  name = "processor-permissions"
  role = aws_iam_role.processor.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes",
          "sqs:ChangeMessageVisibility",
        ]
        Resource = [var.intake_queue_arn]
      },
      {
        Effect   = "Allow"
        Action   = ["dynamodb:PutItem", "dynamodb:GetItem"]
        Resource = [var.orders_table_arn]
      },
      {
        Effect   = "Allow"
        Action   = ["sns:Publish"]
        Resource = [var.sns_topic_arn]
      },
    ]
  })
}

############################
# Lambda function — Validator
############################
resource "aws_lambda_function" "validator" {
  function_name    = "${var.name}-validator-${var.environment}"
  role             = aws_iam_role.validator.arn
  handler          = "handler.lambda_handler"
  runtime          = var.runtime
  architectures    = [var.architecture]
  filename         = data.archive_file.validator_zip.output_path
  source_code_hash = data.archive_file.validator_zip.output_base64sha256
  timeout          = 10
  memory_size      = 256

  environment {
    variables = {
      INTAKE_QUEUE_URL = var.intake_queue_url
    }
  }

  tags = {
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

############################
# Lambda function — Processor
############################
resource "aws_lambda_function" "processor" {
  function_name    = "${var.name}-processor-${var.environment}"
  role             = aws_iam_role.processor.arn
  handler          = "handler.lambda_handler"
  runtime          = var.runtime
  architectures    = [var.architecture]
  filename         = data.archive_file.processor_zip.output_path
  source_code_hash = data.archive_file.processor_zip.output_base64sha256
  timeout          = 30
  memory_size      = 256

  environment {
    variables = {
      ORDERS_TABLE_NAME = var.orders_table_name
      SNS_TOPIC_ARN     = var.sns_topic_arn
    }
  }

  tags = {
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

############################
# SQS → Processor event source mapping
############################
resource "aws_lambda_event_source_mapping" "sqs_processor" {
  event_source_arn        = var.intake_queue_arn
  function_name           = aws_lambda_function.processor.arn
  batch_size              = 10
  function_response_types = ["ReportBatchItemFailures"]
}

############################
# CloudWatch Log Groups
############################
resource "aws_cloudwatch_log_group" "validator_logs" {
  name              = "/aws/lambda/${aws_lambda_function.validator.function_name}"
  retention_in_days = 30
}

resource "aws_cloudwatch_log_group" "processor_logs" {
  name              = "/aws/lambda/${aws_lambda_function.processor.function_name}"
  retention_in_days = 30
}
