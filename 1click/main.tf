###############################################################
# K8s on AWS — Terraform 1-Click
# Root Configuration
# Providers: AWS (infra) + TLS (key generation) + Local (file writing)
# ##############################################################

terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    # Provider 2: TLS — For generating cryptographic keys entirely inside Terraform
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    # Provider 3: Local — For writing the generated private key to disk securely
    local = {
      source  = "hashicorp/local"
      version = "~> 2.0"
    }
  }
}

# ----- Providers Init -----
provider "aws" {
  region = var.aws_region
}

provider "tls" {}

# ----- SSH Private Key & Key Pair Generation -----
# This resource uses the tls provider to generate a private key in the Terraform state
resource "tls_private_key" "this" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# This resource uses the local provider to write the private key to a local file
resource "local_sensitive_file" "private_key" {
  content         = tls_private_key.this.private_key_pem
  filename        = "${path.module}/generated-key.pem"
  file_permission = "0600"
}

# This resource uses the aws provider to upload the generated public key
resource "aws_key_pair" "this" {
  key_name   = "${var.project_name}-keypair"
  public_key = tls_private_key.this.public_key_openssh

  tags = local.common_tags
}

# ----- Modules -----
module "vpc" {
  source       = "./modules/vpc"
  project_name = var.project_name
  common_tags  = local.common_tags
  vpc_cidr     = var.vpc_cidr
  az           = var.availability_zone
}

module "ec2" {
  source            = "./modules/ec2"
  project_name      = var.project_name
  common_tags       = local.common_tags
  subnet_id         = module.vpc.public_subnet_id
  security_group_id = module.vpc.ec2_sg_id
  key_name          = aws_key_pair.this.key_name
  instance_type     = var.instance_type
  ami_id            = data.aws_ssm_parameter.al2023_ami.value
  app_port          = var.app_port
  node_port         = var.node_port
}

module "alb" {
  source            = "./modules/alb"
  project_name      = var.project_name
  common_tags       = local.common_tags
  vpc_id            = module.vpc.vpc_id
  public_subnet_ids = module.vpc.public_subnet_ids
  security_group_id = module.vpc.alb_sg_id
  ec2_instance_id   = module.ec2.instance_id
  ec2_instance_ip   = module.ec2.private_ip
  node_port         = var.node_port
}

# ----- Locals -----
locals {
  common_tags = {
    Project     = var.project_name
    Environment = "lab"
    ManagedBy   = "Terraform"
    Owner       = "Vo Le Truong Huy"
    StudentID   = "XB-DN26-102"
    Group       = "3"
  }
}
