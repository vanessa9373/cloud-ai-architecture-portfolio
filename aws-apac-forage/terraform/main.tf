terraform {
  required_version = ">= 1.6"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
  }
  backend "s3" {
    bucket         = "vanessa-terraform-state"
    key            = "apac-forage/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-state-lock"
    encrypt        = true
  }
}

provider "aws" {
  region = var.aws_region
  default_tags {
    tags = {
      Project     = "shoplocal-apac"
      Environment = var.environment
      Owner       = "Vanessa Awo — SA Simulation"
      ManagedBy   = "Terraform"
    }
  }
}

provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}

variable "aws_region"   { default = "ap-southeast-2" }  # Sydney
variable "environment"  { default = "prod" }
variable "domain_name"  {}
variable "db_password"  { sensitive = true }
variable "alert_email"  {}

data "aws_availability_zones" "available" { state = "available" }

# ─── VPC ──────────────────────────────────────────────────────────────────────
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = { Name = "shoplocal-vpc" }
}

resource "aws_subnet" "public" {
  count             = 2
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.${count.index + 1}.0/24"
  availability_zone = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true
  tags = { Name = "public-${count.index + 1}" }
}

resource "aws_subnet" "private" {
  count             = 2
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.${count.index + 10}.0/24"
  availability_zone = data.aws_availability_zones.available.names[count.index]
  tags = { Name = "private-${count.index + 1}" }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "shoplocal-igw" }
}

# ─── RDS MySQL Multi-AZ ───────────────────────────────────────────────────────
resource "aws_db_subnet_group" "main" {
  name       = "shoplocal-db-subnet-group"
  subnet_ids = aws_subnet.private[*].id
  tags = { Name = "ShopLocal DB Subnet Group" }
}

resource "aws_security_group" "rds" {
  name   = "shoplocal-rds-sg"
  vpc_id = aws_vpc.main.id
  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.main.cidr_block]  # Only allow from within VPC
  }
}

resource "aws_db_instance" "wordpress" {
  identifier           = "shoplocal-prod"
  engine               = "mysql"
  engine_version       = "8.0"
  instance_class       = "db.t3.micro"    # Cheapest option for learning
  allocated_storage    = 20
  storage_type         = "gp3"
  storage_encrypted    = true             # Encrypt at rest

  db_name  = "wordpress"
  username = "wpuser"
  password = var.db_password

  multi_az               = true           # This is the key HA feature
  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]

  backup_retention_period = 35            # Keep 35 days of automated backups
  backup_window           = "03:00-04:00" # 3am Sydney time
  maintenance_window      = "sun:04:00-sun:05:00"

  deletion_protection = false             # Set to true in real production
  skip_final_snapshot = true             # Set to false in real production

  tags = { Name = "ShopLocal RDS MySQL Multi-AZ" }
}

# ─── Elastic Beanstalk ────────────────────────────────────────────────────────
resource "aws_elastic_beanstalk_application" "shoplocal" {
  name        = "shoplocal"
  description = "ShopLocal WordPress application"
}

resource "aws_elastic_beanstalk_environment" "prod" {
  name                = "shoplocal-prod"
  application         = aws_elastic_beanstalk_application.shoplocal.name
  solution_stack_name = "64bit Amazon Linux 2023 v4.0.0 running PHP 8.2"
  tier                = "WebServer"

  # Auto Scaling settings
  setting {
    namespace = "aws:autoscaling:asg"
    name      = "MinSize"
    value     = "2"   # At least 2 instances for HA
  }
  setting {
    namespace = "aws:autoscaling:asg"
    name      = "MaxSize"
    value     = "6"
  }

  # Load Balancer type
  setting {
    namespace = "aws:elasticbeanstalk:environment"
    name      = "LoadBalancerType"
    value     = "application"   # ALB (not classic)
  }

  # Database connection string (passed as environment variable)
  setting {
    namespace = "aws:elasticbeanstalk:application:environment"
    name      = "DB_HOST"
    value     = aws_db_instance.wordpress.endpoint
  }
  setting {
    namespace = "aws:elasticbeanstalk:application:environment"
    name      = "DB_NAME"
    value     = "wordpress"
  }

  # Health reporting
  setting {
    namespace = "aws:elasticbeanstalk:healthreporting:system"
    name      = "SystemType"
    value     = "enhanced"
  }

  tags = { Name = "ShopLocal Prod Environment" }
}

# ─── CloudFront CDN ───────────────────────────────────────────────────────────
resource "aws_cloudfront_distribution" "shoplocal" {
  enabled             = true
  comment             = "ShopLocal CDN"
  default_root_object = "index.php"

  # PriceClass_200 covers: US, Europe, Asia (covers ShopLocal's markets)
  # Cheaper than PriceClass_All which adds South America and Africa
  price_class = "PriceClass_200"

  origin {
    domain_name = aws_elastic_beanstalk_environment.prod.cname
    origin_id   = "beanstalk"
    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only"
    }
  }

  default_cache_behavior {
    allowed_methods        = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "beanstalk"
    viewer_protocol_policy = "redirect-to-https"
    compress               = true
    forwarded_values {
      query_string = true
      cookies { forward = "all" }
    }
    min_ttl     = 0
    default_ttl = 3600     # Cache for 1 hour by default
    max_ttl     = 86400    # Max cache: 24 hours
  }

  restrictions {
    geo_restriction { restriction_type = "none" }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  tags = { Name = "ShopLocal CloudFront" }
}

# ─── Route 53 Health Checks + DNS Failover ────────────────────────────────────
resource "aws_route53_health_check" "primary" {
  fqdn              = aws_cloudfront_distribution.shoplocal.domain_name
  port              = 443
  type              = "HTTPS"
  resource_path     = "/"
  failure_threshold = 3   # Fail over after 3 consecutive failures
  request_interval  = 30  # Check every 30 seconds
  tags = { Name = "ShopLocal Health Check" }
}

# ─── CloudWatch Alarm — notify on unhealthy hosts ─────────────────────────────
resource "aws_sns_topic" "alerts" {
  name = "shoplocal-alerts"
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

resource "aws_cloudwatch_metric_alarm" "unhealthy_hosts" {
  alarm_name          = "shoplocal-unhealthy-hosts"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "UnHealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Maximum"
  threshold           = 0
  alarm_description   = "Alert when any host becomes unhealthy"
  alarm_actions       = [aws_sns_topic.alerts.arn]
}

# ─── Outputs ──────────────────────────────────────────────────────────────────
output "beanstalk_url"    { value = "http://${aws_elastic_beanstalk_environment.prod.cname}" }
output "cloudfront_url"   { value = "https://${aws_cloudfront_distribution.shoplocal.domain_name}" }
output "rds_endpoint"     { value = aws_db_instance.wordpress.endpoint }
output "rds_multi_az"     { value = aws_db_instance.wordpress.multi_az }
output "price_class"      { value = "PriceClass_200 (US, Europe, Asia — covers ShopLocal markets)" }
