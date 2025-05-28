# AlmaLinux OS 10 Packer template for Vagrant boxes

source "hyperv-iso" "almalinux_10_vagrant_hyperv_x86_64" {
  iso_url               = local.iso_url_10_x86_64
  iso_checksum          = local.iso_checksum_10_x86_64
  http_directory        = var.http_directory
  shutdown_command      = var.vagrant_shutdown_command
  communicator          = "ssh"
  ssh_username          = var.vagrant_ssh_username
  ssh_password          = var.vagrant_ssh_password
  ssh_timeout           = var.ssh_timeout
  boot_command          = var.vagrant_boot_command_10_x86_64
  boot_wait             = var.boot_wait
  disk_size             = var.vagrant_disk_size
  disk_block_size       = 1
  memory                = var.memory_x86_64
  switch_name           = var.hyperv_switch_name
  cpus                  = var.cpus
  generation            = 2
  enable_dynamic_memory = true
  headless              = var.headless
}

source "qemu" "almalinux_10_vagrant_libvirt_x86_64" {
  iso_url            = local.iso_url_10_x86_64
  iso_checksum       = local.iso_checksum_10_x86_64
  http_directory     = var.http_directory
  shutdown_command   = var.vagrant_shutdown_command
  ssh_username       = var.vagrant_ssh_username
  ssh_password       = var.vagrant_ssh_password
  ssh_timeout        = var.ssh_timeout
  boot_command       = var.vagrant_boot_command_10_x86_64
  boot_wait          = var.boot_wait
  accelerator        = "kvm"
  disk_interface     = "virtio-scsi"
  disk_size          = var.vagrant_disk_size
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
  vm_name            = "AlmaLinux-10-Vagrant-Libvirt-${var.os_ver_10}-${formatdate("YYYYMMDD", timestamp())}.${var.build_number}.x86_64.qcow2"
  cpu_model          = "host"
  cpus               = var.cpus
  efi_boot           = true
  efi_firmware_code  = var.ovmf_code
  efi_firmware_vars  = var.ovmf_vars
  efi_drop_efivars   = true
}

source "virtualbox-iso" "almalinux_10_vagrant_virtualbox_x86_64" {
  iso_url              = local.iso_url_10_x86_64
  iso_checksum         = local.iso_checksum_10_x86_64
  http_directory       = var.http_directory
  shutdown_command     = var.vagrant_shutdown_command
  ssh_username         = var.vagrant_ssh_username
  ssh_password         = var.vagrant_ssh_password
  ssh_timeout          = var.ssh_timeout
  boot_command         = var.vagrant_boot_command_10_x86_64
  boot_wait            = var.boot_wait
  firmware             = "efi"
  disk_size            = var.vagrant_disk_size
  guest_os_type        = "RedHat_64"
  cpus                 = var.cpus
  memory               = var.memory_x86_64
  headless             = var.headless
  hard_drive_interface = "sata"
  iso_interface        = "sata"
  vboxmanage           = [["modifyvm", "{{.Name}}", "--nat-localhostreachable1", "on"]]
  vboxmanage_post = [
    ["modifyvm", "{{.Name}}", "--memory", var.post_memory],
    ["modifyvm", "{{.Name}}", "--cpus", var.post_cpus],
  ]
}

source "vmware-iso" "almalinux_10_vagrant_vmware_x86_64" {
  iso_url                        = local.iso_url_10_x86_64
  iso_checksum                   = local.iso_checksum_10_x86_64
  http_directory                 = var.http_directory
  shutdown_command               = var.vagrant_shutdown_command
  ssh_username                   = var.vagrant_ssh_username
  ssh_password                   = var.vagrant_ssh_password
  ssh_timeout                    = var.ssh_timeout
  boot_command                   = var.vagrant_boot_command_10_x86_64
  boot_wait                      = var.boot_wait
  disk_size                      = var.vagrant_disk_size
  guest_os_type                  = "centos-64"
  version                        = 21
  vm_name                        = "AlmaLinux-10-Vagrant-VMware-${var.os_ver_10}-${formatdate("YYYYMMDD", timestamp())}.${var.build_number}.x86_64"
  firmware                       = "efi"
  cpus                           = var.cpus
  memory                         = var.memory_x86_64
  network_adapter_type           = "vmxnet3"
  headless                       = var.headless
  vmx_remove_ethernet_interfaces = true
  vmx_data = {
    "cpuid.coresPerSocket" = "1"
  }
  vmx_data_post = {
    "memsize"  = var.post_memory
    "numvcpus" = var.post_cpus
  }
}

