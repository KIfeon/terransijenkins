variable "region" {
  default = "us-east-1"
}

variable "env_name" {
  description = "Nom de l'environnement"
}

variable "tf_state_bucket" {
  description = "S3 bucket for Terraform state"
  default     = null
}

variable "tf_state_region" {
  description = "AWS region for Terraform state bucket"
  default     = null
}

variable "instance_count" {
  type        = number
  default     = 2
  description = "Nombre de vm, hors bastion"
}

variable "instance_type" {
  default     = "t3.micro"
  description = "Type de VM"
}
variable "instance_role" {
  default     = "webserver"
  description = "Rôle de la VM"
}

variable "instance_distribution" {
  default     = "ubuntu"
  description = "Distribution"
}



variable "selected_ami" {
  default     = "ami-053b0d53c279acc90" # Ubuntu 22.04 us-east-1 (Vérifie toujours la distribution ici)
}

variable "bastion_ami" {
  default     = "ami-053b0d53c279acc90" # Ubuntu 22.04 us-east-1 (idem)
}

variable "bastion_instance_type" {
  default     = "t3.nano"
}