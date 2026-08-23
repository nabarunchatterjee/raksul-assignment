output "alb_dns_name" {
  description = "DNS name of the Novelty ALB"
  value       = aws_lb.novelty_application_load_balancer.dns_name
}

output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.novelty_vpc.id
}

output "ecs_cluster_name" {
  description = "ECS cluster name"
  value       = aws_ecs_cluster.novelty_ecs_cluster.name
}

output "s3_bucket_name" {
  description = "S3 bucket containing Novelty assets"
  value       = aws_s3_bucket.novelty_assets_bucket.bucket
}

output "rds_endpoint" {
  description = "RDS endpoint"
  value       = aws_db_instance.novelty_database.address
}
