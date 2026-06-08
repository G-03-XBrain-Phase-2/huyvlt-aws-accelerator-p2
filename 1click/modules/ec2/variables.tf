variable "project_name" {
  description = "Name prefix for resources"
  type        = string
}

variable "common_tags" {
  description = "Common tags applied to all resources"
  type        = map(string)
}

variable "subnet_id" {
  description = "Public subnet ID where the EC2 instance will run"
  type        = string
}

variable "security_group_id" {
  description = "Security Group ID to associate with the EC2 instance"
  type        = string
}

variable "key_name" {
  description = "Key pair name for SSH access"
  type        = string
}

variable "instance_type" {
  description = "Instance type for the EC2 instance"
  type        = string
}

variable "ami_id" {
  description = "AMI ID for the EC2 instance"
  type        = string
}

variable "app_port" {
  description = "Port the application container runs on"
  type        = number
}

variable "node_port" {
  description = "NodePort exposed by K8s control plane to EC2 host"
  type        = number
}
