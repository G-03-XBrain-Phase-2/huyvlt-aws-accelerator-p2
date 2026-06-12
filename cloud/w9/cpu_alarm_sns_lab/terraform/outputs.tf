output "sns_topic_arn" {
  description = "ARN của SNS Topic cpu-alert-topic"
  value       = aws_sns_topic.cpu_alert.arn
}

output "alarm_name" {
  description = "Tên CloudWatch Alarm"
  value       = aws_cloudwatch_metric_alarm.high_cpu.alarm_name
}

output "alarm_arn" {
  description = "ARN của CloudWatch Alarm"
  value       = aws_cloudwatch_metric_alarm.high_cpu.arn
}

output "subscription_info" {
  description = "Thông tin subscription"
  value = {
    email    = var.alert_email
    status   = "Kiểm tra email để confirm subscription!"
    protocol = "email"
  }
}

output "cloudwatch_console_url" {
  description = "Link CloudWatch Alarms Console"
  value = "https://console.aws.amazon.com/cloudwatch/home?region=${var.aws_region}#alarmsV2:alarm/High-CPU-Alert"
}

output "test_instructions" {
  description = "Hướng dẫn test nhanh"
  value = <<-EOT
    ✅ Setup hoàn tất!

    1. Confirm subscription: Check email ${var.alert_email}
    2. SSH vào EC2 và chạy: bash scripts/stress-cpu.sh
    3. Đợi ~5 phút → email cảnh báo sẽ được gửi
    4. Verify: bash scripts/verify-lab.sh --alarm-name High-CPU-Alert
  EOT
}
