/*
 * AlmaLinux OS 8 Packer template for building AWS images.
 */

packer {
  required_plugins {
    amazon = {
      version = ">= 0.0.1"
      source  = "github.com/hashicorp/amazon"
    }
  }
}


source "vmware-iso" "almalinux-8-aws" {
  iso_url          = var.iso_url
  iso_checksum     = var.iso_checksum
  boot_command     = var.aws_boot_command
  boot_wait        = var.boot_wait
  cpus             = var.cpus
  memory           = var.memory
  disk_size        = var.aws_disk_size
  format           = "ova"
  headless         = var.headless
  http_directory   = var.http_directory
  guest_os_type    = "centos-64"
  shutdown_command = var.root_shutdown_command
  ssh_username     = var.aws_ssh_username
  ssh_password     = var.aws_ssh_password
  ssh_timeout      = var.ssh_timeout
  vmx_data         = {
    "cpuid.coresPerSocket": "1"
  }
  vmx_data_post    = {
    "memsize":  var.post_memory
    "numvcpus": var.post_cpus
  }

  vmx_remove_ethernet_interfaces = true
}


build {
  sources = [
    "sources.vmware-iso.almalinux-8-aws"]

  provisioner "ansible" {
    playbook_file    = "./ansible/aws-ami.yml"
    galaxy_file      = "./ansible/requirements.yml"
    roles_path       = "./ansible/roles"
    collections_path = "./ansible/collections"
    ansible_env_vars = [
      "ANSIBLE_SSH_ARGS='-o ControlMaster=no -o ControlPersist=180s -o ServerAliveInterval=120s -o TCPKeepAlive=yes'"
    ]
  }

  // comment this out if you don't want to import AMI to Amazon EC2 automatically
  post-processor "amazon-import" {
    s3_bucket_name      = var.aws_s3_bucket_name
    license_type        = "BYOL"
    role_name           = var.aws_role_name
    keep_input_artifact = true
    tags                = {
      Description = "AlmaLinux 8.3 x86_64"
      Timestamp   = "{{isotime \"2006-01-02T15:04:05Z\"}}"
    }
  }
}
