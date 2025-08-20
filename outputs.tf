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

output "ssh_bastion_command" {
  description = "SSH command to connect to the bastion host"
  value = "ssh -i lab_rsa.pem ubuntu@${module.bastion.public_ip}"
}

output "ssh_instance_commands" {
  description = "SSH commands to connect to each instance from the bastion (use private IPs)"
  value = [for ip in module.instances[*].private_ip : "ssh -i lab_rsa.pem ubuntu@${ip}"]
}