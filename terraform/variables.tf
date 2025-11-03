# Variables for Terraform configuration
variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod."
  }
}

variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "practice-learning-faus-project"
}

variable "owner" {
  description = "Owner of the resources"
  type        = string
  default     = "Faus7679"
}

variable "github_token" {
  description = "GitHub personal access token"
  type        = string
  sensitive   = true
}

variable "github_owner" {
  description = "GitHub repository owner"
  type        = string
  default     = "Faus7679"
}

variable "github_repo" {
  description = "GitHub repository name"
  type        = string
  default     = "practice-learning-faus-project"
}

variable "jenkins_instance_type" {
  description = "EC2 instance type for Jenkins server"
  type        = string
  default     = "t3.medium"
}

variable "allowed_cidr_blocks" {
  description = "CIDR blocks allowed to access Jenkins"
  type        = list(string)
  default     = ["0.0.0.0/0"]  # Change this to your IP range for security
}

variable "key_pair_name" {
  description = "AWS Key Pair name for EC2 instances"
  type        = string
  default     = ""
}

variable "enable_jenkins_server" {
  description = "Whether to create Jenkins server infrastructure"
  type        = bool
  default     = true
}

variable "enable_github_webhooks" {
  description = "Whether to setup GitHub webhooks for Jenkins"
  type        = bool
  default     = true
}