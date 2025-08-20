terraform {
  required_version = ">= 1.0.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  region = var.region
}

# Génération automatique d’une clé SSH (privée/publique)
resource "tls_private_key" "lab_ssh" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "lab" {
  key_name   = "${var.env_name}-key"
  public_key = tls_private_key.lab_ssh.public_key_openssh
}

# VPC, sous-réseaux, SG : via module (pour production, séparez si besoin)
module "vpc" {
  source             = "terraform-aws-modules/vpc/aws"
  name               = "${var.env_name}-vpc"
  cidr               = "10.0.0.0/16"
  azs                = ["us-east-1a"]
  public_subnets     = ["10.0.1.0/24"]
  private_subnets    = ["10.0.2.0/24"]
  enable_nat_gateway = false
  single_nat_gateway = false

  # Pour simplifier, on utilise le SG par défaut du VPC (adaptable)
  tags = {
    Environment = var.env_name
  }
}

# SECURITY GROUPS
resource "aws_security_group" "ssh" {
  name        = "${var.env_name}-ssh"
  description = "Allow SSH"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port   = 22
    to_port     = 22
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

resource "aws_security_group" "web" {
  name        = "${var.env_name}-web"
  description = "Allow HTTP/HTTPS"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 443
    to_port     = 443
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

module "bastion" {
  source        = "./modules/bastion"
  ami           = var.bastion_ami
  instance_type = var.bastion_instance_type
  subnet_id     = module.vpc.public_subnets[0]
  sg_ids        = [aws_security_group.ssh.id]
  key_name      = aws_key_pair.lab.key_name
  env_name      = var.env_name
}

module "instances" {
  source        = "./modules/instance"
  count         = var.instance_count
  ami           = var.selected_ami
  instance_type = var.instance_type
  subnet_id     = module.vpc.public_subnets[0]
  sg_ids        = var.instance_role == "webserver" ? [aws_security_group.ssh.id, aws_security_group.web.id] : [aws_security_group.ssh.id]
  key_name      = aws_key_pair.lab.key_name
  env_name      = var.env_name
  role          = var.instance_role
  distribution  = var.instance_distribution
  size          = var.instance_size
  associate_public_ip = true
  index         = count.index + 1
}