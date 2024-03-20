# AlmaLinux OS 8 Packer template for building Amazon Machine Images (AMI).

# TODO: Enable when https://github.com/hashicorp/packer/issues/11037 is resolved.
/*
data "amazon-ami" "almalinux_8_x86_64" {
  filters = {
    name         = "AlmaLinux OS 8.*"
    architecture = "x86_64"
    is-public    = true
  }
  owners      = ["764336703387"]
  most_recent = true
}

data "amazon-ami" "almalinux_8_aarch64" {
  filters = {
    name         = "AlmaLinux OS 8.*"
    architecture = "arm64"
    is-public    = true
  }
  owners      = ["764336703387"]
  most_recent = true
}
*/

source "amazon-ebssurrogate" "almalinux_8_ami_x86_64" {
  profile                 = var.aws_profile
  region                  = var.aws_ami_region
  ssh_username            = "ec2-user"
  instance_type           = var.aws_instance_type_x86_64
  source_ami              = var.aws_source_ami_8_x86_64
  ami_name                = local.aws_ami_name_x86_64_8
  ami_description         = local.aws_ami_description_x86_64_8
  ami_architecture        = "x86_64"
  ami_virtualization_type = "hvm"
  ami_regions             = var.aws_ami_regions
  tags = {
    Name         = "${local.aws_ami_name_x86_64_8}",
    Version      = "${local.aws_ami_version_8}",
    Architecture = "x86_64"
  }
  boot_mode    = "uefi-preferred"
  imds_support = "v2.0"
  # uefi_data     = file("tpl/edk2/OVMF_VARS.secboot.fd_20220126gitbb1bba3d77-6.el8_9.6.alma.aws") # Enable Secure Boot support.
  # tpm_support   = "v2.0" # Enable NitroTPM support. Only supported when "boot_mode" is "uefi"
  ena_support   = true
  sriov_support = true

  launch_block_device_mappings {
    device_name           = "/dev/sdb"
    volume_size           = var.aws_volume_size
    volume_type           = var.aws_volume_type
    delete_on_termination = true
  }

  ami_root_device {
    source_device_name    = "/dev/sdb"
    device_name           = "/dev/sda1"
    volume_size           = 10
    volume_type           = var.aws_volume_type
    delete_on_termination = true
  }
}

source "amazon-ebssurrogate" "almalinux_8_ami_aarch64" {
  profile                 = var.aws_profile
  region                  = var.aws_ami_region
  ssh_username            = "ec2-user"
  instance_type           = var.aws_instance_type_aarch64
  source_ami              = var.aws_source_ami_8_aarch64
  ami_name                = local.aws_ami_name_aarch64_8
  ami_description         = local.aws_ami_description_aarch64_8
  ami_architecture        = "arm64"
  ami_virtualization_type = "hvm"
  ami_regions             = var.aws_ami_regions
  tags = {
    Name         = "${local.aws_ami_name_aarch64_8}",
    Version      = "${local.aws_ami_version_8}",
    Architecture = "aarch64"
  }
  imds_support  = "v2.0"
  ena_support   = true
  sriov_support = true

  launch_block_device_mappings {
    device_name           = "/dev/sdb"
    volume_size           = var.aws_volume_size
    volume_type           = var.aws_volume_type
    delete_on_termination = true
  }

  ami_root_device {
    source_device_name    = "/dev/sdb"
    device_name           = "/dev/sda1"
    volume_size           = 10
    volume_type           = var.aws_volume_type
    delete_on_termination = true
  }
}

build {
  sources = [
    "sources.amazon-ebssurrogate.almalinux_8_ami_x86_64",
    "sources.amazon-ebssurrogate.almalinux_8_ami_aarch64"
  ]
  provisioner "shell" {
    inline = ["sudo dnf -y install ansible-core dosfstools"]
  }
  provisioner "ansible-local" {
    playbook_dir  = "./ansible"
    playbook_file = "./ansible/ami_8_x86_64.yaml"
    galaxy_file   = "./ansible/requirements.yml"
    only          = ["amazon-ebssurrogate.almalinux_8_ami_x86_64"]
  }
  provisioner "ansible-local" {
    playbook_dir  = "./ansible"
    playbook_file = "./ansible/ami_8_aarch64.yaml"
    galaxy_file   = "./ansible/requirements.yml"
    only          = ["amazon-ebssurrogate.almalinux_8_ami_aarch64"]
  }
}
