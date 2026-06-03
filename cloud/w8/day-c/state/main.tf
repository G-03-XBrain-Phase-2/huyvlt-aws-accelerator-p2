terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

variable "aws_profile" {
  description = "AWS CLI Profile to use"
  type        = string
  default     = "default"
}

provider "aws" {
  region  = "ap-southeast-1"
  profile = var.aws_profile
}

import {
  to = aws_s3_bucket.local
  id = "hoangcuteday"
}
