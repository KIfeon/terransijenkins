variable "ami" {}
variable "instance_type" {}
variable "subnet_id" {}
variable "sg_ids" {
  type = list(string)
}
variable "key_name" {}
variable "env_name" {}