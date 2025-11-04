# AlmaLinux OS 9 Packer template for Vagrant boxes

source "qemu" "almalinux-9" {
  iso_url            = local.iso_url_9_x86_64
  iso_checksum       = local.iso_checksum_9_x86_64
  http_directory     = var.http_directory
  shutdown_command   = var.vagrant_shutdown_command
  ssh_username       = var.vagrant_ssh_username
  ssh_password       = var.vagrant_ssh_password
  ssh_timeout        = var.ssh_timeout
  boot_command       = var.vagrant_boot_command_9_x86_64
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
  vm_name            = "AlmaLinux-9-Vagrant-Libvirt-${var.os_ver_9}-${formatdate("YYYYMMDD", timestamp())}.x86_64.qcow2"
  cpu_model          = "host"
  cpus               = var.cpus
  efi_boot           = true
  efi_firmware_code  = var.ovmf_code
  efi_firmware_vars  = var.ovmf_vars
  efi_drop_efivars   = true
}

source "virtualbox-iso" "almalinux-9" {
  iso_url              = local.iso_url_9_x86_64
  iso_checksum         = local.iso_checksum_9_x86_64
  http_directory       = var.http_directory
  shutdown_command     = var.vagrant_shutdown_command
  ssh_username         = var.vagrant_ssh_username
  ssh_password         = var.vagrant_ssh_password
  ssh_timeout          = var.ssh_timeout
  boot_command         = var.vagrant_boot_command_9_x86_64
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

source "hyperv-iso" "almalinux-9" {
  iso_url               = local.iso_url_9_x86_64
  iso_checksum          = local.iso_checksum_9_x86_64
  http_directory        = var.http_directory
  shutdown_command      = var.vagrant_shutdown_command
  communicator          = "ssh"
  ssh_username          = var.vagrant_ssh_username
  ssh_password          = var.vagrant_ssh_password
  ssh_timeout           = var.ssh_timeout
  boot_command          = var.vagrant_boot_command_9_x86_64
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

source "qemu" "almalinux-9-hyperv-x86_64" {
  iso_url            = local.iso_url_9_x86_64
  iso_checksum       = local.iso_checksum_9_x86_64
  http_directory     = var.http_directory
  shutdown_command   = var.vagrant_shutdown_command
  ssh_username       = var.vagrant_ssh_username
  ssh_password       = var.vagrant_ssh_password
  ssh_timeout        = var.ssh_timeout
  boot_command       = var.hyperv_boot_command_9_x86_64
  boot_wait          = var.boot_wait
  accelerator        = "kvm"
  disk_interface     = "virtio-scsi"
  disk_size          = var.vagrant_disk_size
  disk_cache         = "unsafe"
  disk_discard       = "unmap"
  disk_detect_zeroes = "unmap"
  format             = "raw"
  headless           = var.headless
  machine_type       = "q35"
  memory             = var.memory_x86_64
  net_device         = "virtio-net"
  qemu_binary        = var.qemu_binary
  vm_name            = "almalinux-9-hyperv-x86_64.raw"
  cpu_model          = "host"
  cpus               = var.cpus
  efi_boot           = true
  efi_firmware_code  = var.ovmf_code
  efi_firmware_vars  = var.ovmf_vars
  efi_drop_efivars   = true
}

source "vmware-iso" "almalinux-9" {
  iso_url                        = local.iso_url_9_x86_64
  iso_checksum                   = local.iso_checksum_9_x86_64
  http_directory                 = var.http_directory
  shutdown_command               = var.vagrant_shutdown_command
  ssh_username                   = var.vagrant_ssh_username
  ssh_password                   = var.vagrant_ssh_password
  ssh_timeout                    = var.ssh_timeout
  boot_command                   = var.vagrant_boot_command_9_x86_64
  boot_wait                      = var.boot_wait
  disk_size                      = var.vagrant_disk_size
  guest_os_type                  = "centos-64"
  version                        = 21
  vm_name                        = "AlmaLinux-9-Vagrant-VMware-${var.os_ver_9}-${formatdate("YYYYMMDD", timestamp())}.x86_64"
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

source "parallels-iso" "almalinux-9" {
  iso_url                = local.iso_url_9_x86_64
  iso_checksum           = local.iso_checksum_9_x86_64
  http_directory         = var.http_directory
  shutdown_command       = var.vagrant_shutdown_command
  ssh_username           = var.vagrant_ssh_username
  ssh_password           = var.vagrant_ssh_password
  ssh_timeout            = var.ssh_timeout
  boot_command           = var.vagrant_boot_command_9_x86_64_bios
  boot_wait              = var.boot_wait
  cpus                   = var.cpus
  disk_size              = var.vagrant_disk_size
  guest_os_type          = "centos"
  memory                 = var.memory_x86_64
  parallels_tools_flavor = var.parallels_tools_flavor_x86_64
}

source "vmware-iso" "almalinux-9-aarch64" {
  iso_url                        = local.iso_url_9_aarch64
  iso_checksum                   = local.iso_checksum_9_aarch64
  http_directory                 = var.http_directory
  shutdown_command               = var.vagrant_shutdown_command
  ssh_username                   = var.vagrant_ssh_username
  ssh_password                   = var.vagrant_ssh_password
  ssh_timeout                    = var.ssh_timeout
  boot_command                   = var.vagrant_boot_command_9_aarch64
  boot_wait                      = var.boot_wait
  disk_size                      = var.vagrant_disk_size
  guest_os_type                  = "arm-rhel9-64"
  version                        = 21
  vm_name                        = "AlmaLinux-9-Vagrant-VMware-${var.os_ver_9}-${formatdate("YYYYMMDD", timestamp())}.aarch64"
  firmware                       = "efi"
  cpus                           = var.cpus
  memory                         = var.memory_aarch64
  network_adapter_type           = "vmxnet3"
  headless                       = var.headless
  vmx_remove_ethernet_interfaces = true
  usb                            = true
  disk_adapter_type              = "nvme"
}

source "parallels-iso" "almalinux-9-aarch64" {
  iso_url                = local.iso_url_9_aarch64
  iso_checksum           = local.iso_checksum_9_aarch64
  http_directory         = var.http_directory
  shutdown_command       = var.vagrant_shutdown_command
  ssh_username           = var.vagrant_ssh_username
  ssh_password           = var.vagrant_ssh_password
  ssh_timeout            = var.ssh_timeout
  boot_command           = var.vagrant_boot_command_9_aarch64
  boot_wait              = var.boot_wait
  cpus                   = var.cpus
  disk_size              = var.vagrant_disk_size
  guest_os_type          = "centos"
  memory                 = var.memory_aarch64
  parallels_tools_flavor = var.parallels_tools_flavor_aarch64
}

source "virtualbox-iso" "almalinux-9-aarch64" {
  iso_url              = local.iso_url_9_aarch64
  iso_checksum         = local.iso_checksum_9_aarch64
  http_directory       = var.http_directory
  shutdown_command     = var.vagrant_shutdown_command
  ssh_username         = var.vagrant_ssh_username
  ssh_password         = var.vagrant_ssh_password
  ssh_timeout          = var.ssh_timeout
  boot_command         = var.vagrant_boot_command_9_aarch64
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

build {
  sources = [
    "source.qemu.almalinux-9",
    "source.virtualbox-iso.almalinux-9",
    "source.hyperv-iso.almalinux-9",
    "source.qemu.almalinux-9-hyperv-x86_64",
    "source.vmware-iso.almalinux-9",
    "source.parallels-iso.almalinux-9",
    "source.virtualbox-iso.almalinux-9-aarch64",
    "source.vmware-iso.almalinux-9-aarch64",
    "source.parallels-iso.almalinux-9-aarch64",
  ]

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
      "qemu.almalinux-9",
      "virtualbox-iso.almalinux-9",
      "vmware-iso.almalinux-9",
      "parallels-iso.almalinux-9",
      "virtualbox-iso.almalinux-9-aarch64",
      "vmware-iso.almalinux-9-aarch64",
      "parallels-iso.almalinux-9-aarch64",
    ]
  }

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
    only = ["hyperv-iso.almalinux-9"]
  }

  provisioner "ansible" {
    user                 = "vagrant"
    use_proxy            = false
    galaxy_file          = "./ansible/requirements.yml"
    galaxy_force_install = true
    collections_path     = "./ansible/collections"
    roles_path           = "./ansible/roles"
    playbook_file        = "./ansible/hyperv.yml"
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
    only = ["qemu.almalinux-9-hyperv-x86_64"]
  }

  provisioner "shell" {
    expect_disconnect = true
    inline            = ["sudo rm -fr /etc/ssh/*host*key*"]
    only              = [
      "hyperv-iso.almalinux-9",
      "qemu.almalinux-9-hyperv-x86_64",
    ]
  }

  post-processors {

    post-processor "vagrant" {
      compression_level = "9"
      output            = "AlmaLinux-9-Vagrant-{{.Provider}}-${var.os_ver_9}-${formatdate("YYYYMMDD", timestamp())}.x86_64.box"
      only = [
        "virtualbox-iso.almalinux-9",
        "hyperv-iso.almalinux-9",
        "vmware-iso.almalinux-9",
        "parallels-iso.almalinux-9",
      ]
    }

    post-processor "vagrant" {
      compression_level = "9"
      output            = "AlmaLinux-9-Vagrant-{{.Provider}}-${var.os_ver_9}-${formatdate("YYYYMMDD", timestamp())}.aarch64.box"
      only = [
        "virtualbox-iso.almalinux-9-aarch64",
        "vmware-iso.almalinux-9-aarch64",
        "parallels-iso.almalinux-9-aarch64",
      ]
    }

    post-processor "vagrant" {
      compression_level    = "9"
      vagrantfile_template = "tpl/vagrant/vagrantfile-libvirt.rb"
      output               = "AlmaLinux-9-Vagrant-{{.Provider}}-${var.os_ver_9}-${formatdate("YYYYMMDD", timestamp())}.x86_64.box"
      only                 = ["qemu.almalinux-9"]
    }

    # The shell-local post-processor creates the box file for the Hyper-V, with the following content:
    # - Virtual Machines/box.xml, copied from the templated file
    # - Virtual Hard Disks/almalinux.vhdx, converted with qemu-img from the raw image
    # - Vagrantfile, empty file
    # - metadata.json, with the architecture and provider information
    #
    # These files are packed by the tar+gzip to match Hyper-V box file format
    #
    # The predefined vagrant post-processor is not used, because it skips 'Virtual Machines' and 'Virtual Hard Disks' directories.
    #
    # The raw image is not used by the Hyper-V, but it is kept for the GitHub Actions workflow to extract packages list from it
    #
    post-processor "shell-local" {
      inline = [
        "mkdir -p '${source.name}/Virtual Machines' '${source.name}/Virtual Hard Disks'",
        "touch ${source.name}/Vagrantfile",
        "echo '{\"architecture\":\"amd64\",\"provider\":\"hyperv\"}' > ${source.name}/metadata.json",
        "cp -a ./tpl/vagrant/hyperv/box.xml '${source.name}/Virtual Machines/box.xml'",
        "qemu-img convert -f raw -O vhdx output-${source.name}/${source.name}.raw '${source.name}/Virtual Hard Disks/almalinux.vhdx'",
        "cd ${source.name}",
        "tar --use-compress-program='gzip -9' -cvf ../AlmaLinux-9-Vagrant-hyperv-${var.os_ver_9}-${formatdate("YYYYMMDD", timestamp())}.x86_64.box .",
        "mv ../output-${source.name}/${source.name}.raw ../AlmaLinux-9-Vagrant-hyperv-${var.os_ver_9}-${formatdate("YYYYMMDD", timestamp())}.x86_64.raw"
      ]
      only = ["qemu.almalinux-9-hyperv-x86_64"]
    }
  }
}
