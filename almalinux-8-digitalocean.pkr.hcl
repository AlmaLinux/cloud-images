/*
 * AlmaLinux OS 8 Packer template for building DigitalOcean images.
 */

packer {
  required_plugins {
    digitalocean = {
      version = ">= 1.0.0"
      source  = "github.com/hashicorp/digitalocean"
    }
  }
}

source "qemu" "almalinux-8-gencloud-do-x86_64" {
  iso_url            = var.iso_url
  iso_checksum       = var.iso_checksum
  shutdown_command   = var.root_shutdown_command
  accelerator        = "kvm"
  http_directory     = var.http_directory
  ssh_username       = var.gencloud_ssh_username
  ssh_password       = var.gencloud_ssh_password
  ssh_timeout        = var.ssh_timeout
  cpus               = var.cpus
  disk_interface     = "virtio-scsi"
  disk_size          = var.gencloud_disk_size
  disk_cache         = "unsafe"
  disk_discard       = "unmap"
  disk_detect_zeroes = "unmap"
  disk_compression   = true
  format             = "qcow2"
  headless           = var.headless
  memory             = var.memory
  net_device         = "virtio-net"
  vm_name            = "almalinux-8-GenericCloud-8.4.x86_64.qcow2"
  boot_wait          = var.boot_wait
  boot_command       = var.gencloud_boot_command
  qemu_img_args {
    convert = ["-o", "compat=0.10"]
    create  = ["-o", "compat=0.10"]
  }
}


build {
  sources = ["qemu.almalinux-8-gencloud-do-x86_64"]

  provisioner "ansible" {
    playbook_file    = "./ansible/digitalocean.yml"
    galaxy_file      = "./ansible/requirements.yml"
    roles_path       = "./ansible/roles"
    collections_path = "./ansible/collections"
    ansible_env_vars = [
      "ANSIBLE_PIPELINING=True",
      "ANSIBLE_REMOTE_TEMP=/tmp",
      "ANSIBLE_SSH_ARGS='-o ControlMaster=no -o ControlPersist=180s -o ServerAliveInterval=120s -o TCPKeepAlive=yes'"
    ]
  }

  // it seems that Ansible leaves a tmp directory for unknown reason,
  // cleanup it manually until we have a solution
  provisioner "shell" {
    scripts = [
      "vm-scripts-digitalocean/80-root_lock-up.bash",
      "vm-scripts-digitalocean/89-root_clean-up.bash",
      "vm-scripts-digitalocean/99-img-check.bash"
    ]
  }

  post-processor "digitalocean-import" {
    api_token     = var.do_api_token
    spaces_key    = var.do_spaces_key
    spaces_secret = var.do_spaces_secret
    spaces_region = var.do_region
    space_name    = var.do_spaces_name
    image_name    = var.do_image_name
    image_regions = var.do_image_regions
  }
}
