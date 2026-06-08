output "instance_id" {
  description = "The ID of the EC2 instance"
  value       = aws_instance.this.id
}

output "public_ip" {
  description = "The public IP of the EC2 instance"
  value       = aws_instance.this.public_ip
}

output "private_ip" {
  description = "The private IP of the EC2 instance"
  value       = aws_instance.this.private_ip
}

output "security_group_id" {
  description = "The security group ID of the EC2 instance"
  value       = aws_security_group.ec2_sg.id
}

output "ssh_key_path" {
  description = "Path to the generated private key file"
  value       = local_sensitive_file.private_key.filename
}
