# AlmaLinux OS 10 Packer template for Cloud-init included and OpenStack compatible Generic Cloud (ext4) images

source "qemu" "almalinux_10_gencloud_ext4_x86_64" {
  iso_url            = local.iso_url_10_x86_64
  iso_checksum       = local.iso_checksum_10_x86_64
  http_directory     = var.http_directory
  shutdown_command   = var.root_shutdown_command
  ssh_username       = var.gencloud_ssh_username
  ssh_password       = var.gencloud_ssh_password
  ssh_timeout        = var.ssh_timeout
  boot_command       = var.gencloud_ext4_boot_command_10_x86_64
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
  vm_name            = "AlmaLinux-10-GenericCloud-ext4-${var.os_ver_10}-${formatdate("YYYYMMDD", timestamp())}.${var.build_number}.x86_64.qcow2"
  cpu_model          = "host"
  cpus               = var.cpus
  efi_boot           = true
  efi_firmware_code  = var.ovmf_code
  efi_firmware_vars  = var.ovmf_vars
  efi_drop_efivars   = true
}

source "qemu" "almalinux_10_gencloud_ext4_aarch64" {
  iso_url            = local.iso_url_10_aarch64
  iso_checksum       = local.iso_checksum_10_aarch64
  http_directory     = var.http_directory
  shutdown_command   = var.root_shutdown_command
  ssh_username       = var.gencloud_ssh_username
  ssh_password       = var.gencloud_ssh_password
  ssh_timeout        = var.ssh_timeout
  boot_command       = local.aarch64_gencloud_ext4_boot_command_10
  boot_wait          = var.boot_wait
  accelerator        = var.aarch64_accelerator
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
  memory             = var.memory_aarch64
  net_device         = "virtio-net"
  qemu_binary        = var.qemu_binary
  vm_name            = "AlmaLinux-10-GenericCloud-ext4-${var.os_ver_10}-${formatdate("YYYYMMDD", timestamp())}.${var.build_number}.aarch64.qcow2"
  cpu_model          = var.aarch64_cpu_model
  cpus               = var.cpus
  qemuargs = concat(
    [["-boot", "strict=on"], ["-monitor", "none"]],
    # Tee the serial port into a log file instead of redirecting it: on the
    # virt machine the firmware and GRUB console IS the serial port, shown
    # on QEMU's VNC text console, and Packer types the boot command into it.
    # "-serial file:" would take that input away (GRUB would never see the
    # keys and boot its default media-check entry).
    var.aarch64_console_log != "" ? [["-chardev", "vc,id=serial0,logfile=${var.aarch64_console_log}"], ["-serial", "chardev:serial0"]] : [],
  )
}

source "qemu" "almalinux_10_gencloud_ext4_ppc64le" {
  iso_url            = local.iso_url_10_ppc64le
  iso_checksum       = local.iso_checksum_10_ppc64le
  http_directory     = var.http_directory
  shutdown_command   = var.root_shutdown_command
  ssh_username       = var.gencloud_ssh_username
  ssh_password       = var.gencloud_ssh_password
  ssh_timeout        = var.ssh_timeout
  boot_command       = local.gencloud_ext4_boot_command_10_ppc64le
  boot_wait          = var.gencloud_boot_wait_ppc64le
  accelerator        = var.ppc64le_accelerator
  disk_interface     = "virtio-scsi"
  disk_size          = var.gencloud_disk_size
  disk_cache         = "unsafe"
  disk_discard       = "unmap"
  disk_detect_zeroes = "unmap"
  disk_compression   = true
  format             = "qcow2"
  headless           = var.headless
  machine_type       = var.ppc64le_machine_type
  cpu_model          = var.ppc64le_cpu_model
  qemuargs           = var.ppc64le_console_log != "" ? [["-serial", "file:${var.ppc64le_console_log}"]] : []
  memory             = var.memory_ppc64le
  net_device         = "virtio-net"
  qemu_binary        = var.qemu_binary
  vm_name            = "AlmaLinux-10-GenericCloud-ext4-${var.os_ver_10}-${formatdate("YYYYMMDD", timestamp())}.${var.build_number}.ppc64le.qcow2"
  cpus               = var.cpus
}

source "qemu" "almalinux_10_gencloud_ext4_x86_64_v2" {
  iso_url            = local.iso_url_10_x86_64_v2
  iso_checksum       = local.iso_checksum_10_x86_64_v2
  http_directory     = var.http_directory
  shutdown_command   = var.root_shutdown_command
  ssh_username       = var.gencloud_ssh_username
  ssh_password       = var.gencloud_ssh_password
  ssh_timeout        = var.ssh_timeout
  boot_command       = var.gencloud_ext4_boot_command_10_x86_64_v2
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
  vm_name            = "AlmaLinux-10-GenericCloud-ext4-${var.os_ver_10}-${formatdate("YYYYMMDD", timestamp())}.${var.build_number}.x86_64_v2.qcow2"
  cpu_model          = "Nehalem"
  cpus               = var.cpus
  efi_boot           = true
  efi_firmware_code  = var.ovmf_code
  efi_firmware_vars  = var.ovmf_vars
  efi_drop_efivars   = true
}

build {
  sources = [
    "source.qemu.almalinux_10_gencloud_ext4_x86_64",
    "source.qemu.almalinux_10_gencloud_ext4_aarch64",
    "source.qemu.almalinux_10_gencloud_ext4_ppc64le",
    "source.qemu.almalinux_10_gencloud_ext4_x86_64_v2",
  ]

  provisioner "ansible" {
    galaxy_file          = "./ansible/requirements.yml"
    galaxy_force_install = true
    collections_path     = "./ansible/collections"
    roles_path           = "./ansible/roles"
    playbook_file        = "./ansible/gencloud.yml"
    ansible_env_vars = [
      "ANSIBLE_PIPELINING=True",
      "ANSIBLE_REMOTE_TEMP=/tmp",
      "ANSIBLE_SSH_TRANSFER_METHOD=scp",
      "ANSIBLE_SCP_EXTRA_ARGS=-O",
    ]
  }
}
