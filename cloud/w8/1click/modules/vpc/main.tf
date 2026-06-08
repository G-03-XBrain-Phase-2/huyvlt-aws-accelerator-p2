# Fetch availability zones dynamically
data "aws_availability_zones" "available" {
  state = "available"
}

# Create the VPC
resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-vpc"
    }
  )
}

# Create Public Subnet 1
resource "aws_subnet" "public_1" {
  vpc_id                  = aws_vpc.this.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, 1) # 10.0.1.0/24
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-public-subnet-1"
    }
  )
}

# Create Public Subnet 2
resource "aws_subnet" "public_2" {
  vpc_id                  = aws_vpc.this.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, 2) # 10.0.2.0/24
  availability_zone       = data.aws_availability_zones.available.names[1]
  map_public_ip_on_launch = true

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-public-subnet-2"
    }
  )
}

# Create Private Subnet 1
resource "aws_subnet" "private_1" {
  vpc_id            = aws_vpc.this.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, 10) # 10.0.10.0/24
  availability_zone = data.aws_availability_zones.available.names[0]

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-private-subnet-1"
    }
  )
}

# Create Private Subnet 2
resource "aws_subnet" "private_2" {
  vpc_id            = aws_vpc.this.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, 11) # 10.0.11.0/24
  availability_zone = data.aws_availability_zones.available.names[1]

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-private-subnet-2"
    }
  )
}

# Internet Gateway for Public Subnets
resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-igw"
    }
  )
}

# Public Route Table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-public-rt"
    }
  )
}

# Associate Public Subnet 1 with Public Route Table
resource "aws_route_table_association" "public_1" {
  subnet_id      = aws_subnet.public_1.id
  route_table_id = aws_route_table.public.id
}

# Associate Public Subnet 2 with Public Route Table
resource "aws_route_table_association" "public_2" {
  subnet_id      = aws_subnet.public_2.id
  route_table_id = aws_route_table.public.id
}

# Private Route Table
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.this.id

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-private-rt"
    }
  )
}

# Associate Private Subnet 1 with Private Route Table
resource "aws_route_table_association" "private_1" {
  subnet_id      = aws_subnet.private_1.id
  route_table_id = aws_route_table.private.id
}

# Associate Private Subnet 2 with Private Route Table
resource "aws_route_table_association" "private_2" {
  subnet_id      = aws_subnet.private_2.id
  route_table_id = aws_route_table.private.id
}
