/*
 * AlmaLinux OS 9 Packer template for building DigitalOcean images.
 */

source "qemu" "almalinux-9-digitalocean-x86_64" {
  iso_url            = local.iso_url_9_x86_64
  iso_checksum       = local.iso_checksum_9_x86_64
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
  machine_type       = "q35"
  memory             = var.memory
  net_device         = "virtio-net"
  qemu_binary        = var.qemu_binary
  vm_name            = "almalinux-9-DigitalOcean-${var.os_ver_9}.x86_64.qcow2"
  boot_wait          = var.boot_wait
  boot_command       = var.gencloud_boot_command_9_x86_64_bios
  qemuargs = [
    ["-cpu", "host"]
  ]
}


build {
  sources = ["qemu.almalinux-9-digitalocean-x86_64"]

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

  provisioner "shell" {
    scripts = [
      "vm-scripts/digitalocean/99-img-check.sh"
    ]
  }

  post-processor "digitalocean-import" {
    api_token          = var.do_api_token
    spaces_key         = var.do_spaces_key
    spaces_secret      = var.do_spaces_secret
    spaces_region      = var.do_spaces_region
    space_name         = var.do_space_name
    image_name         = var.do_image_name_9
    image_regions      = var.do_image_regions
    image_description  = var.do_image_description
    image_distribution = var.do_image_distribution
    image_tags         = local.do_image_tags
  }
}
