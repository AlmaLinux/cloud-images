/*
 * AlmaLinux OS 8 Packer template for building OpenNebula images.
 */

source "qemu" "almalinux-8-opennebula-x86_64" {
  iso_url            = local.iso_url_8_x86_64
  iso_checksum       = local.iso_checksum_8_x86_64
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
  qemu_binary        = var.qemu_binary
  vm_name            = "AlmaLinux-8-OpenNebula-${var.os_ver_8}-${formatdate("YYYYMMDD", timestamp())}.x86_64.qcow2"
  boot_wait          = var.boot_wait
  boot_command       = var.opennebula_boot_command_8_x86_64
}


source "qemu" "almalinux-8-opennebula-aarch64" {
  iso_url            = local.iso_url_8_aarch64
  iso_checksum       = local.iso_checksum_8_aarch64
  shutdown_command   = var.root_shutdown_command
  accelerator        = "kvm"
  http_directory     = var.http_directory
  ssh_username       = var.gencloud_ssh_username
  ssh_password       = var.gencloud_ssh_password
  ssh_timeout        = var.ssh_timeout
  cpus               = var.cpus
  firmware           = var.aavmf_code
  use_pflash         = false
  disk_interface     = "virtio-scsi"
  disk_size          = var.gencloud_disk_size
  disk_cache         = "unsafe"
  disk_discard       = "unmap"
  disk_detect_zeroes = "unmap"
  disk_compression   = true
  format             = "qcow2"
  headless           = var.headless
  machine_type       = "virt,gic-version=max"
  memory             = var.memory
  net_device         = "virtio-net"
  qemu_binary        = var.qemu_binary
  vm_name            = "AlmaLinux-8-OpenNebula-${var.os_ver_8}-${formatdate("YYYYMMDD", timestamp())}.aarch64.qcow2"
  boot_wait          = var.boot_wait
  boot_command       = local.opennebula_boot_command_8_aarch64
  qemuargs = [
    ["-cpu", "max"],
    ["-boot", "strict=on"],
    ["-monitor", "none"]
  ]
}


build {
  sources = [
    "qemu.almalinux-8-opennebula-x86_64",
    "qemu.almalinux-8-opennebula-aarch64"
  ]

  provisioner "ansible" {
    playbook_file    = "./ansible/opennebula.yml"
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
