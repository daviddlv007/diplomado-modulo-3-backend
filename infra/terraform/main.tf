terraform {
  required_version = ">= 1.5.7"

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


# --- Generar par de claves ---
resource "tls_private_key" "ec2_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "ec2_key" {
  key_name   = "${var.project_name}-key"
  public_key = tls_private_key.ec2_key.public_key_openssh
}

output "ec2_private_key_pem" {
  value     = tls_private_key.ec2_key.private_key_pem
  sensitive = true
}

# --- Repositorio ECR backend ---

resource "aws_ecr_repository" "backend" {
  name                 = "phoenix-orders-backend"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }
}


# --- Repositorio ECR frontend ---

resource "aws_ecr_repository" "frontend" {
  name                 = "phoenix-frontend"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }
}

# --- IAM Role + Instance Profile (lectura de ECR) ---

resource "aws_iam_role" "ec2_ecr_role" {
  name = "${var.project_name}-ec2-ecr-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecr_read" {
  role       = aws_iam_role.ec2_ecr_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_instance_profile" "ec2_ecr_profile" {
  name = "${var.project_name}-ec2-ecr-profile"
  role = aws_iam_role.ec2_ecr_role.name
}




# --- EC2 usando el SG MVP ---
resource "aws_instance" "this" {
  ami                    = var.ami
  instance_type          = var.instance_type
  key_name               = aws_key_pair.ec2_key.key_name
  vpc_security_group_ids = [aws_security_group.mvp_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2_ecr_profile.name

  root_block_device {
    volume_size = var.volume_size
    volume_type = var.volume_type
  }

  tags = {
    Name = "${var.project_name}-ec2"
  }
}

