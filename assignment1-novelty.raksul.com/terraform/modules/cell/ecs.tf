# ------------------------------------------------------------------------------
# ECS Cluster
# ------------------------------------------------------------------------------

resource "aws_ecs_cluster" "novelty_ecs_cluster" {
  name = "${local.name}-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = merge(local.common_tags, {
    Name = "${local.name}-cluster"
  })
}


# ------------------------------------------------------------------------------
# ECS Task Execution Role
# ------------------------------------------------------------------------------

resource "aws_iam_role" "novelty_ecs_task_execution_role" {
  name = "${local.name}-ecs-task-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }

        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "novelty_ecs_task_execution_policy" {
  role = aws_iam_role.novelty_ecs_task_execution_role.name

  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}


# ------------------------------------------------------------------------------
# ECS Task Role
# ------------------------------------------------------------------------------

resource "aws_iam_role" "novelty_ecs_task_role" {
  name = "${local.name}-ecs-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }

        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = local.common_tags
}


# ------------------------------------------------------------------------------
# CloudWatch Log Group
# ------------------------------------------------------------------------------

resource "aws_cloudwatch_log_group" "novelty_ecs_log_group" {
  name              = "/ecs/${local.name}"
  retention_in_days = 30

  tags = local.common_tags
}


# ------------------------------------------------------------------------------
# ECS Task Definition
# ------------------------------------------------------------------------------

data "aws_ecr_repository" "novelty_container_repository" {
  name = var.ecr_repository_name
}

resource "aws_ecs_task_definition" "novelty_ecs_task_definition" {
  family                   = "${local.name}-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]

  cpu    = var.ecs_cpu
  memory = var.ecs_memory

  execution_role_arn = aws_iam_role.novelty_ecs_task_execution_role.arn
  task_role_arn      = aws_iam_role.novelty_ecs_task_role.arn

  container_definitions = jsonencode([
    {
      name      = var.container_name
      image     = "${data.aws_ecr_repository.novelty_container_repository.repository_url}:${var.container_tag}"
      essential = true

      portMappings = [
        {
          containerPort = var.container_port
          hostPort      = var.container_port
          protocol      = "tcp"
        }
      ]

      environment = [
        {
          name  = "ENVIRONMENT"
          value = var.environment
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"

        options = {
          awslogs-group         = aws_cloudwatch_log_group.novelty_ecs_log_group.name
          awslogs-stream-prefix = "novelty"
        }
      }

      healthCheck = {
        command = [
          "CMD-SHELL",
          "curl -f http://localhost:${var.container_port}/health || exit 1"
        ]

        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 30
      }
    }
  ])

  tags = merge(local.common_tags, {
    Name = "${local.name}-task"
  })
}


# ------------------------------------------------------------------------------
# ECS Service
# ------------------------------------------------------------------------------

resource "aws_ecs_service" "novelty_ecs_service" {
  name            = "${local.name}-service"
  cluster         = aws_ecs_cluster.novelty_ecs_cluster.id
  task_definition = aws_ecs_task_definition.novelty_ecs_task_definition.arn

  desired_count = var.desired_count

  launch_type = "FARGATE"

  platform_version = "LATEST"

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  deployment_minimum_healthy_percent = 50
  deployment_maximum_percent         = 200

  network_configuration {
    subnets = aws_subnet.novelty_app_subnets[*].id

    security_groups = [
      aws_security_group.novelty_app_security_group.id
    ]

    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.novelty_application_target_group.arn
    container_name   = var.container_name
    container_port   = var.container_port
  }

  tags = merge(local.common_tags, {
    Name = "${local.name}-service"
  })

  depends_on = [
    aws_lb_listener.novelty_https_listener
  ]
}


# ------------------------------------------------------------------------------
# ECS Service Auto Scaling
# ------------------------------------------------------------------------------

resource "aws_appautoscaling_target" "novelty_ecs_scaling_target" {
  max_capacity       = var.ecs_max_capacity
  min_capacity       = var.ecs_min_capacity
  resource_id        = "service/${aws_ecs_cluster.novelty_ecs_cluster.name}/${aws_ecs_service.novelty_ecs_service.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "novelty_ecs_cpu_scaling_policy" {
  name               = "${local.name}-cpu-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.novelty_ecs_scaling_target.resource_id
  scalable_dimension = aws_appautoscaling_target.novelty_ecs_scaling_target.scalable_dimension
  service_namespace  = aws_appautoscaling_target.novelty_ecs_scaling_target.service_namespace

  target_tracking_scaling_policy_configuration {
    target_value = 60

    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }

    scale_in_cooldown  = 300
    scale_out_cooldown = 60
  }
}
