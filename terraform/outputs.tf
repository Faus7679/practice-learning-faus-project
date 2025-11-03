# Output values
output "jenkins_server_public_ip" {
  description = "Public IP address of the Jenkins server"
  value       = var.enable_jenkins_server ? aws_eip.jenkins_eip[0].public_ip : "N/A - Jenkins server not created"
}

output "jenkins_server_url" {
  description = "URL to access Jenkins server"
  value       = var.enable_jenkins_server ? "http://${aws_eip.jenkins_eip[0].public_ip}:8080" : "N/A - Jenkins server not created"
}

output "jenkins_artifacts_bucket" {
  description = "S3 bucket for Jenkins artifacts"
  value       = aws_s3_bucket.jenkins_artifacts.bucket
}

output "deployment_artifacts_bucket" {
  description = "S3 bucket for deployment artifacts"
  value       = aws_s3_bucket.deployment_artifacts.bucket
}

output "aws_access_key_id" {
  description = "AWS Access Key ID for Jenkins"
  value       = aws_iam_access_key.jenkins_user_key.id
  sensitive   = true
}

output "aws_secret_access_key" {
  description = "AWS Secret Access Key for Jenkins"
  value       = aws_iam_access_key.jenkins_user_key.secret
  sensitive   = true
}

output "jenkins_iam_role_arn" {
  description = "IAM Role ARN for Jenkins"
  value       = aws_iam_role.jenkins_role.arn
}

output "vpc_id" {
  description = "VPC ID where Jenkins is deployed"
  value       = var.enable_jenkins_server ? aws_vpc.jenkins_vpc[0].id : "N/A - VPC not created"
}

output "subnet_id" {
  description = "Subnet ID where Jenkins is deployed"
  value       = var.enable_jenkins_server ? aws_subnet.jenkins_public_subnet[0].id : "N/A - Subnet not created"
}

output "security_group_id" {
  description = "Security Group ID for Jenkins"
  value       = var.enable_jenkins_server ? aws_security_group.jenkins_sg[0].id : "N/A - Security Group not created"
}

output "github_webhook_url" {
  description = "GitHub webhook URL"
  value       = var.enable_github_webhooks && var.enable_jenkins_server ? github_repository_webhook.jenkins_webhook[0].url : "N/A - Webhook not created"
}

output "repository_clone_url" {
  description = "GitHub repository clone URL"
  value       = "https://github.com/${var.github_owner}/${var.github_repo}.git"
}

output "jenkins_initial_setup_info" {
  description = "Information for Jenkins initial setup"
  value = var.enable_jenkins_server ? {
    url                = "http://${aws_eip.jenkins_eip[0].public_ip}:8080"
    default_admin_user = "admin"
    default_admin_pass = "admin123!"
    ssh_command        = "ssh -i <your-key>.pem ec2-user@${aws_eip.jenkins_eip[0].public_ip}"
    setup_info_file    = "/home/ec2-user/jenkins-setup-complete.log"
  } : "N/A - Jenkins server not created"
}