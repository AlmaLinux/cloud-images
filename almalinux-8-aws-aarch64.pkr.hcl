/*
 * AlmaLinux OS 8 Packer template for building aarch64 AWS images.
 */


# TODO: Enable when https://github.com/hashicorp/packer/issues/11037 is resolved
/*
data "amazon-ami" "almalinux-8-aarch64" {
  filters = {
    name         = "AlmaLinux OS 8.*"
    architecture = "arm64"
    is-public    = true
  }
  owners      = ["764336703387"]
  most_recent = true
}
*/


source "amazon-ebssurrogate" "almalinux-8-aws-aarch64" {
  region                  = var.aws_ami_region
  ssh_username            = "ec2-user"
  instance_type           = "t4g.small"
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
  ena_support   = true
  sriov_support = true


  launch_block_device_mappings {
    device_name           = "/dev/sdb"
    volume_size           = 4
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
    "sources.amazon-ebssurrogate.almalinux-8-aws-aarch64"
  ]
  provisioner "shell" {
    inline = ["sudo dnf -y install ansible-core"]
  }
  provisioner "ansible-local" {
    playbook_dir  = "./ansible"
    playbook_file = "./ansible/aws-ami-aarch64.yml"
    galaxy_file   = "./ansible/requirements.yml"
  }
}
