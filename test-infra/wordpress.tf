### **Provider Configuration** (provider.tf)
provider "aws" {
  region = var.aws_region
}
/*
### **Backend Configuration** (backend.tf)
terraform {
  backend "s3" {
    bucket         = var.state_bucket
    key            = "wordpress-infra/terraform.tfstate"
    region         = var.aws_region
    dynamodb_table = var.lock_table
    encrypt        = true
  }
}
*/
### **Variables File** (variables.tf)
variable "aws_region" {
  description = "The AWS region to deploy resources."
  default     = "us-east-1"
}

variable "state_bucket" {
  description = "S3 bucket for Terraform state."
  default     = "your-terraform-state-bucket"
}

variable "lock_table" {
  description = "DynamoDB table for state locking."
  default     = "your-dynamodb-lock-table"
}

variable "db_username" {
  description = "Database username for Aurora."
  default     = "admin"
}

variable "db_password" {
  description = "Database password for Aurora."
  default     = "securepassword"
}

variable "environment" {
  description = "Environment name (e.g., dev, prod)."
  default     = "dev"
}

variable "client_vpn_cidr" {
  description = "Client VPN CIDR block."
  default     = "10.8.0.0/16"
}

### **Outputs File** (outputs.tf)
output "vpc_id" {
  description = "The ID of the created VPC."
  value       = module.vpc.vpc_id
}

output "alb_dns" {
  description = "DNS name of the ALB."
  value       = module.public_alb.this_alb_dns_name
}

output "ecs_cluster_name" {
  description = "Name of the ECS cluster."
  value       = aws_ecs_cluster.wordpress.name
}

output "efs_id" {
  description = "ID of the EFS file system."
  value       = module.efs.efs_id
}

output "aurora_endpoint" {
  description = "Aurora cluster endpoint."
  value       = module.aurora.endpoint
}

output "cloudfront_domain" {
  description = "CloudFront distribution domain name."
  value       = module.cloudfront.domain_name
}

### **Main Infrastructure** (main.tf)

# VPC Configuration
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 3.5"

  name                 = "wordpress-vpc"
  cidr                 = "10.0.0.0/16"
  azs                  = ["us-east-1a", "us-east-1b"]
  private_subnets      = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets       = ["10.0.3.0/24", "10.0.4.0/24"]
  isolated_subnets     = ["10.0.5.0/24", "10.0.6.0/24"]

  enable_nat_gateway   = true
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "wordpress-vpc"
  }
}

# Client VPN Configuration
resource "aws_ec2_client_vpn_endpoint" "main" {
  description       = "WordPress Client VPN"
  client_cidr_block = var.client_vpn_cidr
  server_certificate_arn = aws_acm_certificate.vpn_cert.arn

  authentication_options {
    type                        = "certificate-authentication"
    root_certificate_chain_arn  = aws_acm_certificate.vpn_cert.arn
  }

  connection_log_options {
    enabled = false
  }

  tags = {
    Name = "wordpress-client-vpn"
  }
}

resource "aws_ec2_client_vpn_target_network_association" "main" {
  client_vpn_endpoint_id = aws_ec2_client_vpn_endpoint.main.id
  subnet_id              = module.vpc.private_subnets[0]
}

resource "aws_security_group" "client_vpn" {
  name        = "client-vpn-sg"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.client_vpn_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Backup Configuration
module "efs_backup" {
  source = "terraform-aws-modules/backup/aws"

  name         = "wordpress-efs-backup"
  rule_name    = "daily-backup"
  schedule     = "cron(0 12 * * ? *)"

  resources = [
    aws_efs_file_system.wordpress.arn
  ]

  tags = {
    Environment = var.environment
  }
}

resource "aws_rds_cluster_snapshot" "aurora_backup" {
  db_cluster_identifier = module.aurora.this_rds_cluster_id
  db_cluster_snapshot_identifier = "aurora-backup-${var.environment}-$(timestamp())"

  tags = {
    Environment = var.environment
  }
}

# Public ALB Configuration
module "public_alb" {
  source  = "terraform-aws-modules/alb/aws"
  version = "~> 8.0"

  name               = "wordpress-public-alb"
  load_balancer_type = "application"
  vpc_id             = module.vpc.vpc_id
  subnets            = module.vpc.public_subnets

  security_groups = [aws_security_group.public_alb.id]

  listener_ssl_policy_default = "ELBSecurityPolicy-2016-08"

  https_listeners = [
    {
      port               = 443
      protocol           = "HTTPS"
      certificate_arn    = aws_acm_certificate.public_cert.arn
      default_action = {
        type             = "forward"
        target_group_arn = aws_lb_target_group.main.arn
      }
    }
  ]

  tags = {
    Environment = var.environment
  }
}

# ECS, EFS, Aurora, CloudFront, WAF, and other modules
module "ecs" {
  source = "./modules/ecs"
}

module "efs" {
  source = "./modules/efs"
}

module "aurora" {
  source = "./modules/aurora"
}

module "cloudfront" {
  source = "./modules/cloudfront"
}

module "waf" {
  source = "./modules/waf"
}

module "elasticache" {
  source = "./modules/elasticache"
}

module "secrets_manager" {
  source = "./modules/secrets_manager"
}

# Outputs and Cleanup Instructions
# (Refer to `outputs.tf` for all declared outputs)
