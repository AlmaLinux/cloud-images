variables {
  //
  // common variables
  //
  iso_url                  = "http://repo.almalinux.org/almalinux/8.4/isos/x86_64/AlmaLinux-8.4-x86_64-boot.iso"
  iso_checksum             = "file:http://repo.almalinux.org/almalinux/8.4/isos/x86_64/CHECKSUM"
  headless                 = true
  boot_wait                = "10s"
  cpus                     = 2
  memory                   = 2048
  post_cpus                = 1
  post_memory              = 1024
  http_directory           = "http"
  ssh_timeout              = "3600s"
  root_shutdown_command    = "/sbin/shutdown -hP now"
  //
  // AWS specific variables
  //
  aws_boot_command         = [
    "<tab> text ks=http://{{ .HTTPIP }}:{{ .HTTPPort }}/almalinux-8.aws.ks<enter><wait>"
  ]
  aws_disk_size            = 10240
  aws_ssh_username         = "root"
  aws_ssh_password         = "almalinux"
  aws_s3_bucket_name       = ""
  aws_role_name            = "vmimport"
  //
  // DigitalOcean variables
  //
  do_api_token             = env("DIGITALOCEAN_API_TOKEN")
  do_image_name            = "AlmaLinux-x86_64-latest-{{timestamp}}"
  do_image_regions         = ["nyc3"]
  do_region                = "nyc3"
  do_size                  = "s-1vcpu-1gb"
  do_snapshot_name         = "AlmaLinux-x86_64-latest-{{timestamp}}"
  do_spaces_key            = env("DIGITALOCEAN_SPACES_ACCESS_KEY")
  do_spaces_name           = env("DIGITALOCEAN_SPACES_NAME")
  do_spaces_secret         = env("DIGITALOCEAN_SPACES_SECRET_KEY")
  do_tags                  = ["AlmaLinux"]
  //
  // Generic Cloud (OpenStack) variables
  //
  gencloud_boot_command    = [
    "<tab> text ks=http://{{ .HTTPIP }}:{{ .HTTPPort }}/almalinux-8.gencloud.ks<enter><wait>"
  ]
  gencloud_disk_size       = "10G"
  gencloud_ssh_username    = "root"
  gencloud_ssh_password    = "almalinux"
  //
  // Hyper-V specific variables
  //
  hyperv_switch_name       = ""
  //
  // Vagrant specific variables
  //
  vagrant_boot_command     = [
    "<tab> text ks=http://{{ .HTTPIP }}:{{ .HTTPPort }}/almalinux-8.vagrant.ks<enter><wait>"
  ]
  vagrant_efi_boot_command = [
    "e<down><down><end><bs><bs><bs><bs><bs>text ks=http://{{ .HTTPIP }}:{{ .HTTPPort }}/almalinux-8.vagrant.ks<leftCtrlOn>x<leftCtrlOff>"
  ]
  vagrant_disk_size        = 20000
  vagrant_shutdown_command = "echo vagrant | sudo -S /sbin/shutdown -hP now"
  vagrant_ssh_username     = "vagrant"
  vagrant_ssh_password     = "vagrant"
}
