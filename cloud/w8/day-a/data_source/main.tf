terraform {
  required_version = ">= 1.10"
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

# 1. Caller Identity Data Source
data "aws_caller_identity" "current" {}

# 2. Availability Zones Data Source
data "aws_availability_zones" "available" {
  state = "available"
}

# 3. Amazon Linux 2023 AMI Data Source
data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023*-kernel-6.1-x86_64"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

# 4. Default VPC Data Source
data "aws_vpc" "default" {
  default = true
}

# Locals to filter out port 32
locals {
  web_ports = [for port in var.allowed_ports : port if port != 32]
}

# Security Group using dynamic block
resource "aws_security_group" "web_sg" {
  name        = "web-sg"
  description = "Security Group for Web Application"
  vpc_id      = data.aws_vpc.default.id

  dynamic "ingress" {
    for_each = local.web_ports
    content {
      description = "Allow port ${ingress.value}"
      from_port   = ingress.value
      to_port     = ingress.value
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "web-sg"
  }
}

# Outputs
output "account_id" {
  description = "AWS Account ID of the caller"
  value       = data.aws_caller_identity.current.account_id
}

output "availability_zones" {
  description = "List of availability zones in the region"
  value       = data.aws_availability_zones.available.names
}

output "ubuntu_ami_id" {
  description = "ID of the latest Amazon Linux 2023 AMI"
  value       = data.aws_ami.al2023.id
}
