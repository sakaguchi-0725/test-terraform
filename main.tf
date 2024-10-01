provider "aws" {
  region = "ap-northeast-1"
}

# VPC
resource "aws_vpc" "test-vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "test-vpc"
  }
}

# IGW
resource "aws_internet_gateway" "test-igw" {
  vpc_id = aws_vpc.test-vpc.id
  tags = {
    Name = "test-igw"
  }
}

# route table
resource "aws_route_table" "test-route-table" {
  vpc_id = aws_vpc.test-vpc.id

  tags = {
    Name = "test-route-table"
  }
}

# route
resource "aws_route" "test-route-ipv4" {
  route_table_id = aws_route_table.test-route-table.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id = aws_internet_gateway.test-igw.id
}

resource "aws_route" "test-route-ipv6" {
  route_table_id = aws_route_table.test-route-table.id
  destination_ipv6_cidr_block = "::/0"
  gateway_id = aws_internet_gateway.test-igw.id
}

# subnet
resource "aws_subnet" "test-subnet" {
  vpc_id = aws_vpc.test-vpc.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "ap-northeast-1a"
  tags = {
    Name = "test-subnet"
  }
}

# subnetとroute tableの紐付け
resource "aws_route_table_association" "test-association" {
  route_table_id = aws_route_table.test-route-table.id
  subnet_id = aws_subnet.test-subnet.id
}

# Security Group
resource "aws_security_group" "test-security-group" {
  name = "test-security-group"
  description = "Allow web inbound traffic"
  vpc_id = aws_vpc.test-vpc.id

  ingress {
    description = "https"
    from_port = 443
    to_port = 443
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "http"
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "ssh"
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "test-security-group"
  }
}

# ENI
resource "aws_network_interface" "test-nw-interface" {
  subnet_id = aws_subnet.test-subnet.id
  private_ips = ["10.0.1.50"]
  security_groups = [aws_security_group.test-security-group.id]
}

# EIP
resource "aws_eip" "test-eip" {
  network_interface = aws_network_interface.test-nw-interface.id
  associate_with_private_ip = "10.0.1.50"
  depends_on = [ aws_internet_gateway.test-igw,  aws_instance.test-instance ]
}

# Webサーバー
resource "aws_instance" "test-instance" {
  ami = var.ami_id
  instance_type = "t2.micro"
  availability_zone = "ap-northeast-1a"
  key_name = "terraform-test"

  network_interface {
    device_index = 0
    network_interface_id = aws_network_interface.test-nw-interface.id
  }

  user_data = <<-EOF
    #!/bin/bash
    sudo yum -y install httpd
    sudo systemctl start httpd.service
    sudo bash -c 'Hello Terraform!! > /var/www/html/index.html'
  EOF

  tags = {
    Name = "test-instance"
  }
}