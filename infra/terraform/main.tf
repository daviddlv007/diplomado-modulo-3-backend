terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 4.0"
    }
  }

  backend "s3" {
    bucket         = "REPLACE_ME_BUCKET"       # Se reemplaza con -backend-config
    key            = "terraform.tfstate"
    region         = "us-east-1"              # Se reemplaza con -backend-config
    dynamodb_table = "REPLACE_ME_TABLE"       # Se reemplaza con -backend-config
    encrypt        = true
  }
}

provider "aws" {
  region = var.aws_region
}

# --- VPC por defecto ---
data "aws_vpc" "default" {
  default = true
}

# --- Security Group MVP ---
resource "aws_security_group" "mvp_sg" {
  name        = "${var.project_name}-sg"
  description = "SG MVP: SSH HTTP HTTPS abiertos"
  vpc_id      = data.aws_vpc.default.id

  # SSH abierto
  ingress {
    description = "SSH open"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTP público
  ingress {
    description = "HTTP open"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTPS público
  ingress {
    description = "HTTPS open"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Todo permitido en salida
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-sg"
  }
}


# --- EC2 usando el SG MVP ---
resource "aws_instance" "this" {
  ami           = var.ami
  instance_type = var.instance_type
  key_name      = var.key_name

  vpc_security_group_ids = [aws_security_group.mvp_sg.id]

  root_block_device {
    volume_size = var.volume_size
    volume_type = var.volume_type
  }

  tags = {
    Name = "${var.project_name}-ec2"
  }
}
