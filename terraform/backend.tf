# Terraform Backend Configuration
# Uncomment and modify this section if you want to use remote state storage

# terraform {
#   backend "s3" {
#     bucket         = "your-terraform-state-bucket"
#     key            = "jenkins-pipeline/terraform.tfstate"
#     region         = "us-east-1"
#     encrypt        = true
#     dynamodb_table = "terraform-state-lock"
#   }
# }

# Local backend (default) - stores state file locally
# No additional configuration needed for local backend