# ------------------------------------------------------------------------------
# Application Load Balancer
# ------------------------------------------------------------------------------

resource "aws_lb" "novelty_application_load_balancer" {
  name               = "${local.name}-alb"
  internal           = false
  load_balancer_type = "application"

  security_groups = [
    aws_security_group.novelty_alb_security_group.id
  ]

  subnets = aws_subnet.novelty_public_subnets[*].id

  tags = merge(local.common_tags, {
    Name = "${local.name}-alb"
  })
}


# ------------------------------------------------------------------------------
# Target Group
# ------------------------------------------------------------------------------

resource "aws_lb_target_group" "novelty_application_target_group" {
  name        = "${local.name}-tg"
  port        = var.container_port
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = aws_vpc.novelty_vpc.id

  health_check {
    enabled             = true
    path                = "/health"
    protocol            = "HTTP"
    port                = "traffic-port"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    matcher             = "200"
  }

  tags = merge(local.common_tags, {
    Name = "${local.name}-target-group"
  })
}


# ------------------------------------------------------------------------------
# HTTP Listener
#
# Redirect HTTP traffic to HTTPS.
# ------------------------------------------------------------------------------

resource "aws_lb_listener" "novelty_http_listener" {
  load_balancer_arn = aws_lb.novelty_application_load_balancer.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}


# ------------------------------------------------------------------------------
# HTTPS Listener
#
# The certificate ARN is supplied by the root module.
# ------------------------------------------------------------------------------

resource "aws_lb_listener" "novelty_https_listener" {
  load_balancer_arn = aws_lb.novelty_application_load_balancer.arn
  port              = 443
  protocol          = "HTTPS"

  ssl_policy      = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn = var.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.novelty_application_target_group.arn
  }
}
