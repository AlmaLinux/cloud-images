/*
 * CentOS 9 Stream Packer template for building Vagrant boxes.
 */

variables {
  c9s_iso_url_x86_64       = "http://mirror.stream.centos.org/9-stream/BaseOS/x86_64/iso/CentOS-Stream-9-20211201.1-x86_64-boot.iso"
  c9s_iso_checksum_x86_64  = "file:http://mirror.stream.centos.org/9-stream/BaseOS/x86_64/iso/CentOS-Stream-9-20211201.1-x86_64-boot.iso.SHA256SUM"
  c9s_vagrant_boot_command = [
    "<tab> inst.text inst.ks=http://{{ .HTTPIP }}:{{ .HTTPPort }}/centos-9.vagrant.ks<enter><wait>"
  ]
}

source "vmware-iso" "centos-9" {
  iso_url          = var.c9s_iso_url_x86_64
  iso_checksum     = var.c9s_iso_checksum_x86_64
  boot_command     = var.c9s_vagrant_boot_command
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
  vmx_data = {
    "cpuid.coresPerSocket" : "1"
  }
  vmx_data_post = {
    "memsize" : var.post_memory
    "numvcpus" : var.post_cpus
  }

  vmx_remove_ethernet_interfaces = true
}

source "parallels-iso" "centos-9" {
  iso_checksum           = var.c9s_iso_checksum_x86_64
  iso_url                = var.c9s_iso_url_x86_64
  boot_command           = var.c9s_vagrant_boot_command
  boot_wait              = var.boot_wait
  cpus                   = var.cpus
  memory                 = var.memory
  disk_size              = var.vagrant_disk_size
  parallels_tools_flavor = var.parallels_tools_flavor_x86_64
  http_directory         = var.http_directory
  guest_os_type          = "centos"
  shutdown_command       = var.vagrant_shutdown_command
  ssh_username           = var.vagrant_ssh_username
  ssh_password           = var.vagrant_ssh_password
  ssh_timeout            = var.ssh_timeout
}

source "qemu" "centos-9" {
  iso_checksum       = var.c9s_iso_checksum_x86_64
  iso_url            = var.c9s_iso_url_x86_64
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
  qemu_binary        = var.qemu_binary
  vm_name            = "centos-9"
  boot_wait          = var.boot_wait
  boot_command       = var.c9s_vagrant_boot_command
}

source "virtualbox-iso" "centos-9" {
  iso_checksum         = var.c9s_iso_checksum_x86_64
  iso_url              = var.c9s_iso_url_x86_64
  boot_command         = var.c9s_vagrant_boot_command
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
  vboxmanage_post = [
    ["modifyvm", "{{.Name}}", "--memory", var.post_memory],
    ["modifyvm", "{{.Name}}", "--cpus", var.post_cpus]
  ]
}

build {
  sources = [
    "sources.vmware-iso.centos-9",
    "sources.parallels-iso.centos-9",
    "sources.qemu.centos-9",
    "sources.virtualbox-iso.centos-9"
  ]

  provisioner "ansible" {
    playbook_file    = "./ansible/vagrant-box.yml"
    galaxy_file      = "./ansible/requirements.yml"
    roles_path       = "./ansible/roles"
    collections_path = "./ansible/collections"
    ansible_env_vars = [
      "ANSIBLE_PIPELINING=True",
      "ANSIBLE_REMOTE_TEMP=/tmp",
      "ANSIBLE_SSH_ARGS='-o ControlMaster=no -o ControlPersist=180s -o ServerAliveInterval=120s -o TCPKeepAlive=yes'"
    ]
    extra_arguments  = [
      "--extra-vars",
      "packer_provider=${source.type}"
    ]
  }

  post-processors {
    post-processor "vagrant" {
      compression_level = "9"
      output            = "centos-9-x86_64.{{isotime \"20060102\"}}.{{.Provider}}.box"
    }
  }
}
