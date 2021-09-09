/*
 * AlmaLinux OS 8 Packer template for building AWS images Stage 2.
 */


packer {
  required_plugins {
    ansible = {
      version = ">= 1.0.0"
      source  = "github.com/hashicorp/ansible"
    }
  }
}


source "amazon-chroot" "almalinux-8-aws-stage2" {
  ami_name                = var.aws_ami_name
  ami_description         = var.aws_ami_description
  ami_virtualization_type = "hvm"
  ami_regions             = ["us-east-1"]
  tags = {
    Name    = "${var.aws_ami_name}",
    Version = "${var.aws_ami_version}"
  }
  region          = "us-east-1"
  device_path     = "/dev/xvdb"
  mount_options   = ["nouuid"]
  mount_partition = "2"
  source_ami_filter {
    filters = {
      name                = "AlmaLinux OS 8.4.* x86_64-stage1"
      root-device-type    = "ebs"
      virtualization-type = "hvm"
    }
    owners      = ["self"]
    most_recent = true
  }
  root_volume_size = 10
  root_device_name = "/dev/sda1"
  ami_block_device_mappings {
    device_name           = "/dev/sda1"
    delete_on_termination = true
    volume_type           = "gp2"
  }
}


build {
  sources = [
    "sources.amazon-chroot.almalinux-8-aws-stage2"
  ]
  provisioner "ansible" {
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
