/*
 * AlmaLinux OS 9 Packer template for building Oracle Cloud Infrastructure images.
 */

source "qemu" "almalinux-9-oci-bios-x86_64" {
  iso_url            = var.iso_url_9_x86_64
  iso_checksum       = var.iso_checksum_9_x86_64
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
  vm_name            = "AlmaLinux-9-OCI-BIOS-9.1-${formatdate("YYYYMMDD", timestamp())}.x86_64.qcow2"
  boot_wait          = var.boot_wait
  boot_command       = var.gencloud_boot_command_9_x86_64_bios
  qemuargs = [
    ["-cpu", "host"]
  ]
}


source "qemu" "almalinux-9-oci-x86_64" {
  iso_url            = var.iso_url_9_x86_64
  iso_checksum       = var.iso_checksum_9_x86_64
  shutdown_command   = var.root_shutdown_command
  accelerator        = "kvm"
  http_directory     = var.http_directory
  ssh_username       = var.gencloud_ssh_username
  ssh_password       = var.gencloud_ssh_password
  ssh_timeout        = var.ssh_timeout
  cpus               = var.cpus
  efi_firmware_code  = var.ovmf_code
  efi_firmware_vars  = var.ovmf_vars
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
  vm_name            = "AlmaLinux-9-OCI-9.1-${formatdate("YYYYMMDD", timestamp())}.x86_64.qcow2"
  boot_wait          = var.boot_wait
  boot_command       = var.gencloud_boot_command_9_x86_64
  qemuargs = [
    ["-cpu", "host"]
  ]
}


source "qemu" "almalinux-9-oci-aarch64" {
  iso_url            = var.iso_url_9_aarch64
  iso_checksum       = var.iso_checksum_9_aarch64
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
  vm_name            = "AlmaLinux-9-OCI-9.1-${formatdate("YYYYMMDD", timestamp())}.aarch64.qcow2"
  boot_wait          = var.boot_wait
  boot_command       = var.gencloud_boot_command_9_aarch64
  qemuargs = [
    ["-cpu", "max"],
    ["-boot", "strict=on"],
    ["-monitor", "none"]
  ]
}


build {
  sources = [
    "qemu.almalinux-9-oci-bios-x86_64",
    "qemu.almalinux-9-oci-x86_64",
    "qemu.almalinux-9-oci-aarch64"
  ]

  provisioner "ansible" {
    playbook_file    = "./ansible/oci.yml"
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
