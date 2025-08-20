output "bastion_public_ip" {
  value = module.bastion.public_ip
}

output "lab_private_ips" {
  value = [for i in module.instances[*].private_ip : i]
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