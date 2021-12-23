terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 3.0"
    }
    local = {
      source  = "hashicorp/local"
      version = ">= 2.0"
    }
  }
}


provider "aws" {
  region  = "us-east-1"
  profile = "default"
}


data "aws_ami" "ami_test" {
  owners      = ["764336703387"]
  most_recent = true
  name_regex  = "AlmaLinux OS 8.*aarch64"
}


resource "aws_instance" "ami_test-1" {
  ami                         = data.aws_ami.ami_test.id
  associate_public_ip_address = true
  instance_type               = "t4g.micro"
  key_name                    = "alcib-user-prod"
  vpc_security_group_ids      = ["sg-0b52b43429d9b1845"]

  tags = {
    "Name" = "AMI Test 1"
  }
}


resource "aws_instance" "ami_test-2" {
  ami                         = data.aws_ami.ami_test.id
  associate_public_ip_address = true
  instance_type               = "t4g.micro"
  key_name                    = "alcib-user-prod"
  vpc_security_group_ids      = ["sg-0b52b43429d9b1845"]

  tags = {
    "Name" = "AMI Test 2"
  }
}


resource "local_file" "ssh_client_config" {
  content = templatefile("ssh-config.tftpl", {
    "Host1" = aws_instance.ami_test-1.public_dns
    "Host2" = aws_instance.ami_test-2.public_dns
    }
  )
  filename = "${path.module}/ssh-config"
}
