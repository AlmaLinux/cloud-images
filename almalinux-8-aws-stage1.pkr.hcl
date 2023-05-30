/*
 * AlmaLinux OS 8 Packer template for building AWS images.
 */

source "vmware-iso" "almalinux-8-aws-stage1" {
  iso_url          = local.iso_url_8_x86_64
  iso_checksum     = local.iso_checksum_8_x86_64
  boot_command     = var.aws_boot_command_8
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
  iso_url            = local.iso_url_8_x86_64
  iso_checksum       = local.iso_checksum_8_x86_64
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
  vm_name            = "AlmaLinux-8-AWS-${var.os_ver_8}-${formatdate("YYYYMMDD", timestamp())}.x86_64.raw"
  boot_wait          = var.boot_wait
  boot_command       = var.aws_boot_command_8
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
    ami_name        = "Alma ${var.os_ver_8} internal use only ${formatdate("YYYYMMDD", timestamp())} x86_64"
    ami_description = local.aws_ami_description_x86_64_8
    ami_groups      = ["all"]
    s3_bucket_name  = var.aws_s3_bucket_name
    license_type    = "BYOL"
    role_name       = var.aws_role_name
    tags = {
      Name = "Alma ${var.os_ver_8} internal use only ${formatdate("YYYYMMDD", timestamp())} x86_64"
    }
    keep_input_artifact = true
    except = [
      "qemu.almalinux-8-aws-stage1"
    ]
  }

  post-processor "amazon-import" {
    ami_name        = "Alma ${var.os_ver_8} internal use only ${formatdate("YYYYMMDD", timestamp())} x86_64"
    format          = "raw"
    ami_description = local.aws_ami_description_x86_64_8
    ami_groups      = ["all"]
    s3_bucket_name  = var.aws_s3_bucket_name
    license_type    = "BYOL"
    role_name       = var.aws_role_name
    tags = {
      Name = "Alma ${var.os_ver_8} internal use only ${formatdate("YYYYMMDD", timestamp())} x86_64"
    }
    keep_input_artifact = true
    only = [
      "qemu.almalinux-8-aws-stage1"
    ]
  }
}
