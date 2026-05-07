terraform {
  required_version = ">= 1.7.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.50"
    }
  }
}

provider "aws" {
  region = var.region
}

data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }
}

resource "aws_security_group" "example" {
  name        = "nginx-remediation-example-sg"
  description = "Allow SSH and HTTP for remediation example"
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.admin_cidr]
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

resource "aws_iam_role" "ec2_ssm_role" {
  name = "nginx-remediation-example-ec2-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.ec2_ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "nginx-remediation-example-profile"
  role = aws_iam_role.ec2_ssm_role.name
}

resource "aws_instance" "vulnerable_nginx" {
  ami                    = data.aws_ami.al2023.id
  instance_type          = "t3.micro"
  vpc_security_group_ids = [aws_security_group.example.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2_profile.name
  user_data = <<-EOT
#!/bin/bash
set -eux
dnf install -y nginx
dnf install -y yum-plugin-versionlock
# Pin nginx to an older package to simulate vulnerable baseline.
dnf downgrade -y nginx || true
yum versionlock add nginx* || true
systemctl enable nginx
systemctl start nginx
echo "Vulnerable nginx baseline for remediation demo" > /usr/share/nginx/html/index.html
EOT
  tags = {
    Name             = "vulnerable-nginx-demo"
    PatchGroup       = "security-remediation-demo"
    RemediationScope = "ai-assisted"
  }
}

variable "region" {
  type    = string
  default = "us-east-1"
}

variable "admin_cidr" {
  type        = string
  description = "CIDR allowed to SSH to demo instance"
}

output "instance_id" {
  value = aws_instance.vulnerable_nginx.id
}
