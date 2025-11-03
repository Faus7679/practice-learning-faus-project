# S3 Buckets for Jenkins artifacts and CloudFormation templates
resource "aws_s3_bucket" "jenkins_artifacts" {
  bucket = "${var.project_name}-${var.environment}-jenkins-artifacts-${random_string.bucket_suffix.result}"

  tags = merge(local.common_tags, {
    Name        = "${var.project_name}-${var.environment}-jenkins-artifacts"
    Description = "S3 bucket for Jenkins build artifacts"
  })
}

# S3 bucket for deployment artifacts
resource "aws_s3_bucket" "deployment_artifacts" {
  bucket = "${var.project_name}-${var.environment}-deployments-${random_string.bucket_suffix.result}"

  tags = merge(local.common_tags, {
    Name        = "${var.project_name}-${var.environment}-deployments"
    Description = "S3 bucket for CloudFormation deployment artifacts"
  })
}

# Random string for unique bucket names
resource "random_string" "bucket_suffix" {
  length  = 8
  special = false
  upper   = false
}

# S3 bucket versioning
resource "aws_s3_bucket_versioning" "jenkins_artifacts_versioning" {
  bucket = aws_s3_bucket.jenkins_artifacts.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_versioning" "deployment_artifacts_versioning" {
  bucket = aws_s3_bucket.deployment_artifacts.id
  versioning_configuration {
    status = "Enabled"
  }
}

# S3 bucket encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "jenkins_artifacts_encryption" {
  bucket = aws_s3_bucket.jenkins_artifacts.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "deployment_artifacts_encryption" {
  bucket = aws_s3_bucket.deployment_artifacts.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# S3 bucket public access block
resource "aws_s3_bucket_public_access_block" "jenkins_artifacts_pab" {
  bucket = aws_s3_bucket.jenkins_artifacts.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_public_access_block" "deployment_artifacts_pab" {
  bucket = aws_s3_bucket.deployment_artifacts.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# S3 bucket lifecycle configuration
resource "aws_s3_bucket_lifecycle_configuration" "jenkins_artifacts_lifecycle" {
  bucket = aws_s3_bucket.jenkins_artifacts.id

  rule {
    id     = "cleanup_old_artifacts"
    status = "Enabled"

    expiration {
      days = 30
    }

    noncurrent_version_expiration {
      noncurrent_days = 7
    }
  }
}