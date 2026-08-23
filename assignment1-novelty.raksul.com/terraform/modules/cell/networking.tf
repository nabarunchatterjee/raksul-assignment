# -------
# VPC
# -------

resource "aws_vpc" "novelty_vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(local.common_tags, {
    Name = "${local.name}-vpc"
  })
}


# -----------------
# Internet Gateway
# -----------------

resource "aws_internet_gateway" "novelty_internet_gateway" {
  vpc_id = aws_vpc.novelty_vpc.id

  tags = merge(local.common_tags, {
    Name = "${local.name}-internet-gateway"
  })
}


# ------------------------------------------------------------------------------
# Public Subnets
#
# Used by the Application Load Balancer and NAT Gateway.
# One subnet is created in each Availability Zone.
# ------------------------------------------------------------------------------

resource "aws_subnet" "novelty_public_subnets" {
  count = length(var.availability_zones)

  vpc_id            = aws_vpc.novelty_vpc.id
  availability_zone = var.availability_zones[count.index]

  cidr_block = cidrsubnet(
    var.vpc_cidr,
    8,
    count.index
  )

  map_public_ip_on_launch = true

  tags = merge(local.common_tags, {
    Name = "${local.name}-public-${var.availability_zones[count.index]}"
    Tier = "public"
  })
}


# ------------------------------------------------------------------------------
# Application Subnets
#
# ECS Fargate tasks run in these subnets.
# They do not receive public IP addresses.
# Outbound internet access is provided through the NAT Gateway.
# ------------------------------------------------------------------------------

resource "aws_subnet" "novelty_app_subnets" {
  count = length(var.availability_zones)

  vpc_id            = aws_vpc.novelty_vpc.id
  availability_zone = var.availability_zones[count.index]

  cidr_block = cidrsubnet(
    var.vpc_cidr,
    8,
    count.index + 10
  )

  map_public_ip_on_launch = false

  tags = merge(local.common_tags, {
    Name = "${local.name}-app-${var.availability_zones[count.index]}"
    Tier = "private-app"
  })
}


# ------------------------------------------------------------------------------
# Database Subnets
#
# RDS runs in isolated subnets.
# These subnets intentionally have no route to the Internet or NAT Gateway.
# ------------------------------------------------------------------------------

resource "aws_subnet" "novelty_database_subnets" {
  count = length(var.availability_zones)

  vpc_id            = aws_vpc.novelty_vpc.id
  availability_zone = var.availability_zones[count.index]

  cidr_block = cidrsubnet(
    var.vpc_cidr,
    8,
    count.index + 20
  )

  map_public_ip_on_launch = false

  tags = merge(local.common_tags, {
    Name = "${local.name}-database-${var.availability_zones[count.index]}"
    Tier = "database"
  })
}


# ------------------------------------------------------------------------------
# Public Route Table
#
# Public subnets route Internet traffic directly through the Internet Gateway.
# ------------------------------------------------------------------------------

resource "aws_route_table" "novelty_public_route_table" {
  vpc_id = aws_vpc.novelty_vpc.id

  tags = merge(local.common_tags, {
    Name = "${local.name}-public-route-table"
  })
}

resource "aws_route" "novelty_public_internet_route" {
  route_table_id         = aws_route_table.novelty_public_route_table.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.novelty_internet_gateway.id
}

resource "aws_route_table_association" "novelty_public_route_associations" {
  count = length(aws_subnet.novelty_public_subnets)

  subnet_id      = aws_subnet.novelty_public_subnets[count.index].id
  route_table_id = aws_route_table.novelty_public_route_table.id
}


# ------------------------------------------------------------------------------
# NAT Gateway
#
# A single NAT Gateway is used per cell to keep the assignment implementation
# simple and cost-conscious.
#
# For stronger AZ-level resilience, production deployments could provision
# one NAT Gateway per Availability Zone.
# ------------------------------------------------------------------------------

resource "aws_eip" "novelty_nat_eip" {
  domain = "vpc"

  tags = merge(local.common_tags, {
    Name = "${local.name}-nat-eip"
  })
}

resource "aws_nat_gateway" "novelty_nat_gateway" {
  allocation_id = aws_eip.novelty_nat_eip.id
  subnet_id     = aws_subnet.novelty_public_subnets[0].id

  depends_on = [
    aws_internet_gateway.novelty_internet_gateway
  ]

  tags = merge(local.common_tags, {
    Name = "${local.name}-nat-gateway"
  })
}


# ------------------------------------------------------------------------------
# Application Route Table
#
# Private application subnets use the NAT Gateway for outbound access.
# This allows ECS tasks to:
#
# - pull container images
# - access AWS APIs
# - call RAKSUL shared platform APIs
# ------------------------------------------------------------------------------

resource "aws_route_table" "novelty_app_route_table" {
  vpc_id = aws_vpc.novelty_vpc.id

  tags = merge(local.common_tags, {
    Name = "${local.name}-app-route-table"
  })
}

resource "aws_route" "novelty_app_internet_route" {
  route_table_id         = aws_route_table.novelty_app_route_table.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.novelty_nat_gateway.id
}

resource "aws_route_table_association" "novelty_app_route_associations" {
  count = length(aws_subnet.novelty_app_subnets)

  subnet_id      = aws_subnet.novelty_app_subnets[count.index].id
  route_table_id = aws_route_table.novelty_app_route_table.id
}


# ------------------------------------------------------------------------------
# Database Route Table
#
# Database subnets are intentionally isolated.
#
# The VPC's implicit local route allows communication with ECS tasks inside
# the VPC, while no default Internet route is configured.
# ------------------------------------------------------------------------------

resource "aws_route_table" "novelty_database_route_table" {
  vpc_id = aws_vpc.novelty_vpc.id

  tags = merge(local.common_tags, {
    Name = "${local.name}-database-route-table"
  })
}

resource "aws_route_table_association" "novelty_database_route_associations" {
  count = length(aws_subnet.novelty_database_subnets)

  subnet_id      = aws_subnet.novelty_database_subnets[count.index].id
  route_table_id = aws_route_table.novelty_database_route_table.id
}

