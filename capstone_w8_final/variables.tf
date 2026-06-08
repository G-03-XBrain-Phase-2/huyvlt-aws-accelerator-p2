variable "aws_region" {
  description = "AWS Region to deploy resources"
  type        = string
  default     = "ap-southeast-1"
}

variable "project_name" {
  description = "Prefix for all resource names"
  type        = string
  default     = "capstone-final-huyvlt"
}

variable "vpc_cidr" {
  description = "CIDR block for the custom VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "instance_type" {
  description = "EC2 instance type for the web server"
  type        = string
  default     = "t3.micro"
}

variable "db_username" {
  description = "Master username for RDS MySQL database"
  type        = string
  default     = "admin"
}

variable "db_password" {
  description = "Master password for RDS MySQL database"
  type        = string
  sensitive   = true
}

variable "db_name" {
  description = "Database name inside RDS MySQL"
  type        = string
  default     = "appdb"
}

variable "static_bucket_name" {
  description = "Globally unique name for static assets S3 bucket"
  type        = string
  default     = "huyvlt-xb-dn26-102-static-assets"
}
