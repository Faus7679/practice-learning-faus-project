# GitHub repository configuration
data "github_repository" "repo" {
  full_name = "${var.github_owner}/${var.github_repo}"
}

# GitHub webhook for Jenkins (if Jenkins server is created)
resource "github_repository_webhook" "jenkins_webhook" {
  count = var.enable_github_webhooks && var.enable_jenkins_server ? 1 : 0
  
  repository = var.github_repo

  configuration {
    url          = "http://${aws_eip.jenkins_eip[0].public_ip}:8080/github-webhook/"
    content_type = "json"
    insecure_ssl = false
  }

  active = true

  events = [
    "push",
    "pull_request"
  ]
}

# GitHub repository secrets for AWS credentials
resource "github_actions_secret" "aws_access_key_id" {
  repository      = var.github_repo
  secret_name     = "AWS_ACCESS_KEY_ID"
  plaintext_value = aws_iam_access_key.jenkins_user_key.id
}

resource "github_actions_secret" "aws_secret_access_key" {
  repository      = var.github_repo
  secret_name     = "AWS_SECRET_ACCESS_KEY"
  plaintext_value = aws_iam_access_key.jenkins_user_key.secret
}

resource "github_actions_secret" "aws_region" {
  repository      = var.github_repo
  secret_name     = "AWS_REGION"
  plaintext_value = var.aws_region
}

resource "github_actions_secret" "deployment_bucket" {
  repository      = var.github_repo
  secret_name     = "DEPLOYMENT_BUCKET"
  plaintext_value = aws_s3_bucket.deployment_artifacts.bucket
}

# GitHub branch protection (optional)
resource "github_branch_protection" "main_branch" {
  repository_id = data.github_repository.repo.node_id
  pattern      = "main"

  enforce_admins = false

  required_status_checks {
    strict = false
    contexts = [
      "Jenkins CI"
    ]
  }

  required_pull_request_reviews {
    dismiss_stale_reviews           = true
    required_approving_review_count = 1
  }
}