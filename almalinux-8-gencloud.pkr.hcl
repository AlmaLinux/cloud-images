/*
 * AlmaLinux OS 8 Packer template for building Generic Cloud (OpenStack compatible) images.
 */

source "qemu" "almalinux-8-gencloud-x86_64" {
  iso_url            = var.iso_url
  iso_checksum       = var.iso_checksum
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
  memory             = var.memory
  net_device         = "virtio-net"
  qemu_binary        = var.qemu_binary
  vm_name            = "almalinux-8-GenericCloud-8.4.x86_64.qcow2"
  boot_wait          = var.boot_wait
  boot_command       = var.gencloud_boot_command
  qemu_img_args      {
    convert = ["-o", "compat=0.10"]
    create  = ["-o", "compat=0.10"]
  }
}


build {
  sources = ["qemu.almalinux-8-gencloud-x86_64"]

  provisioner "ansible" {
    playbook_file    = "./ansible/gencloud.yml"
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
