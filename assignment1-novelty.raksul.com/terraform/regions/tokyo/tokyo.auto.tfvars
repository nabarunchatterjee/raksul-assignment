name        = "novelty"
environment = "production"
region      = "ap-northeast-1"

vpc_cidr = "10.10.0.0/16"

availability_zones = [
  "ap-northeast-1a",
  "ap-northeast-1c"
]

certificate_domain = "novelty.raksul.com"

container_name      = "novelty"
ecr_repository_name = "novelty"
container_tag       = "v1.0.0"
container_port      = 8080

ecs_cpu          = 512
ecs_memory       = 1024
desired_count    = 2
ecs_min_capacity = 2
ecs_max_capacity = 10

db_name                    = "novelty"
db_username                = "novelty_admin"
postgres_engine_version    = "17"
db_instance_class          = "db.t4g.micro"
db_allocated_storage       = 20
db_max_allocated_storage   = 100
db_backup_retention_period = 7
db_deletion_protection     = true
db_skip_final_snapshot     = false
