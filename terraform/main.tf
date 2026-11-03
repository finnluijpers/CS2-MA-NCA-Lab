
# ==========================================
# AWS vpc
# ==========================================

resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name        = "innovatech-vpc"
    Environment = "CS2-Lab"
  }
}

# ==========================================
# Public subnet
# ==========================================

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "eu-central-1a"

  tags = {
    Name = "innovatech-public-subnet"
  }
}

# ==========================================
# Internet gateway
# ==========================================

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "innovatech-igw"
  }
}

# ==========================================
# Route table
# ==========================================

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "innovatech-public-rt"
  }
}

resource "aws_route_table_association" "public_assoc" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public_rt.id
}

# ==========================================
# Security Group - Tailscale Protected
# ==========================================

resource "aws_security_group" "cloud_sg" {
  name        = "innovatech-cloud-sg"
  description = "Allow SSH, HTTP, ICMP, and Monitoring traffic"
  vpc_id      = aws_vpc.main.id

  # Public HTTP access
  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "innovatech-cloud-sg"
  }
}

# ==========================================
# Ubuntu 24.04 AMI Lookup
# ==========================================

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

# ==========================================
# cloud App EC2 instance
# ==========================================

resource "aws_instance" "cloud_node" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.cloud_sg.id]

  user_data = <<-EOF
              #!/bin/bash
              mkdir -p /home/ubuntu/.ssh
              echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAb7aHvs/T1YyYADrpMrqHnuay2QQiCP1QpeiczqZ+F8 vagrant@app01" >> /home/ubuntu/.ssh/authorized_keys
              chown -R ubuntu:ubuntu /home/ubuntu/.ssh
              chmod 700 /home/ubuntu/.ssh
              chmod 600 /home/ubuntu/.ssh/authorized_keys
              EOF

  tags = {
    Name        = "cloud01"
    Environment = "CS2-Lab"
  }
}

# ==========================================
# Outputs
# ==========================================

output "cloud_node_public_ip" {
  value       = aws_instance.cloud_node.public_ip
  description = "public IP address of cloud01"
}

output "cloud_node_private_ip" {
  value       = aws_instance.cloud_node.private_ip
  description = "private VPC IP address of cloud01"
}
