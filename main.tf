provider "aws" {
  region = var.aws_region
}
resource "aws_vpc" "public_vpc" {
  cidr_block           = var.vpc_cidr_block
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = var.vpc_name
  }

}
resource "aws_subnet" "public_subnet" {
  # count             = 3
  count             = length(var.public_subnet_cidr_blocks)
  vpc_id            = aws_vpc.public_vpc.id
  cidr_block        = element(var.public_subnet_cidr_blocks, count.index)
  availability_zone = element(var.azs, count.index)
  tags = {
    Name = "public_subnet_${count.index + 1}"
  }
}

resource "aws_subnet" "private_subnet" {
  #count             = 3
  count             = length(var.private_subnet_cidr_blocks)
  vpc_id            = aws_vpc.public_vpc.id
  cidr_block        = element(var.private_subnet_cidr_blocks, count.index)
  availability_zone = element(var.azs, count.index)
  tags = {
    Name = "private_subnet_${count.index + 1}"
  }
}

resource "aws_internet_gateway" "public_igw_1" {
  vpc_id = aws_vpc.public_vpc.id
  tags = {
    Name = "public_igw_1"
  }
}

resource "aws_route_table" "public_rt_1" {
  vpc_id = aws_vpc.public_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.public_igw_1.id
  }
  tags = {
    Name = "public_rt_1"
  }
}

resource "aws_route_table_association" "public_rta_1" {
  count          = length(aws_subnet.public_subnet)
  subnet_id      = element(aws_subnet.public_subnet.*.id, count.index)
  route_table_id = aws_route_table.public_rt_1.id
}



resource "aws_security_group" "ec2-sg" {
  name        = "ec2-sg"
  description = "Allow SSH and HTTP"
  vpc_id      = aws_vpc.public_vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
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



resource "aws_instance" "public_instance_1" {
  count = var.environment == "prod" ? 3 : 2
  #count                       = length(var.public_subnet_cidr_blocks)
  ami                         = lookup(var.amis, var.aws_region)
  instance_type               = var.instance_type
  subnet_id                   = element(aws_subnet.public_subnet.*.id, count.index + 1)
  key_name                    = var.key_name
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.ec2-sg.id]
  tags = {
    Name        = "webserver-${count.index + 1}"
    environment = var.environment
  }

}

resource "aws_lb" "public-lb" {
  name                       = "public-lb"
  internal                   = false
  load_balancer_type         = "application"
  security_groups            = [aws_security_group.ec2-sg.id]
  subnets                    = aws_subnet.public_subnet.*.id
  enable_deletion_protection = false
  tags = {
    Name        = "public-lb"
    environment = var.environment
  }
}

resource "aws_lb_target_group" "web_tg" {
  name     = "web-target-group"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.public_vpc.id

  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 30
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  tags = {
    Name = "web-target-group"
  }
}

resource "aws_lb_target_group_attachment" "web_attachment" {

  count = length(aws_instance.public_instance_1)

  target_group_arn = aws_lb_target_group.web_tg.arn

  target_id = aws_instance.public_instance_1[count.index].id

  port = 80
}

resource "aws_lb_listener" "web_listener" {

  load_balancer_arn = aws_lb.public-lb.arn

  port     = 80
  protocol = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web_tg.arn
  }
}

output "alb_dns_name" {
  value = aws_lb.public-lb.dns_name
}