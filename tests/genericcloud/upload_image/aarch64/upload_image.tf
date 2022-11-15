terraform {
  required_version = ">= 0.14.0"
  required_providers {
    openstack = {
      source  = "terraform-provider-openstack/openstack"
      version = ">= 1.40"
    }
  }
}


provider "openstack" {
  cloud = "openstack-aarch64"
}


resource "openstack_images_image_v2" "almalinux-gc" {
  name             = "AlmaLinux OS 8.7.${formatdate("YYYYMMDD", timestamp())}"
  container_format = "bare"
  disk_format      = "qcow2"
  local_file_path  = "AlmaLinux-8-GenericCloud-8.7-${formatdate("YYYYMMDD", timestamp())}.aarch64.qcow2"
}
