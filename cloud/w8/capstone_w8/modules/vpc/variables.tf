variable "project_name" {
  description = "Name prefix for VPC resources"
  type        = string
}

variable "common_tags" {
  description = "Common tags applied to all resources"
  type        = map(string)
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
}

variable "az" {
  description = "Primary availability zone"
  type        = string
}