source "parallels-iso" "almalinux_10_vagrant_parallels_aarch64" {
  iso_url                = local.iso_url_10_aarch64
  iso_checksum           = local.iso_checksum_10_aarch64
  http_directory         = var.http_directory
  shutdown_command       = var.vagrant_shutdown_command
  ssh_username           = var.vagrant_ssh_username
  ssh_password           = var.vagrant_ssh_password
  ssh_timeout            = var.ssh_timeout
  boot_command           = var.vagrant_boot_command_10_aarch64
  boot_wait              = var.boot_wait
  cpus                   = var.cpus
  disk_size              = var.vagrant_disk_size
  guest_os_type          = "centos"
  memory                 = var.memory_aarch64
  parallels_tools_flavor = var.parallels_tools_flavor_aarch64
}

source "virtualbox-iso" "almalinux_10_vagrant_virtualbox_aarch64" {
  iso_url              = local.iso_url_10_aarch64
  iso_checksum         = local.iso_checksum_10_aarch64
  http_directory       = var.http_directory
  shutdown_command     = var.vagrant_shutdown_command
  ssh_username         = var.vagrant_ssh_username
  ssh_password         = var.vagrant_ssh_password
  ssh_timeout          = var.ssh_timeout
  boot_command         = var.vagrant_boot_command_10_aarch64
  boot_wait            = var.boot_wait
  disk_size            = var.vagrant_disk_size
  guest_os_type        = "RedHat_64"
  cpus                 = var.cpus
  memory               = var.memory_aarch64
  headless             = var.headless
  hard_drive_interface = "sata"
  vboxmanage           = [["modifyvm", "{{.Name}}", "--nat-localhostreachable1", "on"]]
  vboxmanage_post = [
    ["modifyvm", "{{.Name}}", "--memory", var.post_memory],
    ["modifyvm", "{{.Name}}", "--cpus", var.post_cpus],
  ]
}

source "vmware-iso" "almalinux_10_vagrant_vmware_aarch64" {
  iso_url                        = local.iso_url_10_aarch64
  iso_checksum                   = local.iso_checksum_10_aarch64
  http_directory                 = var.http_directory
  shutdown_command               = var.vagrant_shutdown_command
  ssh_username                   = var.vagrant_ssh_username
  ssh_password                   = var.vagrant_ssh_password
  ssh_timeout                    = var.ssh_timeout
  boot_command                   = var.vagrant_boot_command_10_aarch64
  boot_wait                      = var.boot_wait
  disk_size                      = var.vagrant_disk_size
  guest_os_type                  = "arm-rhel9-64"
  version                        = 21
  vm_name                        = "AlmaLinux-10-Vagrant-VMware-${var.os_ver_10}-${formatdate("YYYYMMDD", timestamp())}.${var.build_number}.aarch64"
  firmware                       = "efi"
  cpus                           = var.cpus
  memory                         = var.memory_aarch64
  network_adapter_type           = "vmxnet3"
  headless                       = var.headless
  vmx_remove_ethernet_interfaces = true
  usb                            = true
  disk_adapter_type              = "nvme"
}

source "hyperv-iso" "almalinux_10_vagrant_hyperv_x86_64_v2" {
  iso_url               = local.iso_url_10_x86_64_v2
  iso_checksum          = local.iso_checksum_10_x86_64_v2
  http_directory        = var.http_directory
  shutdown_command      = var.vagrant_shutdown_command
  communicator          = "ssh"
  ssh_username          = var.vagrant_ssh_username
  ssh_password          = var.vagrant_ssh_password
  ssh_timeout           = var.ssh_timeout
  boot_command          = var.vagrant_boot_command_10_x86_64_v2
  boot_wait             = var.boot_wait
  disk_size             = var.vagrant_disk_size
  disk_block_size       = 1
  memory                = var.memory_x86_64
  switch_name           = var.hyperv_switch_name
  cpus                  = var.cpus
  generation            = 2
  enable_dynamic_memory = true
  headless              = var.headless
}

source "qemu" "almalinux_10_vagrant_libvirt_x86_64_v2" {
  iso_url            = local.iso_url_10_x86_64_v2
  iso_checksum       = local.iso_checksum_10_x86_64_v2
  http_directory     = var.http_directory
  shutdown_command   = var.vagrant_shutdown_command
  ssh_username       = var.vagrant_ssh_username
  ssh_password       = var.vagrant_ssh_password
  ssh_timeout        = var.ssh_timeout
  boot_command       = var.vagrant_boot_command_10_x86_64_v2
  boot_wait          = var.boot_wait
  accelerator        = "kvm"
  disk_interface     = "virtio-scsi"
  disk_size          = var.vagrant_disk_size
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
  vm_name            = "AlmaLinux-10-Vagrant-Libvirt-${var.os_ver_10}-${formatdate("YYYYMMDD", timestamp())}.${var.build_number}.x86_64_v2.qcow2"
  cpu_model          = "Nehalem"
  cpus               = var.cpus
  efi_boot           = true
  efi_firmware_code  = var.ovmf_code
  efi_firmware_vars  = var.ovmf_vars
  efi_drop_efivars   = true
}

