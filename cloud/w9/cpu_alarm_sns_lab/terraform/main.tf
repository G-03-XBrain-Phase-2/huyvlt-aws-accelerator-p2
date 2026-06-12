# Terraform — SNS Topic + CloudWatch Alarm cho CPU Alert Lab
# Session 03: CPU Alarm → Email Alert via SNS

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  required_version = ">= 1.5.0"
}

provider "aws" {
  region = var.aws_region
}

# ── Data: Lấy thông tin EC2 Instance ─────────────────────────────────────────
data "aws_instance" "target" {
  count       = var.instance_id != "" ? 1 : 0
  instance_id = var.instance_id
}

# ── SNS Topic (Standard) ──────────────────────────────────────────────────────
resource "aws_sns_topic" "cpu_alert" {
  name         = "cpu-alert-topic"
  display_name = "EC2 CPU High Alert"

  tags = var.common_tags
}

# ── Email Subscription ────────────────────────────────────────────────────────
resource "aws_sns_topic_subscription" "email_alert" {
  topic_arn = aws_sns_topic.cpu_alert.arn
  protocol  = "email"
  endpoint  = var.alert_email

  # Lưu ý: Subscription sẽ ở trạng thái PendingConfirmation
  # cho đến khi người dùng click link xác nhận trong email
}

# ── CloudWatch Alarm: CPU > 80% trong 5 phút ──────────────────────────────────
resource "aws_cloudwatch_metric_alarm" "high_cpu" {
  alarm_name          = "High-CPU-Alert"
  alarm_description   = "Cảnh báo khi CPUUtilization > ${var.cpu_threshold}% trong ${var.alarm_period / 60} phút liên tiếp"
  comparison_operator = "GreaterThanThreshold"

  # Metric configuration (Bước 2 & 3 trong slide)
  metric_name = "CPUUtilization"
  namespace   = "AWS/EC2"
  statistic   = "Average"

  # Alarm conditions (Bước 3 trong slide)
  threshold          = var.cpu_threshold  # > 80%
  period             = var.alarm_period   # 5 phút = 300s
  evaluation_periods = 1                  # 1 out of 1 datapoints
  datapoints_to_alarm = 1

  treat_missing_data = "notBreaching"

  dimensions = {
    InstanceId = var.instance_id
  }

  # SNS Notification Action (Bước 4 trong slide)
  alarm_actions = [aws_sns_topic.cpu_alert.arn]
  ok_actions    = [aws_sns_topic.cpu_alert.arn]  # Recovery alert (optional)

  tags = var.common_tags
}

# ── (Optional) EC2 Instance để test ──────────────────────────────────────────
# Bỏ comment nếu muốn Terraform tạo EC2 mới luôn

# data "aws_ami" "amazon_linux_2" {
#   most_recent = true
#   owners      = ["amazon"]
#   filter {
#     name   = "name"
#     values = ["amzn2-ami-hvm-*-x86_64-gp2"]
#   }
# }
#
# resource "aws_instance" "test_ec2" {
#   ami           = data.aws_ami.amazon_linux_2.id
#   instance_type = "t3.micro"
#   key_name      = var.key_pair_name
#
#   user_data = base64encode(<<-EOF
#     #!/bin/bash
#     # Cài stress để test CPU
#     amazon-linux-extras install epel -y
#     yum install -y stress
#   EOF
#   )
#
#   tags = merge(var.common_tags, { Name = "cpu-alarm-lab-ec2" })
# }
