variable "name" {
  description = "Application name"
  type        = string
}

variable "environment" {
  description = "Deployment environment"
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

  validation {
    condition     = length(var.availability_zones) >= 2
    error_message = "A cell must span at least two Availability Zones."
  }
}


# ------------------------------------------------------------------------------
# ECS
# ------------------------------------------------------------------------------

variable "container_name" {
  description = "Name of the application container"
  type        = string
  default     = "novelty"
}

variable "container_image" {
  description = "Docker image for the Novelty application"
  type        = string
}

variable "container_port" {
  description = "Port exposed by the Novelty application"
  type        = number
  default     = 8080

  validation {
    condition     = var.container_port >= 1 && var.container_port <= 65535
    error_message = "Container port must be between 1 and 65535."
  }
}

variable "ecs_cpu" {
  description = "CPU units allocated to each ECS task"
  type        = number
  default     = 512
}

variable "ecs_memory" {
  description = "Memory in MB allocated to each ECS task"
  type        = number
  default     = 1024
}

variable "desired_count" {
  description = "Initial number of ECS tasks"
  type        = number
  default     = 2

  validation {
    condition     = var.desired_count >= 2
    error_message = "At least two ECS tasks are required for high availability."
  }
}

variable "ecs_min_capacity" {
  description = "Minimum number of ECS tasks for autoscaling"
  type        = number
  default     = 2
}

variable "ecs_max_capacity" {
  description = "Maximum number of ECS tasks for autoscaling"
  type        = number
  default     = 10
}


# ------------------------------------------------------------------------------
# Application Load Balancer
# ------------------------------------------------------------------------------

variable "certificate_arn" {
  description = "ARN of the ACM certificate used by the HTTPS ALB listener"
  type        = string
}


# ------------------------------------------------------------------------------
# RDS PostgreSQL
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
  default     = "17"
}

variable "db_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t4g.micro"
}

variable "db_allocated_storage" {
  description = "Initial RDS storage in GB"
  type        = number
  default     = 20
}

variable "db_max_allocated_storage" {
  description = "Maximum RDS storage in GB"
  type        = number
  default     = 100
}

variable "db_backup_retention_period" {
  description = "Number of days to retain automated RDS backups"
  type        = number
  default     = 7
}

variable "db_deletion_protection" {
  description = "Whether RDS deletion protection is enabled"
  type        = bool
  default     = true
}

variable "db_skip_final_snapshot" {
  description = "Whether to skip the final RDS snapshot on deletion"
  type        = bool
  default     = false
}

