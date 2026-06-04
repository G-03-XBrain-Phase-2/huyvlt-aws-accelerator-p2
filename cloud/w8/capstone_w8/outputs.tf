###############################################################
# Outputs
# ##############################################################

output "alb_dns_name" {
  description = "ALB URL — Open this in your browser to view the application"
  value       = "http://${module.alb.alb_dns_name}"
}

output "ec2_public_ip" {
  description = "Public IP of the EC2 instance (for SSH debug)"
  value       = module.ec2.public_ip
}

output "ssh_command" {
  description = "SSH Command to access the EC2 instance"
  value       = "ssh -i generated-key.pem ec2-user@${module.ec2.public_ip}"
}

output "private_key_path" {
  description = "Local path to the generated private key"
  value       = "${path.module}/generated-key.pem"
  sensitive   = true
}
