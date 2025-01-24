module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 3.5"

  name                 = "wordpress-vpc"
  cidr                 = var.cidr
  azs                  = var.azs
  private_subnets      = var.private_subnets
  public_subnets       = var.public_subnets
  isolated_subnets     = var.isolated_subnets
  enable_nat_gateway   = true
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = var.name
  }
}
