variable "project_name" {
  description = "Name prefix for resources"
  type        = string
}

variable "common_tags" {
  description = "Common tags applied to all resources"
  type        = map(string)
}

variable "vpc_id" {
  description = "VPC ID where target group is created"
  type        = string
}

variable "public_subnet_ids" {
  description = "List of public subnet IDs for the ALB"
  type        = list(string)
}

variable "security_group_id" {
  description = "Security Group ID for the ALB"
  type        = string
}

variable "ec2_instance_id" {
  description = "EC2 instance ID to register with target group"
  type        = string
}

variable "ec2_instance_ip" {
  description = "EC2 private IP"
  type        = string
}

variable "node_port" {
  description = "NodePort exposed by K8s control plane on EC2 host"
  type        = number
}
