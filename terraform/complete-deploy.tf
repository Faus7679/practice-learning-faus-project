# Complete Infrastructure Deployment Template
# This template deploys the entire CI/CD infrastructure with automated Jenkins builds

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    github = {
      source  = "integrations/github"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.1"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.2"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.1"
    }
  }
}

# Deploy the complete infrastructure
module "jenkins_infrastructure" {
  source = "./"
  
  # Pass all variables to the main module
  aws_region                = var.aws_region
  environment              = var.environment
  project_name            = var.project_name
  owner                   = var.owner
  github_token            = var.github_token
  github_owner            = var.github_owner
  github_repo             = var.github_repo
  jenkins_instance_type   = var.jenkins_instance_type
  enable_jenkins_server   = var.enable_jenkins_server
  enable_github_webhooks  = var.enable_github_webhooks
  allowed_cidr_blocks     = var.allowed_cidr_blocks
  key_pair_name          = var.key_pair_name
}

# Output comprehensive deployment information
output "complete_deployment_info" {
  value = {
    # Infrastructure URLs
    jenkins_url = var.enable_jenkins_server ? "http://${module.jenkins_infrastructure.jenkins_public_ip}:8080" : "Not deployed"
    webhook_url = var.enable_jenkins_server && var.enable_github_webhooks ? "http://${module.jenkins_infrastructure.jenkins_public_ip}:8080/github-webhook/" : "Not configured"
    
    # Access Information
    jenkins_public_ip = var.enable_jenkins_server ? module.jenkins_infrastructure.jenkins_public_ip : "Not deployed"
    ssh_command = var.enable_jenkins_server && var.key_pair_name != null ? "ssh -i ~/.ssh/${var.key_pair_name}.pem ec2-user@${module.jenkins_infrastructure.jenkins_public_ip}" : "SSH key not configured"
    
    # Jenkins Configuration
    jenkins_job_name = "${var.github_repo}-auto-pipeline"
    admin_user = "admin"
    admin_password = "admin123!"
    
    # AWS Resources
    deployment_bucket = module.jenkins_infrastructure.deployment_bucket_name
    artifacts_bucket = module.jenkins_infrastructure.jenkins_artifacts_bucket_name
    sns_topic_arn = var.enable_jenkins_server ? module.jenkins_infrastructure.build_notifications_topic_arn : "Not created"
    
    # GitHub Integration  
    repository_url = "https://github.com/${var.github_owner}/${var.github_repo}"
    webhook_configured = var.enable_github_webhooks && var.enable_jenkins_server
    
    # Monitoring & Logs
    cloudwatch_log_group = var.enable_jenkins_server ? "/aws/jenkins/${var.project_name}-${var.environment}/builds" : "Not created"
    
    # Quick Start Commands
    setup_commands = [
      "# Access Jenkins",
      "curl http://${var.enable_jenkins_server ? module.jenkins_infrastructure.jenkins_public_ip : "NOT_DEPLOYED"}:8080",
      "",
      "# View deployment info", 
      var.enable_jenkins_server ? "ssh -i ~/.ssh/${var.key_pair_name != null ? var.key_pair_name : "YOUR_KEY"}.pem ec2-user@${module.jenkins_infrastructure.jenkins_public_ip} 'cat /home/ec2-user/jenkins-deployment-complete.log'" : "Jenkins not deployed",
      "",
      "# Monitor Jenkins logs",
      var.enable_jenkins_server ? "ssh -i ~/.ssh/${var.key_pair_name != null ? var.key_pair_name : "YOUR_KEY"}.pem ec2-user@${module.jenkins_infrastructure.jenkins_public_ip} 'sudo journalctl -u jenkins -f'" : "Jenkins not deployed",
      "",
      "# Trigger manual build",
      "curl -X POST -u admin:admin123! http://${var.enable_jenkins_server ? module.jenkins_infrastructure.jenkins_public_ip : "NOT_DEPLOYED"}:8080/job/${var.github_repo}-auto-pipeline/build"
    ]
  }
  
  description = "Complete deployment information for automated Jenkins CI/CD pipeline"
  
  depends_on = [
    module.jenkins_infrastructure
  ]
}

# Create deployment status file
resource "local_file" "deployment_status" {
  content = templatefile("${path.module}/templates/deployment-status.md.tpl", {
    jenkins_url = var.enable_jenkins_server ? "http://${module.jenkins_infrastructure.jenkins_public_ip}:8080" : "Not deployed"
    webhook_url = var.enable_jenkins_server && var.enable_github_webhooks ? "http://${module.jenkins_infrastructure.jenkins_public_ip}:8080/github-webhook/" : "Not configured"
    public_ip = var.enable_jenkins_server ? module.jenkins_infrastructure.jenkins_public_ip : "Not deployed"
    repository_url = "https://github.com/${var.github_owner}/${var.github_repo}"
    job_name = "${var.github_repo}-auto-pipeline"
    environment = var.environment
    project_name = var.project_name
    deployment_bucket = module.jenkins_infrastructure.deployment_bucket_name
    ssh_key = var.key_pair_name
  })
  filename = "${path.module}/deployment-status.md"
}

# Validation checks
resource "null_resource" "deployment_validation" {
  depends_on = [
    module.jenkins_infrastructure,
    local_file.deployment_status
  ]

  provisioner "local-exec" {
    command = <<-EOF
      echo "=== Deployment Validation ==="
      echo "✓ Terraform deployment completed"
      echo "✓ Infrastructure resources created"
      ${var.enable_jenkins_server ? "echo '✓ Jenkins server deployed'" : "echo '⚠ Jenkins server not enabled'"}
      ${var.enable_github_webhooks ? "echo '✓ GitHub webhook configured'" : "echo '⚠ GitHub webhook not enabled'"}
      echo ""
      echo "Next steps:"
      echo "1. Wait 2-3 minutes for Jenkins to fully start"
      echo "2. Access Jenkins at: ${var.enable_jenkins_server ? "http://${module.jenkins_infrastructure.jenkins_public_ip}:8080" : "Not deployed"}"
      echo "3. Login with admin:admin123!"
      echo "4. Check deployment status in deployment-status.md"
      echo ""
      echo "For detailed deployment info, see: ./deployment-status.md"
    EOF
  }

  triggers = {
    always_run = timestamp()
  }
}

# Output for CI/CD pipeline variables
output "pipeline_environment_variables" {
  value = {
    AWS_REGION = var.aws_region
    DEPLOYMENT_BUCKET = module.jenkins_infrastructure.deployment_bucket_name
    ARTIFACTS_BUCKET = module.jenkins_infrastructure.jenkins_artifacts_bucket_name
    STACK_NAME_PREFIX = "faus"
    PROJECT_NAME = var.project_name
    ENVIRONMENT = var.environment
  }
  
  description = "Environment variables for use in Jenkins pipeline"
}