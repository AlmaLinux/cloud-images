/*
 * AlmaLinux OS 9 Packer template for building Amazon Machine Images (AMI).
 */

source "amazon-ebssurrogate" "almalinux-9-ami-x86_64" {
  region                  = "us-east-1"
  ssh_username            = "ec2-user"
  instance_type           = "t3.small"
  source_ami              = "ami-0d824d9c499f27c8a"
  ami_name                = var.aws_ami_name_x86_64_9
  ami_description         = var.aws_ami_description_x86_64_9
  ami_architecture        = "x86_64"
  ami_virtualization_type = "hvm"
  ami_regions             = ["us-east-1"]
  tags = {
    Name         = "${var.aws_ami_name_x86_64_9}",
    Version      = "${var.aws_ami_version_9}",
    Architecture = "x86_64"
  }
  ena_support   = true
  sriov_support = true


  launch_block_device_mappings {
    device_name           = "/dev/sdb"
    volume_size           = 4
    volume_type           = "gp2"
    delete_on_termination = true
  }
  ami_root_device {
    source_device_name    = "/dev/sdb"
    device_name           = "/dev/sda1"
    volume_size           = 10
    volume_type           = "gp2"
    delete_on_termination = true
  }
}


source "amazon-ebssurrogate" "almalinux-9-ami-aarch64" {
  region                  = "us-east-1"
  ssh_username            = "ec2-user"
  instance_type           = "t4g.small"
  source_ami              = "ami-007e46b7d6360c103"
  ami_name                = var.aws_ami_name_aarch64_9
  ami_description         = var.aws_ami_description_aarch64_9
  ami_architecture        = "arm64"
  ami_virtualization_type = "hvm"
  ami_regions             = ["us-east-1"]
  tags = {
    Name         = "${var.aws_ami_name_aarch64_9}",
    Version      = "${var.aws_ami_version_9}",
    Architecture = "aarch64"
  }
  ena_support   = true
  sriov_support = true


  launch_block_device_mappings {
    device_name           = "/dev/sdb"
    volume_size           = 4
    volume_type           = "gp2"
    delete_on_termination = true
  }
  ami_root_device {
    source_device_name    = "/dev/sdb"
    device_name           = "/dev/sda1"
    volume_size           = 10
    volume_type           = "gp2"
    delete_on_termination = true
  }
}


build {
  sources = [
    "sources.amazon-ebssurrogate.almalinux-9-ami-x86_64",
    "sources.amazon-ebssurrogate.almalinux-9-ami-aarch64"
  ]
  provisioner "shell" {
    inline = ["sudo dnf config-manager --set-enabled crb && sudo dnf -y install dosfstools python3-wheel python3-pip && sudo python3 -m pip install ansible"]
  }
  provisioner "ansible-local" {
    playbook_dir   = "./ansible"
    playbook_file  = "./ansible/ami-9-x86_64.yaml"
    galaxy_file    = "./ansible/requirements.yml"
    galaxy_command = "ansible-galaxy collection install -r"
    only = [
      "amazon-ebssurrogate.almalinux-9-ami-x86_64"
    ]
  }
  provisioner "ansible-local" {
    playbook_dir   = "./ansible"
    playbook_file  = "./ansible/ami-9-aarch64.yaml"
    galaxy_file    = "./ansible/requirements.yml"
    galaxy_command = "ansible-galaxy collection install -r"
    only = [
      "amazon-ebssurrogate.almalinux-9-ami-aarch64"
    ]
  }
}
