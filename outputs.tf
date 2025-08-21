output "bastion_public_ip" {
  value = module.bastion.public_ip
}

output "lab_private_ips" {
  value = [for i in module.instances[*].private_ip : i]
}

output "lab_public_ips" {
  description = "Public IPs of lab instances (web servers have public IPs)"
  value       = [for i in module.instances[*] : i.public_ip]
}

output "ssh_private_key_pem" {
  description = "Clé privée SSH générée, à utiliser pour accéder à toutes les instances"
  value       = tls_private_key.lab_ssh.private_key_pem
  sensitive   = true
}

output "ssh_public_key" {
  description = "Clé publique SSH générée et copiée sur AWS"
  value       = tls_private_key.lab_ssh.public_key_openssh
}

locals {
  instance_ssh_user = var.instance_distribution == "amazonlinux" ? "ec2-user" : (var.instance_distribution == "debian" ? "admin" : "ubuntu")
}

output "ssh_bastion_command" {
  description = "SSH command to connect to the bastion host"
  value = "ssh -i ~/.ssh/lab_rsa.pem ${local.instance_ssh_user}@${module.bastion.public_ip}"
}

output "ssh_instance_commands" {
  description = "SSH commands to connect to each instance from the bastion (use private IPs)"
  value = [for ip in module.instances[*].private_ip : "ssh -i ~/.ssh/lab_rsa.pem ${local.instance_ssh_user}@${ip}"]
}

output "chosen_instance_distribution" {
  description = "The selected instance distribution"
  value       = var.instance_distribution
}

output "lab_instance_amis" {
  description = "AMI IDs used for lab instances"
  value       = [for i in module.instances[*] : i.ami_id]
}

output "alb_dns_name" {
  description = "Public DNS name of the Application Load Balancer"
  value       = try(aws_lb.web.dns_name, null)
}

output "alb_http_url" {
  description = "HTTP URL to reach the reverse proxy"
  value       = try("http://${aws_lb.web.dns_name}", null)
}