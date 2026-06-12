output "instance_id" {
  description = "EC2 Instance ID"
  value       = aws_instance.lab_ec2.id
}

output "instance_public_ip" {
  description = "Public IP address của EC2 instance"
  value       = aws_instance.lab_ec2.public_ip
}

output "instance_public_dns" {
  description = "Public DNS của EC2 instance"
  value       = aws_instance.lab_ec2.public_dns
}

output "iam_role_arn" {
  description = "ARN của IAM Role CloudWatch Agent"
  value       = aws_iam_role.cloudwatch_agent_role.arn
}

output "iam_instance_profile_name" {
  description = "Tên Instance Profile"
  value       = aws_iam_instance_profile.cloudwatch_agent_profile.name
}

output "ssh_command" {
  description = "Lệnh SSH vào EC2"
  value       = "ssh -i <YOUR_KEY>.pem ec2-user@${aws_instance.lab_ec2.public_ip}"
}

output "cloudwatch_console_url" {
  description = "Link CloudWatch Metrics Console"
  value       = "https://console.aws.amazon.com/cloudwatch/home?region=${var.aws_region}#metricsV2:graph=~();query=~'*7bCWAgent,InstanceId*7d"
}