source "virtualbox-iso" "almalinux_10_vagrant_virtualbox_x86_64_v2" {
  iso_url              = local.iso_url_10_x86_64_v2
  iso_checksum         = local.iso_checksum_10_x86_64_v2
  http_directory       = var.http_directory
  shutdown_command     = var.vagrant_shutdown_command
  ssh_username         = var.vagrant_ssh_username
  ssh_password         = var.vagrant_ssh_password
  ssh_timeout          = var.ssh_timeout
  boot_command         = var.vagrant_boot_command_10_x86_64_v2
  boot_wait            = var.boot_wait
  firmware             = "efi"
  disk_size            = var.vagrant_disk_size
  guest_os_type        = "RedHat_64"
  cpus                 = var.cpus
  memory               = var.memory_x86_64
  headless             = var.headless
  hard_drive_interface = "sata"
  iso_interface        = "sata"
  vboxmanage           = [["modifyvm", "{{.Name}}", "--nat-localhostreachable1", "on"]]
  vboxmanage_post = [
    ["modifyvm", "{{.Name}}", "--memory", var.post_memory],
    ["modifyvm", "{{.Name}}", "--cpus", var.post_cpus],
  ]
}

source "vmware-iso" "almalinux_10_vagrant_vmware_x86_64_v2" {
  iso_url                        = local.iso_url_10_x86_64_v2
  iso_checksum                   = local.iso_checksum_10_x86_64_v2
  http_directory                 = var.http_directory
  shutdown_command               = var.vagrant_shutdown_command
  ssh_username                   = var.vagrant_ssh_username
  ssh_password                   = var.vagrant_ssh_password
  ssh_timeout                    = var.ssh_timeout
  boot_command                   = var.vagrant_boot_command_10_x86_64_v2
  boot_wait                      = var.boot_wait
  disk_size                      = var.vagrant_disk_size
  guest_os_type                  = "centos-64"
  version                        = 21
  vm_name                        = "AlmaLinux-10-Vagrant-VMware-${var.os_ver_10}-${formatdate("YYYYMMDD", timestamp())}.${var.build_number}.x86_64_v2"
  firmware                       = "efi"
  cpus                           = var.cpus
  memory                         = var.memory_x86_64
  network_adapter_type           = "vmxnet3"
  headless                       = var.headless
  vmx_remove_ethernet_interfaces = true
  vmx_data = {
    "cpuid.coresPerSocket" = "1"
  }
  vmx_data_post = {
    "memsize"  = var.post_memory
    "numvcpus" = var.post_cpus
  }
}

