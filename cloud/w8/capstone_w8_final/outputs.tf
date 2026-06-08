output "vpc_id" {
  description = "The ID of the provisioned custom VPC"
  value       = module.vpc.vpc_id
}

output "web_server_public_ip" {
  description = "The public IP of the EC2 Web Server"
  value       = module.ec2.public_ip
}

output "web_server_private_ip" {
  description = "The private IP of the EC2 Web Server"
  value       = module.ec2.private_ip
}

output "static_assets_bucket" {
  description = "The S3 Bucket name hosting static assets"
  value       = module.s3.bucket_name
}

output "database_endpoint" {
  description = "The connection endpoint of the RDS MySQL Database"
  value       = module.rds.db_endpoint
}

output "ssh_private_key_path" {
  description = "Path to the generated SSH Private Key on local disk"
  value       = module.ec2.ssh_key_path
}

output "application_url" {
  description = "The public URL to access the deployed Web Application Dashboard"
  value       = "http://${module.ec2.public_ip}/"
}
