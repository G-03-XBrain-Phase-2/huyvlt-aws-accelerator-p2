provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile
}

# Cấu hình Remote Backend lưu trữ State
terraform {
  backend "s3" {
    bucket         = "huyvlt-terraform-state-bucket" # Thay bằng bucket của bạn
    key            = "w8/terraform.tfstate"
    region         = "ap-southeast-1"
    dynamodb_table = "terraform-state-locks"         # Thay bằng bảng DynamoDB khóa state
    encrypt        = true
  }
}

# Resource mẫu: Tạo một S3 bucket đơn giản
resource "aws_s3_bucket" "example" {
  bucket        = "huyvlt-example-bucket"
  force_destroy = true

  tags = {
    Name        = "HuyVLT Example Bucket"
    Environment = "Dev"
    Project     = "XBrain-AWS-Accelerator"
  }
}
