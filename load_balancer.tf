# Application Load Balancer
resource "aws_lb" "webapp_lb" {
  name               = "webapp-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.lb_sg.id]
  subnets            = aws_subnet.public_subnets[*].id

  enable_deletion_protection = false

  tags = {
    Name = "WebApp-LoadBalancer"
  }
}

# Target Group for Load Balancer
resource "aws_lb_target_group" "webapp_tg" {
  name        = "webapp-target-group"
  port        = var.app_port
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main_vpc.id
  target_type = "instance"

  health_check {
    interval            = 30
    path                = "/healthz"
    port                = "traffic-port"
    healthy_threshold   = 2
    unhealthy_threshold = 5  # Allow more failures before marking unhealthy
    timeout             = 10 # Give more time to respond
    protocol            = "HTTP"
    matcher             = "200-299" # Accept any 2xx response
  }

  tags = {
    Name = "WebApp-TargetGroup"
  }
}

# HTTP Listener for Load Balancer
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.webapp_lb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.webapp_tg.arn
  }
}

# Reference the imported certificate using a data source
data "aws_acm_certificate" "imported_cert" {
  domain      = "demo.ashaysaoji.com"
  statuses    = ["ISSUED"]
  most_recent = true
}

# HTTPS Listener for Load Balancer
resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.webapp_lb.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = data.aws_acm_certificate.imported_cert.arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.webapp_tg.arn
  }
}
