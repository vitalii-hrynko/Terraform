terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }
}

provider "aws" {
  profile = var.profile
  region  = var.region
}

resource "aws_vpc" "nlb-vpc" {
  cidr_block = "192.168.0.0/16"
  tags = {
    Name = "NLB-VPC"
  }
}

resource "aws_subnet" "subnet1" {
  vpc_id                  = aws_vpc.nlb-vpc.id
  cidr_block              = "192.168.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "us-east-2a"
}

resource "aws_subnet" "subnet2" {
  vpc_id                  = aws_vpc.nlb-vpc.id
  cidr_block              = "192.168.2.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "us-east-2b"
}

resource "aws_internet_gateway" "internet-gw" {
  vpc_id = aws_vpc.nlb-vpc.id

  tags = {
    Name = "Internet-GW"
  }
}

resource "aws_route_table" "internet-rt" {
  vpc_id = aws_vpc.nlb-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.internet-gw.id
  }
}

resource "aws_route_table_association" "assoc1" {
  subnet_id      = aws_subnet.subnet1.id
  route_table_id = aws_route_table.internet-rt.id
}

resource "aws_route_table_association" "assoc2" {
  subnet_id      = aws_subnet.subnet2.id
  route_table_id = aws_route_table.internet-rt.id
}


resource "aws_security_group" "http-sg" {
  name   = "HTTP"
  vpc_id = aws_vpc.nlb-vpc.id
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
}

resource "aws_network_interface" "vm1-nic" {
  subnet_id       = aws_subnet.subnet1.id
  private_ips     = ["192.168.1.10"]
  security_groups = [aws_security_group.http-sg.id]
}

resource "aws_network_interface" "vm2-nic" {
  subnet_id       = aws_subnet.subnet2.id
  private_ips     = ["192.168.2.10"]
  security_groups = [aws_security_group.http-sg.id]
}

resource "aws_instance" "vm1" {
  ami               = "ami-0d8d212151031f51c"
  instance_type     = "t2.micro"
  user_data         = file("apache.sh")
  availability_zone = "us-east-2a"
   
  network_interface {
    network_interface_id = aws_network_interface.vm1-nic.id
    device_index         = 0
  }

  tags = {
    Name = "VM-1"
  }

}

resource "aws_instance" "vm2" {
  ami               = "ami-0d8d212151031f51c"
  instance_type     = "t2.micro"
  user_data         = file("apache.sh")
  availability_zone = "us-east-2b"
  
  network_interface {
    network_interface_id = aws_network_interface.vm2-nic.id
    device_index         = 0
  }
  
  tags = {
    Name = "VM-2"
  }
}

resource "aws_alb_target_group" "nlb-target-group" {
  health_check {
    interval            = 10
    path                = "/"
    protocol            = "HTTP"
    healthy_threshold   = 3
    unhealthy_threshold = 3
  }
  name        = "nlb-target-group"
  port        = 80
  protocol    = "TCP"
  target_type = "instance"
  vpc_id      = aws_vpc.nlb-vpc.id
}

resource "aws_lb" "nlb" {
  name                             = "NLB"
  internal                         = false
  enable_cross_zone_load_balancing = true
  tags = {
    Name = "NLB"
  }
  subnets            = [aws_subnet.subnet1.id, aws_subnet.subnet2.id]
  ip_address_type    = "ipv4"
  load_balancer_type = "network"
}

resource "aws_alb_listener" "nlb_listener" {
  load_balancer_arn = aws_lb.nlb.arn
  port              = 80
  protocol          = "TCP"

  default_action {
    target_group_arn = aws_alb_target_group.nlb-target-group.arn
    type             = "forward"
  }
}

resource "aws_alb_target_group_attachment" "vm1-attach" {
  target_group_arn = aws_alb_target_group.nlb-target-group.arn
  target_id        = aws_instance.vm1.id
}

resource "aws_alb_target_group_attachment" "vm2-attach" {
  target_group_arn = aws_alb_target_group.nlb-target-group.arn
  target_id        = aws_instance.vm2.id
}

