###############################################################
# Variables & Data Sources
# ##############################################################

variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "ap-southeast-1"
}

variable "project_name" {
  description = "Prefix for all resource names"
  type        = string
  default     = "k8s-demo-huyvlt"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zone" {
  description = "Primary AZ (used for EC2 subnet)"
  type        = string
  default     = "ap-southeast-1a"
}

variable "instance_type" {
  description = "EC2 instance type — t3.medium minimum for Minikube"
  type        = string
  default     = "t3.medium"
}

variable "app_port" {
  description = "Port the app listens on inside the container"
  type        = number
  default     = 80
}

variable "node_port" {
  description = "Kubernetes NodePort exposed on EC2 host"
  type        = number
  default     = 30080
}

# Dynamic AMI Resolution: Fetch the latest Amazon Linux 2023 AMI
data "aws_ssm_parameter" "al2023_ami" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}
