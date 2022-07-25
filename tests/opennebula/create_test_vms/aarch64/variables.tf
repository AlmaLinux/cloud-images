variable "one_endpoint" {
  default     = ""
  type        = string
  description = "OpenNebula XML-RPC Endpoint API URL"
}

variable "one_username" {
  default     = ""
  type        = string
  description = "OpenNebula Username"
}

variable "one_password" {
  default     = ""
  type        = string
  description = "Opennebula Password or Login Token of the username"
}

variable "datastore_id" {
  type        = number
  description = "ID of the datastore used to store the image"
  nullable    = false
}

variable "group" {
  type        = string
  description = "Name of the group which owns the template"
  nullable    = false
}

variable "network_id" {
  type        = number
  description = "ID of the virtual network to attach to the virtual machine"
  nullable    = false
}

variable "ssh_pub_key" {
  type        = string
  description = "SSH Public key of the ALCIB"
  nullable    = false
}
