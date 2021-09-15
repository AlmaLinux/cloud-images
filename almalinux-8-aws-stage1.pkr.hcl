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


source "vmware-iso" "almalinux-8-aws-stage1" {
  iso_url          = var.iso_url_x86_64
  iso_checksum     = var.iso_checksum_x86_64
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
  vmx_data = {
    "cpuid.coresPerSocket" : "1"
  }
  vmx_data_post = {
    "memsize" : var.post_memory
    "numvcpus" : var.post_cpus
  }

  vmx_remove_ethernet_interfaces = true
}


source "qemu" "almalinux-8-aws-stage1" {
  iso_url            = var.iso_url_x86_64
  iso_checksum       = var.iso_checksum_x86_64
  shutdown_command   = var.root_shutdown_command
  accelerator        = "kvm"
  http_directory     = var.http_directory
  ssh_username       = var.aws_ssh_username
  ssh_password       = var.aws_ssh_password
  ssh_timeout        = var.ssh_timeout
  cpus               = var.cpus
  disk_interface     = "virtio-scsi"
  disk_size          = var.aws_disk_size
  disk_cache         = "unsafe"
  disk_discard       = "unmap"
  disk_detect_zeroes = "unmap"
  disk_compression   = true
  format             = "raw"
  headless           = var.headless
  memory             = var.memory
  net_device         = "virtio-net"
  qemu_binary        = var.qemu_binary
  vm_name            = "almalinux-8-AWS-8.4.x86_64.raw"
  boot_wait          = var.boot_wait
  boot_command       = var.aws_boot_command
}


build {
  sources = [
    "sources.vmware-iso.almalinux-8-aws-stage1",
    "sources.qemu.almalinux-8-aws-stage1"
  ]

  provisioner "ansible" {
    playbook_file    = "./ansible/aws-ami.yml"
    galaxy_file      = "./ansible/requirements.yml"
    roles_path       = "./ansible/roles"
    collections_path = "./ansible/collections"
    ansible_env_vars = [
      "ANSIBLE_PIPELINING=True",
      "ANSIBLE_REMOTE_TEMP=/tmp",
      "ANSIBLE_SSH_ARGS='-o ControlMaster=no -o ControlPersist=180s -o ServerAliveInterval=120s -o TCPKeepAlive=yes'"
    ]
  }

  // comment this out if you don't want to import AMI to Amazon EC2 automatically
  post-processor "amazon-import" {
    ami_name        = "${var.aws_ami_name_x86_64}-stage1"
    ami_description = var.aws_ami_description_x86_64
    ami_groups      = ["all"]
    s3_bucket_name  = var.aws_s3_bucket_name
    license_type    = "BYOL"
    role_name       = var.aws_role_name
    tags = {
      Name = "${var.aws_ami_name_x86_64}-stage1"
    }
    keep_input_artifact = true
    except = [
      "qemu.almalinux-8-aws-stage1"
    ]
  }

  post-processor "amazon-import" {
    ami_name        = "${var.aws_ami_name_x86_64}-stage1"
    format          = "raw"
    ami_description = var.aws_ami_description_x86_64
    ami_groups      = ["all"]
    s3_bucket_name  = var.aws_s3_bucket_name
    license_type    = "BYOL"
    role_name       = var.aws_role_name
    tags = {
      Name = "${var.aws_ami_name_x86_64}-stage1"
    }
    keep_input_artifact = true
    only = [
      "qemu.almalinux-8-aws-stage1"
    ]
  }
}
