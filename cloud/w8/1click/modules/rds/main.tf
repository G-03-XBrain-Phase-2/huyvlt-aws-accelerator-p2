# DB Subnet Group - RDS MySQL requires at least 2 subnets in different AZs
resource "aws_db_subnet_group" "this" {
  name       = "${var.project_name}-db-subnet-group"
  subnet_ids = var.private_subnet_ids

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-db-subnet-group"
    }
  )
}

# RDS Security Group - Allow inbound 3306 ONLY from Web Server Security Group
resource "aws_security_group" "rds_sg" {
  name        = "${var.project_name}-rds-sg"
  description = "Access to RDS MySQL from Web Server only"
  vpc_id      = var.vpc_id

  ingress {
    description     = "MySQL from EC2 Web Server"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [var.web_server_sg_id]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-rds-sg"
    }
  )
}

# RDS MySQL DB Instance
resource "aws_db_instance" "this" {
  identifier           = "${var.project_name}-db"
  allocated_storage    = 20
  max_allocated_storage = 100
  engine               = "mysql"
  engine_version       = "8.0"
  instance_class       = "db.t3.micro"
  db_name              = var.db_name
  username             = var.db_username
  password             = var.db_password
  parameter_group_name = "default.mysql8.0"
  db_subnet_group_name = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  skip_final_snapshot  = true
  publicly_accessible  = false
  multi_az             = false

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-db-instance"
    }
  )
}
