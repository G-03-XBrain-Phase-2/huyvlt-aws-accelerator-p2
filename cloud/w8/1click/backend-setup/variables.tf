variable "aws_region" {
  description = "AWS region for provisioning remote state infrastructure"
  type        = string
  default     = "ap-southeast-1"
}

variable "bucket_name" {
  description = "Name of the S3 bucket for Terraform state"
  type        = string
  default     = "huyvlt-xb-dn26-102-tfstate-bucket"
}

variable "dynamodb_table_name" {
  description = "Name of the DynamoDB table for state locking"
  type        = string
  default     = "terraform-state-locks"
}
