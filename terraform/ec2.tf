# Data source for latest Amazon Linux 2 AMI
data "aws_ami" "amazon_linux" {
  count = var.enable_jenkins_server ? 1 : 0
  
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

# User data script for Jenkins installation
locals {
  jenkins_user_data = var.enable_jenkins_server ? base64encode(templatefile("${path.module}/scripts/jenkins-setup.sh", {
    aws_region             = var.aws_region
    github_repo           = var.github_repo
    github_owner          = var.github_owner
    jenkins_artifacts_bucket = aws_s3_bucket.jenkins_artifacts.bucket
    deployment_bucket     = aws_s3_bucket.deployment_artifacts.bucket
    aws_access_key        = aws_iam_access_key.jenkins_user_key.id
    aws_secret_key        = aws_iam_access_key.jenkins_user_key.secret
  })) : ""
}

# Jenkins EC2 instance
resource "aws_instance" "jenkins_server" {
  count = var.enable_jenkins_server ? 1 : 0
  
  ami                    = data.aws_ami.amazon_linux[0].id
  instance_type          = var.jenkins_instance_type
  key_name              = var.key_pair_name != "" ? var.key_pair_name : null
  vpc_security_group_ids = [aws_security_group.jenkins_sg[0].id]
  subnet_id             = aws_subnet.jenkins_public_subnet[0].id
  iam_instance_profile  = aws_iam_instance_profile.jenkins_profile.name

  user_data = local.jenkins_user_data

  root_block_device {
    volume_type = "gp3"
    volume_size = 20
    encrypted   = true
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-jenkins-server"
    Type = "Jenkins"
  })
}

# Elastic IP for Jenkins server
resource "aws_eip" "jenkins_eip" {
  count = var.enable_jenkins_server ? 1 : 0
  
  instance = aws_instance.jenkins_server[0].id
  domain   = "vpc"

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-jenkins-eip"
  })
}