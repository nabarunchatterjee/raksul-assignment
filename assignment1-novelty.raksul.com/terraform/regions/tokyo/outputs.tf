output "alb_dns_name" {
  description = "DNS name of the Tokyo Novelty ALB"
  value       = module.novelty_cell.alb_dns_name
}

output "vpc_id" {
  description = "Tokyo Novelty VPC ID"
  value       = module.novelty_cell.vpc_id
}

output "ecs_cluster_name" {
  description = "Tokyo Novelty ECS cluster name"
  value       = module.novelty_cell.ecs_cluster_name
}

output "s3_bucket_name" {
  description = "Tokyo Novelty S3 assets bucket"
  value       = module.novelty_cell.s3_bucket_name
}

output "rds_endpoint" {
  description = "Tokyo Novelty PostgreSQL endpoint"
  value       = module.novelty_cell.rds_endpoint
}
