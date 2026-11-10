# Blue Target Group
resource "aws_lb_target_group" "blue" {
  name        = "${var.app_name}-blue-tg"
  port        = var.instance_port
  protocol    = "HTTP"
  vpc_id      = data.aws_vpc.default.id
  target_type = "instance"

  health_check {
    healthy_threshold   = var.health_check_healthy_threshold
    unhealthy_threshold = var.health_check_unhealthy_threshold
    timeout             = var.health_check_timeout
    interval            = var.health_check_interval
    path                = var.health_check_path
    matcher             = "200"
    port                = "traffic-port"
  }

  stickiness {
    type            = "lb_cookie"
    enabled         = var.stickiness_enabled
    cookie_duration = var.stickiness_duration
  }

  tags = merge(
    var.tags,
    {
      Name  = "${var.app_name}-blue-tg"
      Color = "Blue"
    }
  )

  lifecycle {
    create_before_destroy = true
  }
}

# Green Target Group
resource "aws_lb_target_group" "green" {
  name        = "${var.app_name}-green-tg"
  port        = var.instance_port
  protocol    = "HTTP"
  vpc_id      = data.aws_vpc.default.id
  target_type = "instance"

  health_check {
    healthy_threshold   = var.health_check_healthy_threshold
    unhealthy_threshold = var.health_check_unhealthy_threshold
    timeout             = var.health_check_timeout
    interval            = var.health_check_interval
    path                = var.health_check_path
    matcher             = "200"
    port                = "traffic-port"
  }

  stickiness {
    type            = "lb_cookie"
    enabled         = var.stickiness_enabled
    cookie_duration = var.stickiness_duration
  }

  tags = merge(
    var.tags,
    {
      Name  = "${var.app_name}-green-tg"
      Color = "Green"
    }
  )

  lifecycle {
    create_before_destroy = true
  }
}
