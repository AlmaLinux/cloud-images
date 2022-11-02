variables {
  //
  // common variables
  //
  iso_url_8_x86_64       = "https://repo.almalinux.org/almalinux/8.6/isos/x86_64/AlmaLinux-8.6-x86_64-boot.iso"
  iso_checksum_8_x86_64  = "file:https://repo.almalinux.org/almalinux/8.6/isos/x86_64/CHECKSUM"
  iso_url_8_aarch64      = "https://repo.almalinux.org/almalinux/8.6/isos/aarch64/AlmaLinux-8.6-aarch64-boot.iso"
  iso_checksum_8_aarch64 = "file:https://repo.almalinux.org/almalinux/8.6/isos/aarch64/CHECKSUM"
  iso_url_8_ppc64le      = "https://repo.almalinux.org/almalinux/8.6/isos/ppc64le/AlmaLinux-8.6-ppc64le-boot.iso"
  iso_checksum_8_ppc64le = "file:https://repo.almalinux.org/almalinux/8.6/isos/ppc64le/CHECKSUM"
  iso_url_9_x86_64       = "https://repo.almalinux.org/almalinux/9.0/isos/x86_64/AlmaLinux-9.0-x86_64-boot.iso"
  iso_checksum_9_x86_64  = "file:https://repo.almalinux.org/almalinux/9.0/isos/x86_64/CHECKSUM"
  iso_url_9_aarch64      = "https://repo.almalinux.org/almalinux/9.0/isos/aarch64/AlmaLinux-9.0-aarch64-boot.iso"
  iso_checksum_9_aarch64 = "file:https://repo.almalinux.org/almalinux/9.0/isos/aarch64/CHECKSUM"
  iso_url_9_ppc64le      = "https://repo.almalinux.org/almalinux/9.0/isos/ppc64le/AlmaLinux-9.0-ppc64le-boot.iso"
  iso_checksum_9_ppc64le = "file:https://repo.almalinux.org/almalinux/9.0/isos/ppc64le/CHECKSUM"
  headless               = true
  boot_wait              = "10s"
  cpus                   = 2
  memory                 = 2048
  post_cpus              = 1
  post_memory            = 1024
  http_directory         = "http"
  ssh_timeout            = "3600s"
  root_shutdown_command  = "/sbin/shutdown -hP now"
  qemu_binary            = ""
  firmware_x86_64        = "/usr/share/OVMF/OVMF_CODE.fd"
  firmware_aarch64       = "/usr/share/AAVMF/AAVMF_CODE.fd"
  //
  // AWS specific variables
  //
  aws_boot_command_8 = [
    "<tab> inst.text net.ifnames=0 inst.ks=http://{{ .HTTPIP }}:{{ .HTTPPort }}/almalinux-8.aws.ks<enter><wait>"
  ]
  aws_disk_size                 = 4096
  aws_ssh_username              = "root"
  aws_ssh_password              = "almalinux"
  aws_s3_bucket_name            = ""
  aws_role_name                 = "vmimport"
  aws_ami_name_x86_64_8         = "AlmaLinux OS 8.6.{{isotime \"20060102\"}} x86_64"
  aws_ami_name_aarch64_8        = "AlmaLinux OS 8.6.{{isotime \"20060102\"}} aarch64"
  aws_ami_description_x86_64_8  = "Official AlmaLinux OS 8.6 x86_64 image"
  aws_ami_description_aarch64_8 = "Official AlmaLinux OS 8.6 aarch64 image"
  aws_ami_version_8             = "8.6.{{isotime \"20060102\"}}"
  aws_ami_name_x86_64_9         = "AlmaLinux OS 9.0.{{isotime \"20060102\"}} x86_64"
  aws_ami_name_aarch64_9        = "AlmaLinux OS 9.0.{{isotime \"20060102\"}} aarch64"
  aws_ami_description_x86_64_9  = "Official AlmaLinux OS 9.0 x86_64 image"
  aws_ami_description_aarch64_9 = "Official AlmaLinux OS 9.0 aarch64 image"
  aws_ami_version_9             = "9.0.{{isotime \"20060102\"}}"
  aws_ami_architecture          = "x86_64"
  //
  // DigitalOcean variables
  //
  do_api_token          = env("DIGITALOCEAN_API_TOKEN")
  do_spaces_key         = env("DIGITALOCEAN_SPACES_ACCESS_KEY")
  do_spaces_secret      = env("DIGITALOCEAN_SPACES_SECRET_KEY")
  do_spaces_region      = "nyc3"
  do_space_name         = env("DIGITALOCEAN_SPACE_NAME")
  do_image_name         = "AlmaLinux OS 8.6.{{isotime \"20060102\"}} x86_64"
  do_image_regions      = ["nyc3"]
  do_image_description  = "Official AlmaLinux OS Image"
  do_image_distribution = "AlmaLinux OS"
  do_image_tags         = ["AlmaLinux", "8.6", "8"]
  //
  // Generic Cloud (OpenStack) variables
  //
  gencloud_boot_command_8_x86_64 = [
    "<tab> inst.text net.ifnames=0 inst.gpt inst.ks=http://{{ .HTTPIP }}:{{ .HTTPPort }}/almalinux-8.gencloud-x86_64.ks<enter><wait>"
  ]
  gencloud_boot_command_8_x86_64_uefi = [
    "c<wait>",
    "linuxefi /images/pxeboot/vmlinuz inst.stage2=hd:LABEL=AlmaLinux-8-6-x86_64-dvd ro ",
    "inst.text biosdevname=0 net.ifnames=0 ",
    "inst.ks=http://{{ .HTTPIP }}:{{ .HTTPPort }}/almalinux-8.gencloud-x86_64.ks<enter>",
    "initrdefi /images/pxeboot/initrd.img<enter>",
    "boot<enter><wait>"
  ]
  gencloud_boot_command_8_aarch64 = [
    "c<wait>",
    "linux /images/pxeboot/vmlinuz inst.stage2=hd:LABEL=AlmaLinux-8-6-aarch64-dvd ro ",
    "inst.text biosdevname=0 net.ifnames=0 ",
    "inst.ks=http://{{ .HTTPIP }}:{{ .HTTPPort }}/almalinux-8.gencloud-aarch64.ks<enter>",
    "initrd /images/pxeboot/initrd.img<enter>",
    "boot<enter><wait>"
  ]
  gencloud_boot_command_8_ppc64le = [
    "c<wait>",
    "linux /ppc/ppc64/vmlinuz inst.stage2=hd:LABEL=AlmaLinux-8-6-ppc64le-dvd ro ",
    "inst.text biosdevname=0 net.ifnames=0 ",
    "inst.ks=http://{{ .HTTPIP }}:{{ .HTTPPort }}/almalinux-8.gencloud-ppc64le.ks<enter>",
    "initrd /ppc/ppc64/initrd.img<enter>",
    "boot<enter><wait>"
  ]
  gencloud_boot_command_9_x86_64_bios = [
    "<tab> inst.text biosdevname=0 net.ifnames=0 inst.gpt inst.ks=http://{{ .HTTPIP }}:{{ .HTTPPort }}/almalinux-9.gencloud-x86_64-bios.ks<enter><wait>"
  ]
  gencloud_boot_command_9_x86_64 = [
    "c<wait>",
    "linuxefi /images/pxeboot/vmlinuz inst.stage2=hd:LABEL=AlmaLinux-9-0-x86_64-dvd ro ",
    "inst.text biosdevname=0 net.ifnames=0 ",
    "inst.ks=http://{{ .HTTPIP }}:{{ .HTTPPort }}/almalinux-9.gencloud-x86_64.ks<enter>",
    "initrdefi /images/pxeboot/initrd.img<enter>",
    "boot<enter><wait>"
  ]
  gencloud_boot_command_9_aarch64 = [
    "c<wait>",
    "linux /images/pxeboot/vmlinuz inst.stage2=hd:LABEL=AlmaLinux-9-0-aarch64-dvd ro ",
    "inst.text biosdevname=0 net.ifnames=0 ",
    "inst.ks=http://{{ .HTTPIP }}:{{ .HTTPPort }}/almalinux-9.gencloud-aarch64.ks<enter>",
    "initrd /images/pxeboot/initrd.img<enter>",
    "boot<enter><wait>"
  ]
  gencloud_boot_command_9_ppc64le = [
    "c<wait>",
    "linux /ppc/ppc64/vmlinuz inst.stage2=hd:LABEL=AlmaLinux-9-0-ppc64le-dvd ro ",
    "inst.text biosdevname=0 net.ifnames=0 ",
    "inst.ks=http://{{ .HTTPIP }}:{{ .HTTPPort }}/almalinux-9.gencloud-ppc64le.ks<enter>",
    "initrd /ppc/ppc64/initrd.img<enter>",
    "boot<enter><wait>"
  ]

  gencloud_disk_size         = "10G"
  gencloud_ssh_username      = "root"
  gencloud_ssh_password      = "almalinux"
  gencloud_boot_wait_ppc64le = "8s"
  //
  // Hyper-V specific variables
  //
  hyperv_switch_name = ""
  //
  // Vagrant specific variables
  //
  vagrant_boot_command_8_x86_64 = [
    "<tab> inst.text inst.ks=http://{{ .HTTPIP }}:{{ .HTTPPort }}/almalinux-8.vagrant.ks<enter><wait>"
  ]
  vagrant_boot_command_9_x86_64 = [
    "<tab> inst.text inst.gpt inst.ks=http://{{ .HTTPIP }}:{{ .HTTPPort }}/almalinux-9.vagrant.ks<enter><wait>"
  ]
  vagrant_boot_command_9_aarch64 = [
    "e<down><down><end><bs><bs><bs><bs><bs>inst.text inst.ks=http://{{ .HTTPIP }}:{{ .HTTPPort }}/almalinux-9.vagrant-aarch64.ks<leftCtrlOn>x<leftCtrlOff>"
  ]
  vagrant_efi_boot_command_8_x86_64 = [
    "e<down><down><end><bs><bs><bs><bs><bs>inst.text inst.ks=http://{{ .HTTPIP }}:{{ .HTTPPort }}/almalinux-8.vagrant.ks<leftCtrlOn>x<leftCtrlOff>"
  ]
  vagrant_efi_boot_command_9_x86_64 = [
    "c<wait>",
    "linuxefi /images/pxeboot/vmlinuz inst.stage2=hd:LABEL=AlmaLinux-9-0-x86_64-dvd ro ",
    "inst.text biosdevname=0 net.ifnames=0 ",
    "inst.ks=http://{{ .HTTPIP }}:{{ .HTTPPort }}/almalinux-9.vagrant.ks<enter>",
    "initrdefi /images/pxeboot/initrd.img<enter>",
    "boot<enter><wait>"
  ]
  vagrant_disk_size        = 20000
  vagrant_shutdown_command = "echo vagrant | sudo -S /sbin/shutdown -hP now"
  vagrant_ssh_username     = "vagrant"
  vagrant_ssh_password     = "vagrant"
  //
  // OpenNebula variables
  //
  opennebula_boot_command_8_x86_64 = [
    "<tab> inst.text net.ifnames=0 inst.gpt inst.ks=http://{{ .HTTPIP }}:{{ .HTTPPort }}/almalinux-8.opennebula-x86_64.ks<enter><wait>"
  ]
  opennebula_boot_command_8_aarch64 = [
    "c<wait>",
    "linux /images/pxeboot/vmlinuz inst.stage2=hd:LABEL=AlmaLinux-8-6-aarch64-dvd ro ",
    "inst.text biosdevname=0 net.ifnames=0 ",
    "inst.ks=http://{{ .HTTPIP }}:{{ .HTTPPort }}/almalinux-8.opennebula-aarch64.ks<enter>",
    "initrd /images/pxeboot/initrd.img<enter>",
    "boot<enter><wait>"
  ]
  //
  // Parallels variables
  //
  parallels_tools_flavor_x86_64 = "lin"
  parallels_tools_flavor_aarch64 = "lin-arm"
}
