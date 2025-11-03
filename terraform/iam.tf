# IAM Role for Jenkins EC2 instance
resource "aws_iam_role" "jenkins_role" {
  name = "${var.project_name}-${var.environment}-jenkins-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = local.common_tags
}

# IAM Policy for Jenkins to interact with AWS services
resource "aws_iam_policy" "jenkins_policy" {
  name        = "${var.project_name}-${var.environment}-jenkins-policy"
  description = "Policy for Jenkins to manage AWS resources"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:*",
          "cloudformation:*",
          "iam:PassRole",
          "iam:GetRole",
          "iam:ListRoles",
          "ec2:Describe*",
          "logs:*",
          "sts:GetCallerIdentity"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "iam:CreateRole",
          "iam:DeleteRole",
          "iam:AttachRolePolicy",
          "iam:DetachRolePolicy",
          "iam:PutRolePolicy",
          "iam:DeleteRolePolicy",
          "iam:GetRolePolicy",
          "iam:ListRolePolicies"
        ]
        Resource = [
          "arn:aws:iam::${local.account_id}:role/${var.project_name}-*"
        ]
      }
    ]
  })

  tags = local.common_tags
}

# Attach policy to role
resource "aws_iam_role_policy_attachment" "jenkins_policy_attachment" {
  role       = aws_iam_role.jenkins_role.name
  policy_arn = aws_iam_policy.jenkins_policy.arn
}

# Instance profile for Jenkins EC2
resource "aws_iam_instance_profile" "jenkins_profile" {
  name = "${var.project_name}-${var.environment}-jenkins-profile"
  role = aws_iam_role.jenkins_role.name

  tags = local.common_tags
}

# IAM User for Jenkins to use for AWS API calls (alternative to instance profile)
resource "aws_iam_user" "jenkins_user" {
  name = "${var.project_name}-${var.environment}-jenkins-user"
  path = "/"

  tags = local.common_tags
}

# Attach policy to Jenkins user
resource "aws_iam_user_policy_attachment" "jenkins_user_policy" {
  user       = aws_iam_user.jenkins_user.name
  policy_arn = aws_iam_policy.jenkins_policy.arn
}

# Access keys for Jenkins user
resource "aws_iam_access_key" "jenkins_user_key" {
  user = aws_iam_user.jenkins_user.name
}