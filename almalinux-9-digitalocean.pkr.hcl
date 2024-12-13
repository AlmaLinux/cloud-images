# AlmaLinux OS 9 Packer template for DigitalOcean images

source "qemu" "almalinux-9-digitalocean-x86_64" {
  iso_url            = local.iso_url_9_x86_64
  iso_checksum       = local.iso_checksum_9_x86_64
  http_directory     = var.http_directory
  shutdown_command   = var.root_shutdown_command
  ssh_username       = var.gencloud_ssh_username
  ssh_password       = var.gencloud_ssh_password
  ssh_timeout        = var.ssh_timeout
  boot_command       = local.gencloud_boot_command_9_x86_64
  boot_wait          = var.boot_wait
  accelerator        = "kvm"
  disk_interface     = "virtio-scsi"
  disk_size          = var.gencloud_disk_size
  disk_cache         = "unsafe"
  disk_discard       = "unmap"
  disk_detect_zeroes = "unmap"
  disk_compression   = true
  format             = "qcow2"
  headless           = var.headless
  machine_type       = "q35"
  memory             = var.memory_x86_64
  net_device         = "virtio-net"
  qemu_binary        = var.qemu_binary
  vm_name            = "AlmaLinux-9-DigitalOcean-${var.os_ver_9}-${formatdate("YYYYMMDD", timestamp())}.x86_64.qcow2"
  cpu_model          = "host"
  cpus               = var.cpus
  efi_boot           = true
  efi_firmware_code  = var.ovmf_code
  efi_firmware_vars  = var.ovmf_vars
  efi_drop_efivars   = true
}

build {
  sources = ["source.qemu.almalinux-9-digitalocean-x86_64"]

  provisioner "ansible" {
    galaxy_file          = "./ansible/requirements.yml"
    galaxy_force_install = true
    collections_path     = "./ansible/collections"
    roles_path           = "./ansible/roles"
    playbook_file        = "./ansible/digitalocean.yml"
    ansible_env_vars = [
      "ANSIBLE_PIPELINING=True",
      "ANSIBLE_REMOTE_TEMP=/tmp",
      "ANSIBLE_SCP_EXTRA_ARGS=-O",
    ]
  }

  provisioner "shell" {
    scripts = ["vm-scripts/digitalocean/99-img-check.sh"]
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
