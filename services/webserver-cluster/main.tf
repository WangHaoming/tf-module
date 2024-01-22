resource "aws_launch_configuration" "example" {
  image_id        = "ami-0c55b159cbfafe1f0"
  instance_type   = var.instance_type
  security_groups = [aws_security_group.instance.id]
  user_data       = data.template_file.user_data.rendered

  # Required when using a launch configuration with an auto scaling group.
  # https://www.terraform.io/docs/providers/aws/r/launch_configuration.html
  lifecycle {
    create_before_destroy = true
  }
}


data "template_file" "user_data" {
  template = file("${path.module}/user-data.sh")

  vars = {
    server_port = var.server_port
    # db_address  = data.terraform_remote_state.db.outputs.address
    # db_port     = data.terraform_remote_state.db.outputs.port

    db_address = "data.terraform_remote_state.db.outputs.address"
    db_port    = "data.terraform_remote_state.db.outputs.port"
  }
}


data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

resource "aws_lb" "example" {
  name               = var.cluster_name
  load_balancer_type = "application"
  subnets            = data.aws_subnets.default.ids
  security_groups    = [aws_security_group.instance.id]
}


resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.example.arn
  port              = local.http_port
  protocol          = "HTTP"

  # By default, return a simple 404 page
  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      message_body = "404: page not found"
      status_code  = 404
    }
  }

}



resource "aws_lb_listener_rule" "example" {
  listener_arn = aws_lb_listener.http.arn
  priority = 100

  condition {
    path_pattern {
      values = [ "*" ]
    }
  }
  action {
    type = "forward"
    target_group_arn = aws_lb_target_group.example.arn
  }
}

resource "aws_lb_target_group" "example" {
    name = var.cluster_name
    port = var.server_port
    protocol = "HTTP"
    vpc_id = data.aws_vpc.default.id

    health_check {
      path = "/"
      port = 80
      protocol = "HTTP"
      matcher = "200"
      interval = 15
      timeout = 3
      healthy_threshold = 2
      unhealthy_threshold = 2
    }

}

resource "aws_autoscaling_group" "example" {
  launch_configuration = aws_launch_configuration.example.name
  vpc_zone_identifier  = data.aws_subnets.default.ids
  target_group_arns    = [aws_lb_target_group.example.arn]
  health_check_type = "ELB"

  min_size = var.min_size
  max_size = var.max_size

  tag {
    key                 = "Name"
    value               = var.cluster_name
    propagate_at_launch = true
  }
}


resource "aws_security_group" "instance" {
  name = "${var.cluster_name}-instance"
}

resource "aws_security_group_rule" "allow_server_http_inbound" {
  type              = "ingress"
  security_group_id = aws_security_group.instance.id
  from_port         = var.server_port
  to_port           = var.server_port
  protocol          = local.tcp_protocol
  cidr_blocks       = local.all_ips
}


locals {
  all_ips       = ["0.0.0.0/0"]
  tcp_protocol = "tcp"
  http_port = "80"

}

# resource "aws_security_group_rule" "allow_server_http_inbound" {
#   type              = "ingress"
#   security_group_id = aws_security_group.instance.id

#   from_port   = var.server_port
#   to_port     = var.server_port
#   protocol    = local.tcp_protocol
#   cidr_blocks = local.all_ips
# }


output "alb_dns_name" {
  value = aws_lb.example.dns_name
  description = "the dns of alb"
}



