variable "node_location" {
  type = string
}

variable "resource_prefix" {
  type = string
}
variable "node_address_space" {
  default = ["192.168.0.0/16"]
}
variable "node_address_prefixes" {
  default = ["192.168.1", "192.168.2"]
}

variable "subnet_name" {
  type = list(string)
}
variable "subnet_cidr" {
  type = list(string)
}
#variable for Environment
variable "environment" {
  type = string
}
variable "total_node_count" {
  type = number
}
variable "cluster_node_count" {
  type = number
}
variable "ilb_probe_port" {
  type = number
}
variable "admin_username" {
  type = string
}
variable "admin_password" {
  type = string
}