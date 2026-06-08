# Capstone Week 8 Final Project Root main.tf
# Provisions: VPC + S3 + EC2 + RDS MySQL + Security Groups + IAM

# Fetch the latest Amazon Linux 2023 AMI dynamically
data "aws_ssm_parameter" "al2023_ami" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

# Local tags and details
locals {
  common_tags = {
    Project     = var.project_name
    Environment = "capstone"
    ManagedBy   = "Terraform"
    Owner       = "Vo Le Truong Huy"
    StudentID   = "XB-DN26-102"
    Group       = "3"
  }
}

# Network Module
module "vpc" {
  source       = "./modules/vpc"
  project_name = var.project_name
  vpc_cidr     = var.vpc_cidr
  common_tags  = local.common_tags
}

# S3 Storage Module
module "s3" {
  source       = "./modules/s3"
  project_name = var.project_name
  bucket_name  = var.static_bucket_name
  common_tags  = local.common_tags
}

# EC2 Web Server Module
module "ec2" {
  source         = "./modules/ec2"
  project_name   = var.project_name
  vpc_id         = module.vpc.vpc_id
  subnet_id      = module.vpc.public_subnet_1_id
  instance_type  = var.instance_type
  ami_id         = data.aws_ssm_parameter.al2023_ami.value
  s3_bucket_name = module.s3.bucket_name
  s3_bucket_arn  = module.s3.bucket_arn
  db_host        = module.rds.db_endpoint
  db_name        = module.rds.db_name
  db_username    = module.rds.db_username
  db_password    = var.db_password
  aws_region       = var.aws_region
  common_tags      = local.common_tags
  s3_objects_ready = module.s3.s3_objects_ready
}

# RDS MySQL Module
module "rds" {
  source             = "./modules/rds"
  project_name       = var.project_name
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
  db_username        = var.db_username
  db_password        = var.db_password
  db_name            = var.db_name
  web_server_sg_id   = module.ec2.security_group_id
  common_tags        = local.common_tags
}
