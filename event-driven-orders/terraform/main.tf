terraform {
  required_version = ">= 1.6"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.0"
    }
  }
  backend "s3" {
    bucket         = "vanessa-tfstate-management"
    key            = "event-driven-orders/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-state-lock"
    encrypt        = true
  }
}

provider "aws" {
  region = var.aws_region
}

module "dynamodb" {
  source = "./modules/dynamodb"

  table_name  = "${var.project_name}-orders"
  environment = var.environment
}

module "sqs" {
  source = "./modules/sqs"

  name              = var.project_name
  environment       = var.environment
  visibility_timeout = 30
  max_receive_count  = 3
}

module "lambda" {
  source = "./modules/lambda"

  name                = var.project_name
  environment         = var.environment
  orders_table_arn    = module.dynamodb.table_arn
  orders_table_name   = module.dynamodb.table_name
  intake_queue_arn    = module.sqs.intake_queue_arn
  intake_queue_url    = module.sqs.intake_queue_url
  sns_topic_arn       = module.sqs.sns_topic_arn
  runtime             = "python3.12"
  architecture        = "arm64"
}

module "api_gateway" {
  source = "./modules/api-gateway"

  name                         = var.project_name
  environment                  = var.environment
  validator_lambda_invoke_arn  = module.lambda.validator_invoke_arn
  validator_lambda_name        = module.lambda.validator_function_name
  throttle_burst_limit         = 1000
  throttle_rate_limit          = 500
}

module "monitoring" {
  source = "./modules/monitoring"

  name                     = var.project_name
  environment              = var.environment
  dlq_arn                  = module.sqs.dlq_arn
  dlq_name                 = module.sqs.dlq_name
  validator_function_name  = module.lambda.validator_function_name
  processor_function_name  = module.lambda.processor_function_name
  alert_email              = var.alert_email
}
