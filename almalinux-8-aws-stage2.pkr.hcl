/*
 * AlmaLinux OS 8 Packer template for building AWS images Stage 2.
 */

source "amazon-chroot" "almalinux-8-aws-stage2" {
  ami_name                = local.aws_ami_name_x86_64_8
  ami_description         = local.aws_ami_description_x86_64_8
  ami_virtualization_type = "hvm"
  ami_regions             = var.aws_ami_regions
  tags = {
    Name         = "${local.aws_ami_name_x86_64_8}",
    Version      = "${local.aws_ami_version_8}",
    Architecture = "${var.aws_ami_architecture}"
  }
  ena_support     = true
  sriov_support   = true
  region          = var.aws_ami_region
  device_path     = "/dev/xvdb"
  mount_options   = ["nouuid"]
  mount_partition = "2"
  source_ami_filter {
    filters = {
      name                = "Alma ${var.os_ver_8} internal use only*x86_64"
      root-device-type    = "ebs"
      virtualization-type = "hvm"
    }
    owners      = ["self"]
    most_recent = true
  }
  root_volume_size = 4
  root_device_name = "/dev/sda1"
  ami_block_device_mappings {
    device_name           = "/dev/sda1"
    delete_on_termination = true
    volume_type           = var.aws_volume_type
  }
}


build {
  sources = [
    "sources.amazon-chroot.almalinux-8-aws-stage2"
  ]
  provisioner "ansible" {
    galaxy_file    = "./ansible/requirements.yml"
    inventory_file = "./ansible/aws-ami-stage2.inventory"
    playbook_file  = "./ansible/aws-ami-stage2.yml"
    extra_arguments = [
      "--connection=chroot"
    ]
    ansible_env_vars = [
      "ANSIBLE_PIPELINING=True",
      "ANSIBLE_REMOTE_TEMP=/tmp"
    ]
  }
}
