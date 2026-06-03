variable "environment" {
  description = "Deployment environment (dev, staging, prod)"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "The environment variable must be one of 'dev', 'staging', or 'prod'."
  }
}

variable "project" {
  description = "Project name prefix"
  type        = string
  default     = "myproject"
}

variable "force_destroy" {
  description = "Allow deletion of non-empty S3 bucket"
  type        = bool
  default     = false
}

variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "ap-southeast-1"
}

variable "aws_profile" {
  description = "AWS CLI Profile to use"
  type        = string
  default     = "default"
}
