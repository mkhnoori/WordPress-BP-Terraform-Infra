output "vpc_id" {
  value = module.vpc.vpc_id
}

output "alb_dns" {
  value = module.public_alb.this_alb_dns_name
}

output "ecs_cluster_name" {
  value = aws_ecs_cluster.wordpress.name
}
