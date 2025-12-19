# AlmaLinux OS 10 Packer template for GCP VM images

source "qemu" "almalinux_10_gcp_x86_64" {
  iso_url            = local.iso_url_10_x86_64
  iso_checksum       = local.iso_checksum_10_x86_64
  http_directory     = var.http_directory
  shutdown_command   = var.root_shutdown_command
  ssh_username       = var.gencloud_ssh_username
  ssh_password       = var.gencloud_ssh_password
  ssh_timeout        = var.ssh_timeout
  boot_command       = var.gcp_boot_command_10_x86_64
  boot_wait          = var.boot_wait
  accelerator        = "kvm"
  disk_interface     = "virtio-scsi"
  disk_size          = var.gcp_disk_size
  disk_cache         = "unsafe"
  disk_discard       = "unmap"
  disk_detect_zeroes = "unmap"
  format             = "raw"
  headless           = var.headless
  machine_type       = "q35"
  memory             = var.memory_x86_64
  net_device         = "virtio-net"
  qemu_binary        = var.qemu_binary
  vm_name            = "AlmaLinux-10-GCP-${var.os_ver_10}-${formatdate("YYYYMMDD", timestamp())}.${var.build_number}.x86_64.raw"
  cpu_model          = "host"
  cpus               = var.cpus
  efi_boot           = true
  efi_firmware_code  = var.ovmf_code
  efi_firmware_vars  = var.ovmf_vars
  efi_drop_efivars   = true
}

source "qemu" "almalinux_10_gcp_aarch64" {
  iso_url            = local.iso_url_10_aarch64
  iso_checksum       = local.iso_checksum_10_aarch64
  http_directory     = var.http_directory
  shutdown_command   = var.root_shutdown_command
  ssh_username       = var.gencloud_ssh_username
  ssh_password       = var.gencloud_ssh_password
  ssh_timeout        = var.ssh_timeout
  boot_command       = var.gcp_boot_command_10_aarch64
  boot_wait          = var.boot_wait
  accelerator        = "kvm"
  firmware           = var.aavmf_code
  use_pflash         = false
  disk_interface     = "virtio-scsi"
  disk_size          = var.gcp_disk_size
  disk_cache         = "unsafe"
  disk_discard       = "unmap"
  disk_detect_zeroes = "unmap"
  format             = "raw"
  headless           = var.headless
  machine_type       = "virt,gic-version=max"
  memory             = var.memory_aarch64
  net_device         = "virtio-net"
  qemu_binary        = var.qemu_binary
  vm_name            = "AlmaLinux-10-GCP-${var.os_ver_10}-${formatdate("YYYYMMDD", timestamp())}.${var.build_number}.aarch64.raw"
  cpu_model          = "host"
  cpus               = var.cpus
  qemuargs = [
    ["-boot", "strict=on"],
    ["-monitor", "none"]
  ]
}

source "qemu" "almalinux_10_gcp_64k_aarch64" {
  iso_url            = local.iso_url_10_aarch64
  iso_checksum       = local.iso_checksum_10_aarch64
  http_directory     = var.http_directory
  shutdown_command   = var.root_shutdown_command
  ssh_username       = var.gencloud_ssh_username
  ssh_password       = var.gencloud_ssh_password
  ssh_timeout        = var.ssh_timeout
  boot_command       = var.gcp_boot_command_10_64k_aarch64
  boot_wait          = var.boot_wait
  accelerator        = "kvm"
  firmware           = var.aavmf_code
  use_pflash         = false
  disk_interface     = "virtio-scsi"
  disk_size          = var.gcp_disk_size
  disk_cache         = "unsafe"
  disk_discard       = "unmap"
  disk_detect_zeroes = "unmap"
  format             = "raw"
  headless           = var.headless
  machine_type       = "virt,gic-version=max"
  memory             = var.memory_aarch64
  net_device         = "virtio-net"
  qemu_binary        = var.qemu_binary
  vm_name            = "AlmaLinux-10-GCP-${var.os_ver_10}-${formatdate("YYYYMMDD", timestamp())}.${var.build_number}-64k.aarch64.raw"
  cpu_model          = "host"
  cpus               = var.cpus
  qemuargs = [
    ["-boot", "strict=on"],
    ["-monitor", "none"]
  ]
}

build {
  sources = [
    "source.qemu.almalinux_10_gcp_x86_64",
    "source.qemu.almalinux_10_gcp_aarch64",
    "source.qemu.almalinux_10_gcp_64k_aarch64",
  ]

  provisioner "ansible" {
    galaxy_file          = "./ansible/requirements.yml"
    galaxy_force_install = true
    collections_path     = "./ansible/collections"
    roles_path           = "./ansible/roles"
    playbook_file        = "./ansible/gcp.yml"
    ansible_env_vars = [
      "ANSIBLE_PIPELINING=True",
      "ANSIBLE_REMOTE_TEMP=/tmp",
      "ANSIBLE_SCP_EXTRA_ARGS=-O",
    ]
  }

  # copy SBOM metadata file into output
  post-processor "shell-local" {
    inline = [
      "cp /tmp/sbom-data-$PACKER_BUILD_NAME.json output-$PACKER_BUILD_NAME/"
    ]
  }

  post-processor "shell-local" {
    inline = [
      "cd output-$PACKER_BUILD_NAME",
      "mv AlmaLinux-10-GCP-${var.os_ver_10}-${formatdate("YYYYMMDD", timestamp())}.${var.build_number}.x86_64.raw disk.raw",
      "tar -cf - disk.raw | pigz -c > AlmaLinux-10-GCP-${var.os_ver_10}-${formatdate("YYYYMMDD", timestamp())}.${var.build_number}.x86_64.tar.gz"
    ]
    only = ["qemu.almalinux_10_gcp_x86_64"]
  }

  post-processor "shell-local" {
    inline = [
      "cd output-$PACKER_BUILD_NAME",
      "mv AlmaLinux-10-GCP-${var.os_ver_10}-${formatdate("YYYYMMDD", timestamp())}.${var.build_number}.aarch64.raw disk.raw",
      "tar -cf - disk.raw | pigz -c > AlmaLinux-10-GCP-${var.os_ver_10}-${formatdate("YYYYMMDD", timestamp())}.${var.build_number}.aarch64.tar.gz"
    ]
    only = ["qemu.almalinux_10_gcp_aarch64"]
  }

}
