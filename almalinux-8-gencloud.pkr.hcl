# AlmaLinux OS 8 Packer template for Cloud-init included and OpenStack compatible Generic Cloud images

source "qemu" "almalinux-8-gencloud-x86_64" {
  iso_url            = local.iso_url_8_x86_64
  iso_checksum       = local.iso_checksum_8_x86_64
  http_directory     = var.http_directory
  shutdown_command   = var.root_shutdown_command
  ssh_username       = var.gencloud_ssh_username
  ssh_password       = var.gencloud_ssh_password
  ssh_timeout        = var.ssh_timeout
  boot_command       = local.gencloud_boot_command_8_x86_64
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
  vm_name            = "AlmaLinux-8-GenericCloud-${var.os_ver_8}-${formatdate("YYYYMMDD", timestamp())}.x86_64.qcow2"
  cpu_model          = "host"
  cpus               = var.cpus
  efi_boot           = true
  efi_firmware_code  = var.ovmf_code
  efi_firmware_vars  = var.ovmf_vars
  efi_drop_efivars   = true
}

source "qemu" "almalinux-8-gencloud-aarch64" {
  iso_url            = local.iso_url_8_aarch64
  iso_checksum       = local.iso_checksum_8_aarch64
  http_directory     = var.http_directory
  shutdown_command   = var.root_shutdown_command
  ssh_username       = var.gencloud_ssh_username
  ssh_password       = var.gencloud_ssh_password
  ssh_timeout        = var.ssh_timeout
  boot_command       = local.gencloud_boot_command_8_aarch64
  boot_wait          = var.boot_wait
  accelerator        = "kvm"
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
  vm_name            = "AlmaLinux-8-GenericCloud-${var.os_ver_8}-${formatdate("YYYYMMDD", timestamp())}.aarch64.qcow2"
  cpu_model          = "host"
  cpus               = var.cpus
  qemuargs = [
    ["-boot", "strict=on"],
    ["-monitor", "none"],
  ]
}

source "qemu" "almalinux-8-gencloud-ppc64le" {
  iso_url            = local.iso_url_8_ppc64le
  iso_checksum       = local.iso_checksum_8_ppc64le
  http_directory     = var.http_directory
  shutdown_command   = var.root_shutdown_command
  ssh_username       = var.gencloud_ssh_username
  ssh_password       = var.gencloud_ssh_password
  ssh_timeout        = var.ssh_timeout
  boot_command       = local.gencloud_boot_command_8_ppc64le
  boot_wait          = var.gencloud_boot_wait_ppc64le
  accelerator        = "none"
  disk_interface     = "virtio-scsi"
  disk_size          = var.gencloud_disk_size
  disk_cache         = "unsafe"
  disk_discard       = "unmap"
  disk_detect_zeroes = "unmap"
  disk_compression   = true
  format             = "qcow2"
  headless           = var.headless
  machine_type       = "pseries,accel=kvm,kvm-type=HV"
  memory             = var.memory_ppc64le
  net_device         = "virtio-net"
  qemu_binary        = var.qemu_binary
  vm_name            = "AlmaLinux-8-GenericCloud-${var.os_ver_8}-${formatdate("YYYYMMDD", timestamp())}.ppc64le.qcow2"
  cpus               = var.cpus
}

# s390x is built under TCG (full-system emulation) on the x86_64 runners:
# there are no s390x runners and KVM cannot accelerate a foreign arch, so
# a build takes hours rather than minutes. s390x has no BIOS boot menu to
# type a boot_command into, so the installer kernel and initrd are booted
# directly (-kernel/-initrd, downloaded by shared-steps into
# var.s390x_boot_dir) with inst.ks= on the kernel command line - the same
# direct-kernel install oz performs on the Jenkins s390x host. The s390x
# kickstart carries the whole provisioning in its %post (no Ansible: hence
# communicator "none" and the 'except' on the provisioner below) and ends
# with 'reboot'; -no-reboot turns that reboot into a QEMU exit, which is
# what a communicator-less build waits for (up to shutdown_timeout). The
# kernel line deliberately has NO cio_ignore=all,!condev (the ISO's
# generic.prm carries it for LPAR/z/VM installs): in a QEMU guest the
# virtio NIC and disk are CCW devices too and would be ignored, leaving the
# installer with no network to fetch the kickstart and no disk to install
# on - it then waits forever with an idle CPU. The
# target disk is a blank qcow2 pre-created by shared-steps and grown to
# disk_size (disk_image = true): no boot ISO is attached, because
# s390-ccw-virtio has no IDE bus for Packer's default CD-ROM. The SCLP
# console is written to var.s390x_boot_dir/console.log for diagnostics.
source "qemu" "almalinux-8-gencloud-s390x" {
  iso_url            = "${var.s390x_boot_dir}/blank.qcow2"
  iso_checksum       = "none"
  disk_image         = true
  http_directory     = var.http_directory
  communicator       = "none"
  shutdown_timeout   = var.s390x_install_timeout
  boot_wait          = "10s"
  accelerator        = "tcg"
  disk_interface     = "virtio"
  disk_size          = var.gencloud_disk_size
  disk_cache         = "unsafe"
  disk_discard       = "unmap"
  disk_detect_zeroes = "unmap"
  disk_compression   = true
  format             = "qcow2"
  headless           = var.headless
  machine_type       = "s390-ccw-virtio"
  memory             = var.memory_s390x
  net_device         = "virtio-net"
  qemu_binary        = var.qemu_binary
  vm_name            = "AlmaLinux-8-GenericCloud-${var.os_ver_8}-${formatdate("YYYYMMDD", timestamp())}.s390x.qcow2"
  cpus               = var.cpus
  qemuargs = [
    ["-cpu", "max"],
    ["-kernel", "${var.s390x_boot_dir}/kernel.img"],
    ["-initrd", "${var.s390x_boot_dir}/initrd.img"],
    ["-append", "ro ramdisk_size=40000 console=ttysclp0 ip=dhcp inst.text inst.ks=http://{{ .HTTPIP }}:{{ .HTTPPort }}/almalinux-8.gencloud-s390x.ks"],
    ["-serial", "file:${var.s390x_boot_dir}/console.log"],
    ["-no-reboot"],
  ]
}

build {
  sources = [
    "source.qemu.almalinux-8-gencloud-x86_64",
    "source.qemu.almalinux-8-gencloud-aarch64",
    "source.qemu.almalinux-8-gencloud-ppc64le",
    "source.qemu.almalinux-8-gencloud-s390x",
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
    extra_arguments = [
      "--extra-vars",
      "is_unified_boot=true",
    ]
    only = ["qemu.almalinux-8-gencloud-x86_64"]
  }

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
    only = [
      "qemu.almalinux-8-gencloud-aarch64",
      "qemu.almalinux-8-gencloud-ppc64le",
    ]
  }
}
