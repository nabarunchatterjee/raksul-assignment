output "alb_dns_name" {
  description = "DNS name of the Singapore Novelty ALB"
  value       = module.novelty_cell.alb_dns_name
}

output "vpc_id" {
  description = "Singapore Novelty VPC ID"
  value       = module.novelty_cell.vpc_id
}

output "ecs_cluster_name" {
  description = "Singapore Novelty ECS cluster name"
  value       = module.novelty_cell.ecs_cluster_name
}

output "s3_bucket_name" {
  description = "Singapore Novelty S3 assets bucket"
  value       = module.novelty_cell.s3_bucket_name
}

output "rds_endpoint" {
  description = "Singapore Novelty PostgreSQL endpoint"
  value       = module.novelty_cell.rds_endpoint
}
