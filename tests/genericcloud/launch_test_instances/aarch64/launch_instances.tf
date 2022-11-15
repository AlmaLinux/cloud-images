terraform {
  required_version = ">= 0.14.0"
  required_providers {
    openstack = {
      source  = "terraform-provider-openstack/openstack"
      version = ">= 1.40"
    }
    local = {
      source  = "hashicorp/local"
      version = ">= 2.0"
    }
  }
}


provider "openstack" {
  cloud = "openstack-aarch64"
}


resource "openstack_compute_instance_v2" "gc_test-1" {
  name            = "GenericCloud Test 1"
  image_name      = "AlmaLinux OS 8.7.${formatdate("YYYYMMDD", timestamp())}"
  flavor_name     = "m1.small"
  security_groups = ["SSH"]
  key_pair        = "alcib"


  network {
    name = "public5"
  }
}


resource "openstack_compute_instance_v2" "gc_test-2" {
  name            = "GenericCloud Test 2"
  image_name      = "AlmaLinux OS 8.7.${formatdate("YYYYMMDD", timestamp())}"
  flavor_name     = "m1.small"
  security_groups = ["SSH"]
  key_pair        = "alcib"


  network {
    name = "public5"
  }
}


resource "local_file" "ssh_client_config" {
  content = templatefile("ssh-config.tftpl", {
    "Host1" = openstack_compute_instance_v2.gc_test-1.access_ip_v4
    "Host2" = openstack_compute_instance_v2.gc_test-2.access_ip_v4
    }
  )
  filename = "${path.module}/ssh-config"
}
