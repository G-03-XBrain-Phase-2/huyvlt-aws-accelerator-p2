# Terraform — Root Account Alert Lab
# Session 05: CloudTrail + Metric Filter + Alarm + SNS + Lambda

terraform {
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
  required_version = ">= 1.5.0"
}

provider "aws" {
  region = var.aws_region
}

locals {
  trail_name   = "security-audit-trail"
  log_group    = "/aws/cloudtrail/security-trail"
  account_id   = data.aws_caller_identity.current.account_id
}

data "aws_caller_identity" "current" {}

# ── S3 Bucket cho CloudTrail ──────────────────────────────────────────────────
resource "aws_s3_bucket" "cloudtrail_logs" {
  bucket        = "cloudtrail-logs-${local.account_id}-${var.aws_region}"
  force_destroy = true

  tags = var.common_tags
}

resource "aws_s3_bucket_public_access_block" "cloudtrail_logs" {
  bucket                  = aws_s3_bucket.cloudtrail_logs.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_policy" "cloudtrail_logs" {
  bucket = aws_s3_bucket.cloudtrail_logs.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AWSCloudTrailAclCheck"
        Effect    = "Allow"
        Principal = { Service = "cloudtrail.amazonaws.com" }
        Action    = "s3:GetBucketAcl"
        Resource  = aws_s3_bucket.cloudtrail_logs.arn
      },
      {
        Sid       = "AWSCloudTrailWrite"
        Effect    = "Allow"
        Principal = { Service = "cloudtrail.amazonaws.com" }
        Action    = "s3:PutObject"
        Resource  = "${aws_s3_bucket.cloudtrail_logs.arn}/AWSLogs/${local.account_id}/*"
        Condition = {
          StringEquals = { "s3:x-amz-acl" = "bucket-owner-full-control" }
        }
      }
    ]
  })
}

# ── CloudWatch Log Group ──────────────────────────────────────────────────────
resource "aws_cloudwatch_log_group" "cloudtrail" {
  name              = local.log_group
  retention_in_days = 90
  tags              = var.common_tags
}

# ── IAM Role cho CloudTrail → CloudWatch ──────────────────────────────────────
resource "aws_iam_role" "cloudtrail_cw_role" {
  name = "CloudTrail-CloudWatch-Role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "cloudtrail.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = var.common_tags
}

resource "aws_iam_role_policy" "cloudtrail_cw_policy" {
  name = "CloudTrailToCloudWatchLogs"
  role = aws_iam_role.cloudtrail_cw_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["logs:CreateLogStream", "logs:PutLogEvents"]
      Resource = "${aws_cloudwatch_log_group.cloudtrail.arn}:*"
    }]
  })
}

# ── Bước 1: CloudTrail Trail ──────────────────────────────────────────────────
resource "aws_cloudtrail" "security_trail" {
  name                          = local.trail_name
  s3_bucket_name                = aws_s3_bucket.cloudtrail_logs.id
  include_global_service_events = true
  is_multi_region_trail         = true
  enable_log_file_validation    = true

  # Gửi logs tới CloudWatch (Bước 1 trong slide)
  cloud_watch_logs_group_arn = "${aws_cloudwatch_log_group.cloudtrail.arn}:*"
  cloud_watch_logs_role_arn  = aws_iam_role.cloudtrail_cw_role.arn

  tags = var.common_tags

  depends_on = [aws_s3_bucket_policy.cloudtrail_logs]
}

# ── Bước 2: CloudWatch Metric Filter ─────────────────────────────────────────
resource "aws_cloudwatch_log_metric_filter" "root_login" {
  name           = "RootAccountLoginFilter"
  log_group_name = aws_cloudwatch_log_group.cloudtrail.name

  # Pattern chính xác từ slide
  pattern = "{ $.userIdentity.type = \"Root\" && $.eventType != \"AwsServiceEvent\" }"

  metric_transformation {
    name          = "RootAccountLoginCount"
    namespace     = "Security"
    value         = "1"
    default_value = "0"
    unit          = "Count"
  }
}

