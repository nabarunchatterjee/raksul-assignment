module "novelty_cell" {
  source = "../../modules/cell"

  name        = var.name
  environment = var.environment

  vpc_cidr           = var.vpc_cidr
  availability_zones = var.availability_zones

  certificate_arn = var.certificate_arn

  container_name  = var.container_name
  container_image = var.container_image
  container_port  = var.container_port

  ecs_cpu          = var.ecs_cpu
  ecs_memory       = var.ecs_memory
  desired_count    = var.desired_count
  ecs_min_capacity = var.ecs_min_capacity
  ecs_max_capacity = var.ecs_max_capacity

  db_name                    = var.db_name
  db_username                = var.db_username
  db_password                = var.db_password
  postgres_engine_version    = var.postgres_engine_version
  db_instance_class          = var.db_instance_class
  db_allocated_storage       = var.db_allocated_storage
  db_max_allocated_storage   = var.db_max_allocated_storage
  db_backup_retention_period = var.db_backup_retention_period
  db_deletion_protection     = var.db_deletion_protection
  db_skip_final_snapshot     = var.db_skip_final_snapshot
}
