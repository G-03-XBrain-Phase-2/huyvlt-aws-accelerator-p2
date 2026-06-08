variable "project_name" {
  description = "Name of the project to prefix resources"
  type        = string
}

variable "common_tags" {
  description = "Common tags to apply to resources"
  type        = map(string)
}

variable "vpc_id" {
  description = "The VPC ID"
  type        = string
}

variable "subnet_id" {
  description = "The subnet ID to place the EC2 instance in (must be public)"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "ami_id" {
  description = "The AMI ID for the EC2 instance (Amazon Linux 2023)"
  type        = string
}

variable "s3_bucket_name" {
  description = "Name of the S3 bucket for static assets"
  type        = string
}

variable "s3_bucket_arn" {
  description = "ARN of the S3 bucket for static assets"
  type        = string
}

variable "db_host" {
  description = "RDS DB host address"
  type        = string
}

variable "db_name" {
  description = "RDS DB name"
  type        = string
}

variable "db_username" {
  description = "RDS DB master username"
  type        = string
}

variable "db_password" {
  description = "RDS DB master password"
  type        = string
  sensitive   = true
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "s3_objects_ready" {
  description = "Trigger to ensure S3 objects are uploaded before EC2 boots"
  type        = any
  default     = []
}
