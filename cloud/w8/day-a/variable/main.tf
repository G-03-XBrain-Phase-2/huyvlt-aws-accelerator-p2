terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile
}

locals {
  name_prefix = "${var.project}-${var.environment}-"
  is_prod     = var.environment == "prod"

  common_tags = {
    Environment = var.environment
    Project     = var.project
    ManagedBy   = "Terraform"
  }
}

resource "aws_s3_bucket" "local" {
  bucket_prefix = local.name_prefix
  force_destroy = var.force_destroy

  tags = local.common_tags

  lifecycle {
    precondition {
      condition     = local.is_prod && var.force_destroy == false
      error_message = "S3 bucket can only be created in the 'prod' environment with force_destroy set to false."
    }
  }
}

output "bucket_name" {
  description = "Name of the created S3 bucket"
  value       = aws_s3_bucket.local.id
}
