output "cloudtrail_trail_arn" {
  description = "ARN của CloudTrail Trail"
  value       = aws_cloudtrail.security_trail.arn
}

output "cloudwatch_log_group" {
  description = "Tên CloudWatch Log Group nhận CloudTrail logs"
  value       = aws_cloudwatch_log_group.cloudtrail.name
}

output "metric_filter_name" {
  description = "Tên Metric Filter phát hiện Root login"
  value       = aws_cloudwatch_log_metric_filter.root_login.name
}

output "alarm_name" {
  description = "Tên CloudWatch Alarm"
  value       = aws_cloudwatch_metric_alarm.root_login_alarm.alarm_name
}

output "sns_topic_arn" {
  description = "ARN SNS Topic gửi cảnh báo"
  value       = aws_sns_topic.security_alerts.arn
}

output "lambda_function_name" {
  description = "Tên Lambda auto-disable function (nếu có deploy)"
  value       = var.deploy_lambda ? aws_lambda_function.auto_disable_root[0].function_name : "Không deploy"
}

output "next_steps" {
  description = "Hướng dẫn sau khi apply"
  value = <<-EOT
    ✅ Infrastructure đã được tạo!

    📋 Việc cần làm thủ công:
    1. Confirm email subscription: check ${var.alert_email}
    ${var.alert_phone != "" ? "2. SMS subscription đã active tự động" : "2. (Bỏ qua SMS - không có phone)"}

    🧪 Test không cần root login:
       bash ../scripts/test-metric-filter.sh

    🔍 Verify toàn bộ:
       bash ../scripts/verify-lab.sh

    📊 Console:
       https://console.aws.amazon.com/cloudwatch/home?region=${var.aws_region}#alarmsV2:
  EOT
}
