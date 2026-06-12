# Terraform — EC2 + IAM Role cho CloudWatch Agent Lab
# Provider: AWS

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  required_version = ">= 1.5.0"
}

provider "aws" {
  region = var.aws_region
}

# ── Data Sources ──────────────────────────────────────────────────────────────
data "aws_ami" "amazon_linux_2" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# ── IAM Role cho CloudWatch Agent ────────────────────────────────────────────
resource "aws_iam_role" "cloudwatch_agent_role" {
  name        = "${var.project_name}-CloudWatch-Role"
  description = "IAM Role for EC2 to push metrics/logs to CloudWatch"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = var.common_tags
}

resource "aws_iam_role_policy_attachment" "cloudwatch_agent_policy" {
  role       = aws_iam_role.cloudwatch_agent_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_instance_profile" "cloudwatch_agent_profile" {
  name = "${var.project_name}-CloudWatch-Profile"
  role = aws_iam_role.cloudwatch_agent_role.name

  tags = var.common_tags
}

# ── Security Group ────────────────────────────────────────────────────────────
resource "aws_security_group" "lab_sg" {
  name        = "${var.project_name}-sg"
  description = "Security group for CloudWatch Agent Lab EC2"

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.allowed_ssh_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-sg"
  })
}

# ── EC2 Instance ──────────────────────────────────────────────────────────────
resource "aws_instance" "lab_ec2" {
  ami                    = data.aws_ami.amazon_linux_2.id
  instance_type          = var.instance_type
  key_name               = var.key_pair_name
  iam_instance_profile   = aws_iam_instance_profile.cloudwatch_agent_profile.name
  vpc_security_group_ids = [aws_security_group.lab_sg.id]

  # User data: tự động cài agent khi khởi động instance
  user_data = base64encode(<<-EOF
    #!/bin/bash
    # Cài đặt CloudWatch Agent
    yum install -y amazon-cloudwatch-agent

    # Tạo thư mục log cho app demo
    mkdir -p /var/log/app

    # Tạo config mẫu tối giản
    cat > /opt/aws/amazon-cloudwatch-agent/bin/config.json << 'CWCONFIG'
    {
      "agent": {
        "metrics_collection_interval": 60,
        "run_as_user": "root"
      },
      "metrics": {
        "metrics_collected": {
          "mem": {
            "measurement": ["mem_used_percent"],
            "metrics_collection_interval": 60
          },
          "disk": {
            "measurement": ["used_percent"],
            "metrics_collection_interval": 60,
            "resources": ["/"]
          }
        },
        "namespace": "CWAgent"
      }
    }
    CWCONFIG

    # Khởi động Agent
    /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
        -a fetch-config -m ec2 -s \
        -c file:/opt/aws/amazon-cloudwatch-agent/bin/config.json

    systemctl enable amazon-cloudwatch-agent
    systemctl start amazon-cloudwatch-agent
  EOF
  )

  root_block_device {
    volume_size           = 20
    volume_type           = "gp3"
    delete_on_termination = true
  }

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-ec2"
  })
}
