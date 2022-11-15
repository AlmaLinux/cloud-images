terraform {
  required_version = ">= 0.14.0"
  required_providers {
    opennebula = {
      source  = "OpenNebula/opennebula"
      version = ">= 0.5.1"
    }
  }
}

provider "opennebula" {
  endpoint = var.one_endpoint
  username = var.one_username
  password = var.one_password
}

resource "opennebula_image" "opennebula-amd64" {
  name         = "OpenNebula x86_64 ALCIB Image"
  description  = "This image will be tested as a part of AlmalInux Cloud Image Builder"
  datastore_id = var.datastore_id
  persistent   = false
  path         = "AlmaLinux-8-OpenNebula-8.7-${formatdate("YYYYMMDD", timestamp())}.x86_64.qcow2"
  type         = "OS"
  dev_prefix   = "vd"
  format       = "qcow2"
}
