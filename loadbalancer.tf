// Provider
provider "aws" {
  access_key = "${var.access_key}"
  secret_key = "${var.secret_key}"
  region     = "us-east-1"
}

// User's external IP
data "http" "my_ip" {
  url = "https://ipinfo.io/ip"
}

// VPC
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "PlayQ-2019-vpc"
  }
}

// Subnets
resource "aws_subnet" "public_1a" {
  vpc_id            = "${aws_vpc.main.id}"
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "PlayQ-2019-public_1a"
  }
}

resource "aws_subnet" "public_1b" {
  vpc_id            = "${aws_vpc.main.id}"
  cidr_block        = "10.0.2.0/24"
  availability_zone = "us-east-1b"

  tags = {
    Name = "PlayQ-2019-public_1b"
  }
}

// Route table
resource "aws_route_table" "public" {
  vpc_id = "${aws_vpc.main.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.igw.id}"
  }

  tags = {
    Name = "PlayQ-2019-public_rt"
  }
}

// Route table associations
resource "aws_route_table_association" "public_1a" {
  subnet_id      = "${aws_subnet.public_1a.id}"
  route_table_id = "${aws_route_table.public.id}"
}

resource "aws_route_table_association" "public_1b" {
  subnet_id      = "${aws_subnet.public_1b.id}"
  route_table_id = "${aws_route_table.public.id}"
}

// Internet gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = "${aws_vpc.main.id}"

  tags = {
    Name = "PlayQ-2019-igw"
  }
}

// Security groups
resource "aws_security_group" "lb_sg" {
  name        = "lb_sg"
  description = "Load balancer security group"
  vpc_id      = "${aws_vpc.main.id}"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "PlayQ-2019-lb_sg"
  }
}

resource "aws_security_group" "webserver_sg" {
  name        = "webserver_sg"
  description = "Allow restricted inbound SSH, outbound HTTP/HTTPS"
  vpc_id      = "${aws_vpc.main.id}"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["76.169.181.157/32", "${trimspace(data.http.my_ip.body)}/32"]
  }

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = ["${aws_security_group.lb_sg.id}"]
  }

  egress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "PlayQ-2019-webserver_sg"
  }
}

// Load balancer
resource "aws_lb" "lb" {
  name               = "lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = ["${aws_security_group.lb_sg.id}"]
  subnets            = ["${aws_subnet.public_1a.id}", "${aws_subnet.public_1b.id}"]

  tags = {
    Name = "PlayQ-2019-alb"
  }
}

resource "aws_lb_listener" "lb_listener" {
  load_balancer_arn = "${aws_lb.lb.arn}"
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "fixed-response"
    fixed_response {
        content_type = "text/html"
        status_code = 500
    }
  }
}

resource "aws_lb_listener_rule" "webserver_lb_listener_rule" {
  listener_arn = "${aws_lb_listener.lb_listener.arn}"

  action {
    type             = "forward"
    target_group_arn = "${aws_lb_target_group.lb_tg.arn}"
  }

  condition {
    field  = "host-header"
    values = ["www.playqtest.com"]
  }
}

resource "aws_lb_target_group" "lb_tg" {
  name        = "lb-tg"
  port        = 80
  protocol    = "HTTP"
  target_type = "instance"
  vpc_id      = "${aws_vpc.main.id}"

  health_check {
    path     = "/"
    interval = 10
  }
}

resource "aws_autoscaling_attachment" "webserver_asg_attachment" {
  autoscaling_group_name = "${aws_autoscaling_group.webserver_asg.id}"
  alb_target_group_arn   = "${aws_lb_target_group.lb_tg.arn}"
}

// Output
output "lb_url" {
  value = "http://${aws_lb.lb.dns_name}"
}

