# ------------------------------------------------------------------------------
# RDS Subnet Group
# ------------------------------------------------------------------------------

resource "aws_db_subnet_group" "novelty_database_subnet_group" {
  name = "${local.name}-db-subnet-group"

  subnet_ids = aws_subnet.novelty_database_subnets[*].id

  tags = merge(local.common_tags, {
    Name = "${local.name}-db-subnet-group"
  })
}


# ------------------------------------------------------------------------------
# RDS PostgreSQL
# ------------------------------------------------------------------------------

resource "aws_db_instance" "novelty_database" {
  identifier = "${local.name}-postgres"

  engine         = "postgres"
  engine_version = var.postgres_engine_version
  instance_class = var.db_instance_class

  allocated_storage     = var.db_allocated_storage
  max_allocated_storage = var.db_max_allocated_storage
  storage_type          = "gp3"
  storage_encrypted     = true

  db_name                     = var.db_name
  username                    = var.db_username
  manage_master_user_password = true
  port                        = 5432

  db_subnet_group_name = aws_db_subnet_group.novelty_database_subnet_group.name

  vpc_security_group_ids = [
    aws_security_group.novelty_database_security_group.id
  ]

  publicly_accessible = false

  multi_az = true

  backup_retention_period = var.db_backup_retention_period
  backup_window           = "18:00-19:00"
  maintenance_window      = "sun:19:00-sun:20:00"

  auto_minor_version_upgrade = true
  deletion_protection        = var.db_deletion_protection
  skip_final_snapshot        = var.db_skip_final_snapshot

  copy_tags_to_snapshot = true

  tags = merge(local.common_tags, {
    Name = "${local.name}-postgres"
  })
}
