packer {
  required_version = ">= 1.7.0"
  required_plugins {
    amazon = {
      version = ">= 1.1.0"
      source  = "github.com/hashicorp/amazon"
    }
    ansible = {
      version = ">= 1.1.0"
      source  = "github.com/hashicorp/ansible"
    }
    digitalocean = {
      version = ">= 1.2.0"
      source  = "github.com/digitalocean/digitalocean"
    }
    hyperv = {
      version = ">= 1.0.3"
      source  = "github.com/hashicorp/hyperv"
    }
    parallels = {
      version = ">= 1.1.2"
      source  = "github.com/Parallels/parallels"
    }
    qemu = {
      version = ">= 1.0.7"
      source  = "github.com/hashicorp/qemu"
    }
    vagrant = {
      version = ">= 1.1.0"
      source  = "github.com/hashicorp/vagrant"
    }
    virtualbox = {
      version = ">= 1.0.3"
      source  = "github.com/hashicorp/virtualbox"
    }
    vmware = {
      version = ">= 1.1.0"
      source  = "github.com/hashicorp/vmware"
    }
  }
}
