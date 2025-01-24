terraform {
  backend "s3" {
    bucket         = var.state_bucket
    key            = "wordpress-infra/terraform.tfstate"
    region         = var.aws_region
    dynamodb_table = var.lock_table
    encrypt        = true
  }
}
