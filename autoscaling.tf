// Filter for autoscaling-based webservers
data "aws_instances" "webserver_instances" {
  instance_tags = {
    Name = "PlayQ-2019"
    Type = "webserver"
  }

  depends_on = [ "aws_autoscaling_group.webserver_asg" ]
}

// Latest Ubuntu Bionic AMI for our region
data "aws_ami" "latest_ubuntu" {
  most_recent = true
  owners      = ["099720109477"] // Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-bionic-18.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

// SSH key/AWS key pair
resource "tls_private_key" "webservers_ssh_key" {
  algorithm = "RSA"
  rsa_bits  = 4096

  provisioner "local-exec" {
    command     = "echo '${tls_private_key.webservers_ssh_key.private_key_pem}' > id_rsa && chmod 600 id_rsa"
    interpreter = ["bash", "-c"]
  }
}

resource "aws_key_pair" "webservers_key_pair" {
  key_name   = "webservers"
  public_key = "${tls_private_key.webservers_ssh_key.public_key_openssh}"
}

// Launch config
resource "aws_launch_configuration" "webserver_lc" {
  name                        = "webserver_lc"
  image_id                    = "${data.aws_ami.latest_ubuntu.id}"
  instance_type               = "t2.micro"
  key_name                    = "${aws_key_pair.webservers_key_pair.key_name}"
  associate_public_ip_address = true
  security_groups             = ["${aws_security_group.webserver_sg.id}"]
  user_data                   = "${file("userdata.sh")}"

  lifecycle {
    create_before_destroy = true
  }
}

// Autoscaling group
resource "aws_autoscaling_group" "webserver_asg" {
  name                 = "webserver_asg"
  max_size             = 3
  min_size             = 2
  launch_configuration = "${aws_launch_configuration.webserver_lc.name}"
  vpc_zone_identifier  = ["${aws_subnet.public_1a.id}", "${aws_subnet.public_1b.id}"]

  lifecycle {
    create_before_destroy = true
  }

  tags = [
    {
      key                 = "Name"
      value               = "PlayQ-2019"
      propagate_at_launch = true
    },
    {
      key                 = "Type"
      value               = "webserver"
      propagate_at_launch = true
    },
  ]
}

// Output
output "webserver_public_ips" {
    value = "${join(", ", data.aws_instances.webserver_instances.public_ips)}"
}