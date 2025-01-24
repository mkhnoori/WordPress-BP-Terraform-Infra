module "vpc" {
  source = "./modules/vpc"
}

module "alb" {
  source = "./modules/alb"
}

module "ecs" {
  source = "./modules/ecs"
}

module "efs" {
  source = "./modules/efs"
}

module "aurora" {
  source = "./modules/aurora"
}

module "elasticache" {
  source = "./modules/elasticache"
}

module "cloudfront" {
  source = "./modules/cloudfront"
}

module "waf" {
  source = "./modules/waf"
}

module "secrets_manager" {
  source = "./modules/secrets_manager"
}
provider "aws" {
  region = var.aws_region
}

module "wordpress" {
  source = "."
}