# ── Bước 4: SNS Topic ────────────────────────────────────────────────────────
resource "aws_sns_topic" "security_alerts" {
  name         = "root-login-security-alerts"
  display_name = "AWS Root Login SECURITY ALERT"
  tags         = var.common_tags
}

resource "aws_sns_topic_subscription" "email_alert" {
  topic_arn = aws_sns_topic.security_alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

resource "aws_sns_topic_subscription" "sms_alert" {
  count     = var.alert_phone != "" ? 1 : 0
  topic_arn = aws_sns_topic.security_alerts.arn
  protocol  = "sms"
  endpoint  = var.alert_phone
}

# ── Bước 3: CloudWatch Alarm ─────────────────────────────────────────────────
resource "aws_cloudwatch_metric_alarm" "root_login_alarm" {
  alarm_name          = "RootAccountLogin-Alert"
  alarm_description   = "SECURITY ALERT: Root account đã được sử dụng! Điều tra ngay lập tức."
  comparison_operator = "GreaterThanOrEqualToThreshold"

  # Bắt nguồn từ Metric Filter (Bước 2)
  namespace   = "Security"
  metric_name = "RootAccountLoginCount"
  statistic   = "Sum"

  # Trigger ngay khi có 1 lần login (slide: "ANY single root login")
  threshold          = 1
  period             = 300
  evaluation_periods = 1
  datapoints_to_alarm = 1
  treat_missing_data = "notBreaching"

  # SNS Actions (Bước 4)
  alarm_actions = [aws_sns_topic.security_alerts.arn]
  ok_actions    = [aws_sns_topic.security_alerts.arn]

  depends_on = [aws_cloudwatch_log_metric_filter.root_login]

  tags = var.common_tags
}

# ── Optional: Lambda Auto-Disable ────────────────────────────────────────────
data "archive_file" "lambda_zip" {
  count       = var.deploy_lambda ? 1 : 0
  type        = "zip"
  source_dir  = "${path.module}/../lambda/auto-disable-root"
  output_path = "${path.module}/lambda_function.zip"
}

resource "aws_iam_role" "lambda_role" {
  count = var.deploy_lambda ? 1 : 0
  name  = "RootLoginAutoDisable-Lambda-Role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_basic" {
  count      = var.deploy_lambda ? 1 : 0
  role       = aws_iam_role.lambda_role[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "lambda_iam_policy" {
  count = var.deploy_lambda ? 1 : 0
  name  = "RootAutoDisablePolicy"
  role  = aws_iam_role.lambda_role[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["iam:ListAccessKeys", "iam:UpdateAccessKey", "iam:GetAccountSummary"]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = ["sns:Publish"]
        Resource = aws_sns_topic.security_alerts.arn
      }
    ]
  })
}

resource "aws_lambda_function" "auto_disable_root" {
  count            = var.deploy_lambda ? 1 : 0
  function_name    = "RootLoginAutoDisable"
  role             = aws_iam_role.lambda_role[0].arn
  handler          = "handler.lambda_handler"
  runtime          = "python3.12"
  timeout          = 30
  filename         = data.archive_file.lambda_zip[0].output_path
  source_code_hash = data.archive_file.lambda_zip[0].output_base64sha256

  environment {
    variables = {
      ALERT_TOPIC_ARN = aws_sns_topic.security_alerts.arn
      AUDIT_LOG_GROUP = "/security/root-login-audit"
    }
  }

  tags = var.common_tags
}

resource "aws_sns_topic_subscription" "lambda_trigger" {
  count     = var.deploy_lambda ? 1 : 0
  topic_arn = aws_sns_topic.security_alerts.arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.auto_disable_root[0].arn
}

resource "aws_lambda_permission" "sns_invoke" {
  count         = var.deploy_lambda ? 1 : 0
  statement_id  = "AllowSNSInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.auto_disable_root[0].function_name
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.security_alerts.arn
}
