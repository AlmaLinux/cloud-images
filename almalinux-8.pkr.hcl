variables {
  iso_url = "https://repo.almalinux.org/almalinux/8.3/isos/x86_64/AlmaLinux-8.3-x86_64-boot.iso"
  iso_checksum = "file:https://repo.almalinux.org/almalinux/8.3/isos/x86_64/CHECKSUM"
  headless = true
  boot_command = [
    "<tab> text ks=http://{{ .HTTPIP }}:{{ .HTTPPort }}/almalinux-8.vagrant.ks<enter><wait>"
  ]
  boot_wait = "10s"
  http_directory = "http"
  shutdown_command = "echo vagrant | sudo -S /sbin/shutdown -hP now"
  cpus = 2
  memory = 2048
  disk_size = 20000
  ssh_username = "vagrant"
  ssh_password = "vagrant"
  ssh_timeout = "3600s"
  post_memory = 1024
  post_cpus = 1
}


source "virtualbox-iso" "almalinux-8" {
  iso_url = var.iso_url
  iso_checksum = var.iso_checksum
  boot_command = var.boot_command
  boot_wait = var.boot_wait
  cpus = var.cpus
  memory = var.memory
  disk_size = var.disk_size
  headless = var.headless
  http_directory = var.http_directory
  guest_os_type = "RedHat_64"
  shutdown_command = var.shutdown_command
  ssh_username = var.ssh_username
  ssh_password = var.ssh_password
  ssh_timeout = var.ssh_timeout
  hard_drive_interface = "sata"
  vboxmanage_post = [
    ["modifyvm", "{{.Name}}", "--memory", var.post_memory],
    ["modifyvm", "{{.Name}}", "--cpus", var.post_cpus]
  ]
}


source "vmware-iso" "almalinux-8" {
  iso_url = var.iso_url
  iso_checksum = var.iso_checksum
  boot_command = var.boot_command
  boot_wait = var.boot_wait
  cpus = var.cpus
  memory = var.memory
  disk_size = var.disk_size
  headless = var.headless
  http_directory = var.http_directory
  guest_os_type = "centos-64"
  shutdown_command = var.shutdown_command
  ssh_username = var.ssh_username
  ssh_password = var.ssh_password
  ssh_timeout = var.ssh_timeout
  vmx_data = {
    "cpuid.coresPerSocket": "1"
  }
  vmx_data_post = {
    "memsize": var.post_memory
    "numvcpus": var.post_cpus
  }
  vmx_remove_ethernet_interfaces = true
}


source "qemu" "almalinux-8" {
  iso_checksum       = var.iso_checksum
  iso_url            = var.iso_url
  shutdown_command   = var.shutdown_command
  accelerator        = "kvm"
  http_directory     = var.http_directory
  ssh_username       = var.ssh_username
  ssh_password       = var.ssh_password
  ssh_timeout        = var.ssh_timeout
  cpus               = var.cpus
  disk_interface     = "virtio-scsi"
  disk_size          = var.disk_size
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
  boot_command       = var.boot_command
}

build {
  sources = ["sources.virtualbox-iso.almalinux-8", "sources.vmware-iso.almalinux-8", "sources.qemu.almalinux-8"]

  provisioner "ansible" {
    playbook_file = "./ansible/vagrant-box.yml"
    galaxy_file = "./ansible/requirements.yml"
    roles_path = "./ansible/roles"
    collections_path = "./ansible/collections"
    ansible_env_vars = [
      "ANSIBLE_SSH_ARGS='-o ControlMaster=no -o ControlPersist=180s -o ServerAliveInterval=120s -o TCPKeepAlive=yes'"
    ]
    extra_arguments = ["--extra-vars", "packer_provider=${source.type}"]
  }

  post-processor "vagrant" {
    compression_level = "9"
    output = "almalinux-8-x86_64.{{isotime \"20060102\"}}.{{.Provider}}.box"
    except = ["qemu.almalinux-8"]
  }

  post-processor "vagrant" {
    compression_level = "9"
    vagrantfile_template = "tpl/vagrant/vagrantfile-libvirt.tpl"
    output = "almalinux-8-x86_64.{{isotime \"20060102\"}}.{{.Provider}}.box"
    only = ["qemu.almalinux-8"]
  }
}
