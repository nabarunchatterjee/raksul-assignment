# ------------------------------------------------------------------------------
# Application
# ------------------------------------------------------------------------------

variable "name" {
  description = "Application name"
  type        = string
}

variable "environment" {
  description = "Deployment environment"
  type        = string
}

variable "region" {
  description = "AWS region"
  type        = string
}


# ------------------------------------------------------------------------------
# Networking
# ------------------------------------------------------------------------------

variable "vpc_cidr" {
  description = "CIDR block for the cell VPC"
  type        = string
}

variable "availability_zones" {
  description = "Availability Zones used by the cell"
  type        = list(string)
}


# ------------------------------------------------------------------------------
# Load Balancer
# ------------------------------------------------------------------------------

variable "certificate_domain" {
  description = "Domain name of the existing ACM certificate"
  type        = string
}

# ------------------------------------------------------------------------------
# ECS
# ------------------------------------------------------------------------------

variable "container_name" {
  description = "Application container name"
  type        = string
}

variable "ecr_repository_name" {
  description = "ECR repo for the Novelty application"
  type        = string
}

variable "container_tag" {
  description = "Tag for container image"
  type        = string
}

variable "container_port" {
  description = "Application container port"
  type        = number
}

variable "ecs_cpu" {
  description = "CPU units allocated to each ECS task"
  type        = number
}

variable "ecs_memory" {
  description = "Memory allocated to each ECS task in MB"
  type        = number
}

variable "desired_count" {
  description = "Initial number of ECS tasks"
  type        = number
}

variable "ecs_min_capacity" {
  description = "Minimum number of ECS tasks"
  type        = number
}

variable "ecs_max_capacity" {
  description = "Maximum number of ECS tasks"
  type        = number
}


# ------------------------------------------------------------------------------
# RDS
# ------------------------------------------------------------------------------

variable "db_name" {
  description = "PostgreSQL database name"
  type        = string
}

variable "db_username" {
  description = "PostgreSQL master username"
  type        = string
  sensitive   = true
}

variable "postgres_engine_version" {
  description = "PostgreSQL engine version"
  type        = string
}

variable "db_instance_class" {
  description = "RDS instance class"
  type        = string
}

variable "db_allocated_storage" {
  description = "Initial RDS storage in GB"
  type        = number
}

variable "db_max_allocated_storage" {
  description = "Maximum RDS storage in GB"
  type        = number
}

variable "db_backup_retention_period" {
  description = "RDS backup retention period in days"
  type        = number
}

variable "db_deletion_protection" {
  description = "Whether RDS deletion protection is enabled"
  type        = bool
}

variable "db_skip_final_snapshot" {
  description = "Whether to skip the final RDS snapshot"
  type        = bool
}