build {
  sources = [
    "source.hyperv-iso.almalinux_10_vagrant_hyperv_x86_64",
    "source.qemu.almalinux_10_vagrant_libvirt_x86_64",
    "source.virtualbox-iso.almalinux_10_vagrant_virtualbox_x86_64",
    "source.vmware-iso.almalinux_10_vagrant_vmware_x86_64",
    "source.parallels-iso.almalinux_10_vagrant_parallels_aarch64",
    "source.virtualbox-iso.almalinux_10_vagrant_virtualbox_aarch64",
    "source.vmware-iso.almalinux_10_vagrant_vmware_aarch64",
    "source.hyperv-iso.almalinux_10_vagrant_hyperv_x86_64_v2",
    "source.qemu.almalinux_10_vagrant_libvirt_x86_64_v2",
    "source.virtualbox-iso.almalinux_10_vagrant_virtualbox_x86_64_v2",
    "source.vmware-iso.almalinux_10_vagrant_vmware_x86_64_v2",
  ]

  provisioner "ansible" {
    user                 = "vagrant"
    use_proxy            = false
    galaxy_file          = "./ansible/requirements.yml"
    galaxy_force_install = true
    collections_path     = "./ansible/collections"
    roles_path           = "./ansible/roles"
    playbook_file        = "./ansible/vagrant.yml"
    ansible_env_vars = [
      "ANSIBLE_PIPELINING=True",
      "ANSIBLE_REMOTE_TEMP=/tmp",
      "ANSIBLE_SCP_EXTRA_ARGS=-O",
      "ANSIBLE_HOST_KEY_CHECKING=False",
    ]
    extra_arguments = [
      "--extra-vars",
      "packer_provider=${source.type} ansible_ssh_pass=vagrant",
    ]
    only = [
      "hyperv-iso.almalinux_10_vagrant_hyperv_x86_64",
      "hyperv-iso.almalinux_10_vagrant_hyperv_x86_64_v2",
    ]
  }

  provisioner "shell" {
    expect_disconnect = true
    inline            = ["sudo rm -fr /etc/ssh/*host*key*"]
    only = [
      "hyperv-iso.almalinux_10_vagrant_hyperv_x86_64",
      "hyperv-iso.almalinux_10_vagrant_hyperv_x86_64_v2",
    ]
  }

  provisioner "ansible" {
    user                 = "vagrant"
    galaxy_file          = "./ansible/requirements.yml"
    galaxy_force_install = true
    collections_path     = "./ansible/collections"
    roles_path           = "./ansible/roles"
    playbook_file        = "./ansible/vagrant.yml"
    ansible_env_vars = [
      "ANSIBLE_PIPELINING=True",
      "ANSIBLE_REMOTE_TEMP=/tmp",
      "ANSIBLE_SCP_EXTRA_ARGS=-O",
    ]
    extra_arguments = [
      "--extra-vars",
      "packer_provider=${source.type}",
    ]
    only = [
      "qemu.almalinux_10_vagrant_libvirt_x86_64",
      "virtualbox-iso.almalinux_10_vagrant_virtualbox_x86_64",
      "vmware-iso.almalinux_10_vagrant_vmware_x86_64",
      "parallels-iso.almalinux_10_vagrant_parallels_aarch64",
      "virtualbox-iso.almalinux_10_vagrant_virtualbox_aarch64",
      "vmware-iso.almalinux_10_vagrant_vmware_aarch64",
      "qemu.almalinux_10_vagrant_libvirt_x86_64_v2",
      "virtualbox-iso.almalinux_10_vagrant_virtualbox_x86_64_v2",
      "vmware-iso.almalinux_10_vagrant_vmware_x86_64_v2",
    ]
  }

  post-processors {

    post-processor "vagrant" {
      compression_level = "9"
      output            = "AlmaLinux-10-Vagrant-{{.Provider}}-${var.os_ver_10}-${formatdate("YYYYMMDD", timestamp())}.${var.build_number}.x86_64.box"
      only = [
        "hyperv-iso.almalinux_10_vagrant_hyperv_x86_64",
        "virtualbox-iso.almalinux_10_vagrant_virtualbox_x86_64",
        "vmware-iso.almalinux_10_vagrant_vmware_x86_64",
      ]
    }

    post-processor "vagrant" {
      compression_level    = "9"
      vagrantfile_template = "tpl/vagrant/vagrantfile-libvirt.rb"
      output               = "AlmaLinux-10-Vagrant-{{.Provider}}-${var.os_ver_10}-${formatdate("YYYYMMDD", timestamp())}.${var.build_number}.x86_64.box"
      only                 = ["qemu.almalinux_10_vagrant_libvirt_x86_64"]
    }

    post-processor "vagrant" {
      compression_level = "9"
      output            = "AlmaLinux-10-Vagrant-{{.Provider}}-${var.os_ver_10}-${formatdate("YYYYMMDD", timestamp())}.${var.build_number}.aarch64.box"
      only = [
        "source.parallels-iso.almalinux_10_vagrant_parallels_aarch64",
        "source.virtualbox-iso.almalinux_10_vagrant_virtualbox_aarch64",
        "source.vmware-iso.almalinux_10_vagrant_vmware_aarch64",
      ]
    }

    post-processor "vagrant" {
      compression_level = "9"
      output            = "AlmaLinux-10-Vagrant-{{.Provider}}-${var.os_ver_10}-${formatdate("YYYYMMDD", timestamp())}.${var.build_number}.x86_64_v2.box"
      only = [
        "hyperv-iso.almalinux_10_vagrant_hyperv_x86_64_v2",
        "virtualbox-iso.almalinux_10_vagrant_virtualbox_x86_64_v2",
        "vmware-iso.almalinux_10_vagrant_vmware_x86_64_v2",
      ]
    }

    post-processor "vagrant" {
      compression_level    = "9"
      vagrantfile_template = "tpl/vagrant/vagrantfile-libvirt.rb"
      output               = "AlmaLinux-10-Vagrant-{{.Provider}}-${var.os_ver_10}-${formatdate("YYYYMMDD", timestamp())}.${var.build_number}.x86_64_v2.box"
      only                 = ["qemu.almalinux_10_vagrant_libvirt_x86_64_v2"]
    }
  }
}
