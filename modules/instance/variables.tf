variable "ami" {}
variable "instance_type" {}
variable "subnet_id" {}
variable "sg_ids" { type = list(string) }
variable "key_name" {}
variable "env_name" {}
variable "role" {}
variable "distribution" {}
variable "size" {}
variable "associate_public_ip" {
  description = "Whether to associate a public IP address"
  type        = bool
  default     = false
}
variable "index" {}