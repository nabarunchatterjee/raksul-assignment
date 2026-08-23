# ------------------------------------------------------------------------------
# ALB Security Group
#
# Internet-facing ALB accepts HTTPS traffic from the Internet.
# The ALB forwards application traffic to ECS.
# ------------------------------------------------------------------------------

resource "aws_security_group" "novelty_alb_security_group" {
  name        = "${local.name}-alb-sg"
  description = "Security group for the Novelty Application Load Balancer"
  vpc_id      = aws_vpc.novelty_vpc.id

  tags = merge(local.common_tags, {
    Name = "${local.name}-alb-sg"
  })
}

resource "aws_vpc_security_group_ingress_rule" "novelty_alb_https_ingress" {
  security_group_id = aws_security_group.novelty_alb_security_group.id

  description = "Allow HTTPS traffic from the Internet"

  ip_protocol = "tcp"
  from_port   = 443
  to_port     = 443

  cidr_ipv4 = "0.0.0.0/0"
}

resource "aws_vpc_security_group_egress_rule" "novelty_alb_egress" {
  security_group_id = aws_security_group.novelty_alb_security_group.id

  description = "Allow ALB to communicate with application targets"

  ip_protocol = "tcp"
  from_port   = var.container_port
  to_port     = var.container_port

  referenced_security_group_id = aws_security_group.novelty_app_security_group.id
}


# ------------------------------------------------------------------------------
# Application Security Group
#
# ECS accepts traffic ONLY from the ALB.
# ECS can make outbound HTTPS connections to external APIs.
# ------------------------------------------------------------------------------

resource "aws_security_group" "novelty_app_security_group" {
  name        = "${local.name}-app-sg"
  description = "Security group for Novelty ECS tasks"
  vpc_id      = aws_vpc.novelty_vpc.id

  tags = merge(local.common_tags, {
    Name = "${local.name}-app-sg"
  })
}

resource "aws_vpc_security_group_ingress_rule" "novelty_app_alb_ingress" {
  security_group_id = aws_security_group.novelty_app_security_group.id

  description = "Allow application traffic from the ALB"

  ip_protocol = "tcp"
  from_port   = var.container_port
  to_port     = var.container_port

  referenced_security_group_id = aws_security_group.novelty_alb_security_group.id
}

resource "aws_vpc_security_group_egress_rule" "novelty_app_https_egress" {
  security_group_id = aws_security_group.novelty_app_security_group.id

  description = "Allow ECS tasks to access external HTTPS APIs"

  ip_protocol = "tcp"
  from_port   = 443
  to_port     = 443

  cidr_ipv4 = "0.0.0.0/0"
}

resource "aws_vpc_security_group_egress_rule" "novelty_app_database_egress" {
  security_group_id = aws_security_group.novelty_app_security_group.id

  description = "Allow ECS tasks to connect to PostgreSQL"

  ip_protocol = "tcp"
  from_port   = 5432
  to_port     = 5432

  referenced_security_group_id = aws_security_group.novelty_database_security_group.id
}


# ------------------------------------------------------------------------------
# Database Security Group
#
# RDS accepts PostgreSQL connections ONLY from ECS tasks.
# There is no Internet ingress.
# ------------------------------------------------------------------------------

resource "aws_security_group" "novelty_database_security_group" {
  name        = "${local.name}-database-sg"
  description = "Security group for Novelty RDS PostgreSQL"
  vpc_id      = aws_vpc.novelty_vpc.id

  tags = merge(local.common_tags, {
    Name = "${local.name}-database-sg"
  })
}

resource "aws_vpc_security_group_ingress_rule" "novelty_database_app_ingress" {
  security_group_id = aws_security_group.novelty_database_security_group.id

  description = "Allow PostgreSQL connections from ECS tasks"

  ip_protocol = "tcp"
  from_port   = 5432
  to_port     = 5432

  referenced_security_group_id = aws_security_group.novelty_app_security_group.id
}

resource "aws_vpc_security_group_egress_rule" "novelty_database_egress" {
  security_group_id = aws_security_group.novelty_database_security_group.id

  description = "Allow database responses within the VPC"

  ip_protocol = "-1"

  cidr_ipv4 = var.vpc_cidr
}
