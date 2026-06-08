output "s3_bucket_name" {
  description = "The name of the S3 bucket created for Terraform remote state"
  value       = aws_s3_bucket.state_bucket.id
}

output "dynamodb_table_name" {
  description = "The name of the DynamoDB table created for State Locking"
  value       = aws_dynamodb_table.state_locks.name
}
