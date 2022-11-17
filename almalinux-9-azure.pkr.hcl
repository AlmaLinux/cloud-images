/*
 * AlmaLinux OS 9 Packer template for building an Azure image.
 */

source "qemu" "almalinux-9-azure-x86_64" {
  iso_url            = var.iso_url_9_x86_64
  iso_checksum       = var.iso_checksum_9_x86_64
  shutdown_command   = var.root_shutdown_command
  accelerator        = "kvm"
  http_directory     = var.http_directory
  ssh_username       = var.gencloud_ssh_username
  ssh_password       = var.gencloud_ssh_password
  ssh_timeout        = var.ssh_timeout
  cpus               = var.cpus
  firmware           = var.firmware_x86_64
  use_pflash         = true
  disk_interface     = "virtio-scsi"
  disk_size          = var.azure_disk_size
  disk_cache         = "unsafe"
  disk_discard       = "unmap"
  disk_detect_zeroes = "unmap"
  format             = "raw"
  headless           = var.headless
  machine_type       = "q35"
  memory             = var.memory
  net_device         = "virtio-net"
  qemu_binary        = var.qemu_binary
  vnc_bind_address   = var.vnc_bind_address
  vnc_port_min       = var.vnc_port_min
  vnc_port_max       = var.vnc_port_max
  vm_name            = "AlmaLinux-9-Azure-9.1-${formatdate("YYYYMMDD", timestamp())}.x86_64.raw"
  boot_wait          = var.boot_wait
  boot_command       = var.azure_boot_command_9_x86_64
  qemuargs = [
    ["-cpu", "host"]
  ]
}

build {
  sources = ["qemu.almalinux-9-azure-x86_64"]

  provisioner "ansible" {
    playbook_file    = "./ansible/azure.yml"
    galaxy_file      = "./ansible/requirements.yml"
    roles_path       = "./ansible/roles"
    collections_path = "./ansible/collections"
    ansible_env_vars = [
      "ANSIBLE_PIPELINING=True",
      "ANSIBLE_REMOTE_TEMP=/tmp",
      "ANSIBLE_SSH_ARGS='-o ControlMaster=no -o ControlPersist=180s -o ServerAliveInterval=120s -o TCPKeepAlive=yes'"
    ]
  }
}
