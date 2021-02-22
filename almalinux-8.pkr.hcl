source "virtualbox-iso" "almalinux-8" {
  guest_os_type = "RedHat_64"
  iso_url = "https://repo.almalinux.org/almalinux/8.3-rc/isos/x86_64/AlmaLinux-8.3-rc-1-x86_64-boot.iso"
  iso_checksum = "file:https://repo.almalinux.org/almalinux/8.3-rc/isos/x86_64/CHECKSUM"
  hard_drive_interface = "sata"
  cpus = "2"
  memory = "2048"
  headless = false
  http_directory = "http"
  ssh_username = "vagrant"
  ssh_password = "vagrant"
  shutdown_command = "echo vagrant | sudo -S /sbin/shutdown -hP now"
  boot_command = ["<tab> text ks=http://{{ .HTTPIP }}:{{ .HTTPPort }}/almalinux-8.vagrant.ks<enter><wait>"]
  boot_wait = "10s"
  ssh_wait_timeout = "3600s"
  disk_size = 20000
  vboxmanage_post = [
    ["modifyvm", "{{.Name}}", "--memory", "1024"],
    ["modifyvm", "{{.Name}}", "--cpus", "1"]
  ]
}

build {
  sources = ["sources.virtualbox-iso.almalinux-8"]

  provisioner "ansible" {
    playbook_file = "./ansible/vagrant-virtualbox.yml"
    galaxy_file = "./ansible/requirements.yml"
    roles_path = "./ansible/roles"
    collections_path = "./ansible/collections"
    ansible_env_vars = [
      "ANSIBLE_SSH_ARGS='-o ControlMaster=no -o ControlPersist=180s -o ServerAliveInterval=120s -o TCPKeepAlive=yes'"
    ]
    only = ["virtualbox-iso.almalinux-8"]
  }

  post-processor "vagrant" {
    compression_level = "9"
    provider_override = "virtualbox"
    output = "almalinux-8-x86_64.{{isotime \"20060102\"}}.box"
  }
}
