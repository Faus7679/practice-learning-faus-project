# Terraform Deployment Template for Automated Jenkins CI/CD
# This template creates the complete infrastructure for automated builds

# Local values for deployment
locals {
  jenkins_url = var.enable_jenkins_server ? "http://${aws_eip.jenkins_eip[0].public_ip}:8080" : ""
  
  # Jenkins job configuration for automated builds
  jenkins_job_config = templatefile("${path.module}/templates/jenkins-job.xml.tpl", {
    github_url      = "https://github.com/${var.github_owner}/${var.github_repo}.git"
    github_owner    = var.github_owner
    github_repo     = var.github_repo
    jenkinsfile_path = "Jenkinsfile"
  })
}

# Enhanced GitHub webhook with better error handling
resource "github_repository_webhook" "jenkins_build_trigger" {
  count = var.enable_github_webhooks && var.enable_jenkins_server ? 1 : 0
  
  repository = var.github_repo

  configuration {
    url          = "${local.jenkins_url}/github-webhook/"
    content_type = "json"
    insecure_ssl = false
    secret       = random_password.webhook_secret[0].result
  }

  active = true

  events = [
    "push",
    "pull_request",
    "create",
    "delete"
  ]

  depends_on = [
    aws_instance.jenkins_server
  ]
}

# Webhook secret for security
resource "random_password" "webhook_secret" {
  count   = var.enable_github_webhooks && var.enable_jenkins_server ? 1 : 0
  length  = 32
  special = true
}

# Store webhook secret in AWS Systems Manager Parameter Store
resource "aws_ssm_parameter" "webhook_secret" {
  count = var.enable_github_webhooks && var.enable_jenkins_server ? 1 : 0
  
  name        = "/${var.project_name}/${var.environment}/webhook-secret"
  description = "GitHub webhook secret for Jenkins"
  type        = "SecureString"
  value       = random_password.webhook_secret[0].result

  tags = local.common_tags
}

# Enhanced Jenkins configuration with automated job setup
resource "null_resource" "jenkins_job_setup" {
  count = var.enable_jenkins_server ? 1 : 0
  
  depends_on = [
    aws_instance.jenkins_server,
    github_repository_webhook.jenkins_build_trigger
  ]

  # Trigger when Jenkins server or webhook changes
  triggers = {
    instance_id = aws_instance.jenkins_server[0].id
    webhook_id  = var.enable_github_webhooks ? github_repository_webhook.jenkins_build_trigger[0].id : "none"
    job_config  = local.jenkins_job_config
  }

  # Wait for Jenkins to be fully ready
  provisioner "remote-exec" {
    inline = [
      "echo 'Waiting for Jenkins to be ready...'",
      "timeout 300 bash -c 'until curl -f http://localhost:8080/login >/dev/null 2>&1; do echo \"Waiting for Jenkins...\"; sleep 10; done'",
      "echo 'Jenkins is ready!'"
    ]

    connection {
      type        = "ssh"
      user        = "ec2-user"
      private_key = var.key_pair_name != null ? file("~/.ssh/${var.key_pair_name}.pem") : null
      host        = aws_eip.jenkins_eip[0].public_ip
    }
  }

  # Create Jenkins job via CLI
  provisioner "remote-exec" {
    inline = [
      "echo 'Creating Jenkins job for automated builds...'",
      "sudo -u jenkins java -jar /var/lib/jenkins/jenkins-cli.jar -s http://localhost:8080/ -auth admin:admin123! create-job '${var.github_repo}-pipeline' < /tmp/job-config.xml || echo 'Job may already exist'",
      "echo 'Jenkins job setup completed!'"
    ]

    connection {
      type        = "ssh"
      user        = "ec2-user"
      private_key = var.key_pair_name != null ? file("~/.ssh/${var.key_pair_name}.pem") : null
      host        = aws_eip.jenkins_eip[0].public_ip
    }
  }

  # Upload job configuration
  provisioner "file" {
    content     = local.jenkins_job_config
    destination = "/tmp/job-config.xml"

    connection {
      type        = "ssh"
      user        = "ec2-user"
      private_key = var.key_pair_name != null ? file("~/.ssh/${var.key_pair_name}.pem") : null
      host        = aws_eip.jenkins_eip[0].public_ip
    }
  }
}

# CloudWatch Log Group for Jenkins build logs
resource "aws_cloudwatch_log_group" "jenkins_builds" {
  count             = var.enable_jenkins_server ? 1 : 0
  name              = "/aws/jenkins/${var.project_name}-${var.environment}/builds"
  retention_in_days = 14

  tags = local.common_tags
}

# SNS topic for build notifications
resource "aws_sns_topic" "build_notifications" {
  count = var.enable_jenkins_server ? 1 : 0
  name  = "${var.project_name}-${var.environment}-build-notifications"

  tags = local.common_tags
}

# Lambda function for processing build notifications
resource "aws_lambda_function" "build_processor" {
  count = var.enable_jenkins_server ? 1 : 0
  
  filename         = "build-processor.zip"
  function_name    = "${var.project_name}-${var.environment}-build-processor"
  role            = aws_iam_role.lambda_execution_role[0].arn
  handler         = "index.handler"
  source_code_hash = data.archive_file.lambda_zip[0].output_base64sha256
  runtime         = "python3.9"
  timeout         = 60

  environment {
    variables = {
      SNS_TOPIC_ARN = aws_sns_topic.build_notifications[0].arn
      PROJECT_NAME  = var.project_name
      ENVIRONMENT   = var.environment
    }
  }

  tags = local.common_tags
}

# Lambda deployment package
data "archive_file" "lambda_zip" {
  count = var.enable_jenkins_server ? 1 : 0
  
  type        = "zip"
  output_path = "build-processor.zip"
  
  source {
    content = templatefile("${path.module}/templates/lambda-handler.py.tpl", {
      sns_topic_arn = aws_sns_topic.build_notifications[0].arn
    })
    filename = "index.py"
  }
}

# IAM role for Lambda function
resource "aws_iam_role" "lambda_execution_role" {
  count = var.enable_jenkins_server ? 1 : 0
  
  name = "${var.project_name}-${var.environment}-lambda-execution"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = local.common_tags
}

# IAM policy for Lambda function
resource "aws_iam_role_policy_attachment" "lambda_execution_policy" {
  count      = var.enable_jenkins_server ? 1 : 0
  role       = aws_iam_role.lambda_execution_role[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Additional IAM policy for SNS access
resource "aws_iam_role_policy" "lambda_sns_policy" {
  count = var.enable_jenkins_server ? 1 : 0
  
  name = "${var.project_name}-${var.environment}-lambda-sns"
  role = aws_iam_role.lambda_execution_role[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sns:Publish"
        ]
        Resource = aws_sns_topic.build_notifications[0].arn
      }
    ]
  })
}

# Output deployment information
output "deployment_info" {
  value = {
    jenkins_url     = local.jenkins_url
    webhook_url     = var.enable_github_webhooks && var.enable_jenkins_server ? "${local.jenkins_url}/github-webhook/" : ""
    job_name        = "${var.github_repo}-pipeline"
    sns_topic_arn   = var.enable_jenkins_server ? aws_sns_topic.build_notifications[0].arn : ""
    log_group_name  = var.enable_jenkins_server ? aws_cloudwatch_log_group.jenkins_builds[0].name : ""
  }
  description = "Deployment information for automated Jenkins builds"
}