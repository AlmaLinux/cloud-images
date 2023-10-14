/*
 * AlmaLinux OS 9 Packer template for building Amazon Machine Images (AMI).
 */


# TODO: Enable when https://github.com/hashicorp/packer/issues/11037 is resolved
/*
data "amazon-ami" "almalinux-9-x86_64" {
  filters = {
    name         = "AlmaLinux OS 9.*"
    architecture = "x86_64"
    is-public    = true
  }
  owners      = ["764336703387"]
  most_recent = true
}

data "amazon-ami" "almalinux-9-aarch64" {
  filters = {
    name         = "AlmaLinux OS 9.*"
    architecture = "arm64"
    is-public    = true
  }
  owners      = ["764336703387"]
  most_recent = true
}
*/

source "amazon-ebssurrogate" "almalinux-9-ami-x86_64" {
  region                  = var.aws_ami_region
  ssh_username            = "ec2-user"
  instance_type           = "t3.small"
  source_ami              = var.aws_source_ami_9_x86_64
  ami_name                = local.aws_ami_name_x86_64_9
  ami_description         = local.aws_ami_description_x86_64_9
  ami_architecture        = "x86_64"
  ami_virtualization_type = "hvm"
  ami_regions             = var.aws_ami_regions
  tags = {
    Name         = "${local.aws_ami_name_x86_64_9}",
    Version      = "${local.aws_ami_version_9}",
    Architecture = "x86_64"
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


source "amazon-ebssurrogate" "almalinux-9-ami-aarch64" {
  region                  = var.aws_ami_region
  ssh_username            = "ec2-user"
  instance_type           = "t4g.small"
  source_ami              = var.aws_source_ami_9_aarch64
  ami_name                = local.aws_ami_name_aarch64_9
  ami_description         = local.aws_ami_description_aarch64_9
  ami_architecture        = "arm64"
  ami_virtualization_type = "hvm"
  ami_regions             = var.aws_ami_regions
  tags = {
    Name         = "${local.aws_ami_name_aarch64_9}",
    Version      = "${local.aws_ami_version_9}",
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
    "sources.amazon-ebssurrogate.almalinux-9-ami-x86_64",
    "sources.amazon-ebssurrogate.almalinux-9-ami-aarch64"
  ]
  provisioner "shell" {
    inline = ["sudo dnf -y install ansible-core dosfstools"]
  }
  provisioner "ansible-local" {
    playbook_dir  = "./ansible"
    playbook_file = "./ansible/ami-9-x86_64.yaml"
    galaxy_file   = "./ansible/requirements.yml"
    only = [
      "amazon-ebssurrogate.almalinux-9-ami-x86_64"
    ]
  }
  provisioner "ansible-local" {
    playbook_dir  = "./ansible"
    playbook_file = "./ansible/ami-9-aarch64.yaml"
    galaxy_file   = "./ansible/requirements.yml"
    only = [
      "amazon-ebssurrogate.almalinux-9-ami-aarch64"
    ]
  }
}
