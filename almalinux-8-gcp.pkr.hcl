# AlmaLinux OS 8 Packer template for GCP VM images

source "qemu" "almalinux-8-gcp-x86_64" {
  iso_url            = local.iso_url_8_x86_64
  iso_checksum       = local.iso_checksum_8_x86_64
  http_directory     = var.http_directory
  shutdown_command   = var.root_shutdown_command
  ssh_username       = var.gencloud_ssh_username
  ssh_password       = var.gencloud_ssh_password
  ssh_timeout        = var.ssh_timeout
  boot_command       = local.gcp_boot_command_8_x86_64
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
  vm_name            = "AlmaLinux-8-GCP-${var.os_ver_8}-${formatdate("YYYYMMDD", timestamp())}.${var.build_number}.x86_64.raw"
  cpu_model          = "host"
  cpus               = var.cpus
  efi_boot           = true
  efi_firmware_code  = var.ovmf_code
  efi_firmware_vars  = var.ovmf_vars
  efi_drop_efivars   = true
}

source "qemu" "almalinux-8-gcp-aarch64" {
  iso_url            = local.iso_url_8_aarch64
  iso_checksum       = local.iso_checksum_8_aarch64
  http_directory     = var.http_directory
  shutdown_command   = var.root_shutdown_command
  ssh_username       = var.gencloud_ssh_username
  ssh_password       = var.gencloud_ssh_password
  ssh_timeout        = var.ssh_timeout
  boot_command       = local.gcp_boot_command_8_aarch64
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
  vm_name            = "AlmaLinux-8-GCP-${var.os_ver_8}-${formatdate("YYYYMMDD", timestamp())}.${var.build_number}.aarch64.raw"
  cpu_model          = "host"
  cpus               = var.cpus
  qemuargs = [
    ["-boot", "strict=on"],
    ["-monitor", "none"]
  ]
}

build {
  sources = [
    "source.qemu.almalinux-8-gcp-x86_64",
    "source.qemu.almalinux-8-gcp-aarch64",
  ]

  provisioner "ansible" {
    #command              = "/home/jonathan/ansible-2.16/bin/ansible-playbook"
    #galaxy_command       = "/home/jonathan/ansible-2.16/bin/ansible-galaxy"
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
    only = ["qemu.almalinux-8-gcp-x86_64"]
  }

  provisioner "ansible" {
    galaxy_file          = "./ansible/requirements.yml"
    galaxy_force_install = true
    collections_path     = "./ansible/collections"
    roles_path           = "./ansible/roles"
    playbook_file        = "./ansible/gcp.yml"
    ansible_env_vars = [
      "ANSIBLE_PIPELINING=True",
      "ANSIBLE_REMOTE_TEMP=/tmp",
      "ANSIBLE_SCP_EXTRA_ARGS=-O"
    ]
    only = ["qemu.almalinux-8-gcp-aarch64"]
  }

  # copy the repo metadata file into output
  post-processor "shell-local" {
    inline = [
      "cp /tmp/repo-metadata-$PACKER_BUILD_NAME.txt output-$PACKER_BUILD_NAME/"
    ]
  }

  post-processor "shell-local" {
    inline = [
      "cd output-$PACKER_BUILD_NAME",
      "mv AlmaLinux-8-GCP-${var.os_ver_8}-${formatdate("YYYYMMDD", timestamp())}.${var.build_number}.x86_64.raw disk.raw",
      "tar -cf - disk.raw | pigz -c > AlmaLinux-8-GCP-${var.os_ver_8}-${formatdate("YYYYMMDD", timestamp())}.${var.build_number}.x86_64.tar.gz"
    ]
    only = ["qemu.almalinux-8-gcp-x86_64"]
  }

  post-processor "shell-local" {
    inline = [
      "cd output-$PACKER_BUILD_NAME",
      "mv AlmaLinux-8-GCP-${var.os_ver_8}-${formatdate("YYYYMMDD", timestamp())}.${var.build_number}.aarch64.raw disk.raw",
      "tar -cf - disk.raw | pigz -c > AlmaLinux-8-GCP-${var.os_ver_8}-${formatdate("YYYYMMDD", timestamp())}.${var.build_number}.aarch64.tar.gz"
    ]
    only = ["qemu.almalinux-8-gcp-aarch64"]
  }

}
