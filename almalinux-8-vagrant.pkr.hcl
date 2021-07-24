/*
 * AlmaLinux OS 8 Packer template for building Vagrant boxes.
 */

source "hyperv-iso" "almalinux-8" {
  iso_url               = var.iso_url
  iso_checksum          = var.iso_checksum
  boot_command          = var.vagrant_efi_boot_command
  boot_wait             = var.boot_wait
  generation            = 2
  switch_name           = var.hyperv_switch_name
  cpus                  = var.cpus
  memory                = var.memory
  enable_dynamic_memory = true
  disk_size             = var.vagrant_disk_size
  disk_block_size       = 1
  headless              = var.headless
  http_directory        = var.http_directory
  shutdown_command      = var.vagrant_shutdown_command
  communicator          = "ssh"
  ssh_username          = var.vagrant_ssh_username
  ssh_password          = var.vagrant_ssh_password
  ssh_timeout           = var.ssh_timeout
}


source "virtualbox-iso" "almalinux-8" {
  iso_url              = var.iso_url
  iso_checksum         = var.iso_checksum
  boot_command         = var.vagrant_boot_command
  boot_wait            = var.boot_wait
  cpus                 = var.cpus
  memory               = var.memory
  disk_size            = var.vagrant_disk_size
  headless             = var.headless
  http_directory       = var.http_directory
  guest_os_type        = "RedHat_64"
  shutdown_command     = var.vagrant_shutdown_command
  ssh_username         = var.vagrant_ssh_username
  ssh_password         = var.vagrant_ssh_password
  ssh_timeout          = var.ssh_timeout
  hard_drive_interface = "sata"
  vboxmanage_post      = [
    ["modifyvm", "{{.Name}}", "--memory", var.post_memory],
    ["modifyvm", "{{.Name}}", "--cpus", var.post_cpus]
  ]
}


source "vmware-iso" "almalinux-8" {
  iso_url          = var.iso_url
  iso_checksum     = var.iso_checksum
  boot_command     = var.vagrant_boot_command
  boot_wait        = var.boot_wait
  cpus             = var.cpus
  memory           = var.memory
  disk_size        = var.vagrant_disk_size
  headless         = var.headless
  http_directory   = var.http_directory
  guest_os_type    = "centos-64"
  shutdown_command = var.vagrant_shutdown_command
  ssh_username     = var.vagrant_ssh_username
  ssh_password     = var.vagrant_ssh_password
  ssh_timeout      = var.ssh_timeout
  vmx_data         = {
    "cpuid.coresPerSocket": "1"
  }
  vmx_data_post    = {
    "memsize": var.post_memory
    "numvcpus": var.post_cpus
  }

  vmx_remove_ethernet_interfaces = true
}


source "qemu" "almalinux-8" {
  iso_checksum       = var.iso_checksum
  iso_url            = var.iso_url
  shutdown_command   = var.vagrant_shutdown_command
  accelerator        = "kvm"
  http_directory     = var.http_directory
  ssh_username       = var.vagrant_ssh_username
  ssh_password       = var.vagrant_ssh_password
  ssh_timeout        = var.ssh_timeout
  cpus               = var.cpus
  disk_interface     = "virtio-scsi"
  disk_size          = var.vagrant_disk_size
  disk_cache         = "unsafe"
  disk_discard       = "unmap"
  disk_detect_zeroes = "unmap"
  disk_compression   = true
  format             = "qcow2"
  headless           = var.headless
  memory             = var.memory
  net_device         = "virtio-net"
  vm_name            = "almalinux-8"
  boot_wait          = var.boot_wait
  boot_command       = var.vagrant_boot_command
}


build {
  sources = [
    "sources.virtualbox-iso.almalinux-8",
    "sources.vmware-iso.almalinux-8",
    "sources.qemu.almalinux-8"
  ]

  provisioner "ansible" {
    playbook_file    = "./ansible/vagrant-box.yml"
    galaxy_file      = "./ansible/requirements.yml"
    roles_path       = "./ansible/roles"
    collections_path = "./ansible/collections"
    ansible_env_vars = [
      "ANSIBLE_PIPELINING=True",
      "ANSIBLE_SSH_ARGS='-o ControlMaster=no -o ControlPersist=180s -o ServerAliveInterval=120s -o TCPKeepAlive=yes'"
    ]
    extra_arguments  = [
      "--extra-vars",
      "packer_provider=${source.type}"
    ]
  }

  post-processor "vagrant" {
    compression_level = "9"
    output            = "almalinux-8-x86_64.{{isotime \"20060102\"}}.{{.Provider}}.box"
    except            = [
      "qemu.almalinux-8"
    ]
  }

  post-processor "vagrant" {
    compression_level    = "9"
    vagrantfile_template = "tpl/vagrant/vagrantfile-libvirt.tpl"
    output               = "almalinux-8-x86_64.{{isotime \"20060102\"}}.{{.Provider}}.box"
    only                 = [
      "qemu.almalinux-8"
    ]
  }
}


build {
  sources = ["sources.hyperv-iso.almalinux-8"]

  provisioner "ansible" {
    user = "vagrant"
    use_proxy = false
    playbook_file    = "./ansible/vagrant-box.yml"
    galaxy_file      = "./ansible/requirements.yml"
    roles_path       = "./ansible/roles"
    collections_path = "./ansible/collections"
    ansible_env_vars = [
      "ANSIBLE_PIPELINING=True",
      "ANSIBLE_SSH_ARGS='-o ControlMaster=no -o ControlPersist=180s -o ServerAliveInterval=120s -o TCPKeepAlive=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null'"
    ]
    extra_arguments  = [
      "--extra-vars",
      "packer_provider=${source.type} ansible_ssh_pass=vagrant"
    ]
  }

  provisioner "shell" {
    expect_disconnect = true
    inline = [
      "sudo rm -fr /etc/ssh/*host*key*"
    ]
  }

  post-processor "vagrant" {
    compression_level = "9"
    output            = "almalinux-8-x86_64.{{isotime \"20060102\"}}.{{.Provider}}.box"
    except            = [
      "qemu.almalinux-8"
    ]
  }
}
