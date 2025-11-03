# VPC for Jenkins infrastructure (if needed)
resource "aws_vpc" "jenkins_vpc" {
  count = var.enable_jenkins_server ? 1 : 0
  
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-jenkins-vpc"
  })
}

# Internet Gateway
resource "aws_internet_gateway" "jenkins_igw" {
  count = var.enable_jenkins_server ? 1 : 0
  
  vpc_id = aws_vpc.jenkins_vpc[0].id

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-jenkins-igw"
  })
}

# Public subnet for Jenkins
resource "aws_subnet" "jenkins_public_subnet" {
  count = var.enable_jenkins_server ? 1 : 0
  
  vpc_id                  = aws_vpc.jenkins_vpc[0].id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = true

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-jenkins-public-subnet"
  })
}

# Route table for public subnet
resource "aws_route_table" "jenkins_public_rt" {
  count = var.enable_jenkins_server ? 1 : 0
  
  vpc_id = aws_vpc.jenkins_vpc[0].id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.jenkins_igw[0].id
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-jenkins-public-rt"
  })
}

# Route table association
resource "aws_route_table_association" "jenkins_public_rta" {
  count = var.enable_jenkins_server ? 1 : 0
  
  subnet_id      = aws_subnet.jenkins_public_subnet[0].id
  route_table_id = aws_route_table.jenkins_public_rt[0].id
}

# Security group for Jenkins
resource "aws_security_group" "jenkins_sg" {
  count = var.enable_jenkins_server ? 1 : 0
  
  name        = "${var.project_name}-${var.environment}-jenkins-sg"
  description = "Security group for Jenkins server"
  vpc_id      = aws_vpc.jenkins_vpc[0].id

  # HTTP access for Jenkins
  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
  }

  # SSH access
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
  }

  # HTTPS access
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
  }

  # Outbound internet access
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-jenkins-sg"
  })
}