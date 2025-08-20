resource "aws_instance" "this" {
  ami                         = var.ami
  instance_type               = var.instance_type
  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = var.sg_ids
  associate_public_ip_address = var.associate_public_ip
  key_name                    = var.key_name

  tags = {
    Name         = "${var.env_name}-${var.role}-${var.index}"
    Environment  = var.env_name
    Role         = var.role
    Distribution = var.distribution
    Size         = var.size
  }
}