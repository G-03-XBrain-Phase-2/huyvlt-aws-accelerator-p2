output "db_endpoint" {
  description = "The connection endpoint for the RDS MySQL instance"
  value       = aws_db_instance.this.endpoint
}

output "db_host" {
  description = "The address of the RDS MySQL instance"
  value       = aws_db_instance.this.address
}

output "db_port" {
  description = "The port on which the DB accepts connections"
  value       = aws_db_instance.this.port
}

output "db_name" {
  description = "The name of the database"
  value       = aws_db_instance.this.db_name
}

output "db_username" {
  description = "The master username for the database"
  value       = aws_db_instance.this.username
}

output "rds_sg_id" {
  description = "The security group ID of the RDS instance"
  value       = aws_security_group.rds_sg.id
}
