variable "os_ver_8" {
  description = "AlmaLinux OS 8 version"

  type    = string
  default = "8.9"

  validation {
    condition     = can(regex("8.[3-9]$|8.[1-9][0-9]$", var.os_ver_8))
    error_message = "The os_ver_8 value must be one of released or prereleased versions of AlmaLinux OS 8."
  }
}

variable "os_ver_9" {
  description = "AlmaLinux OS 9 version"

  type    = string
  default = "9.3"

  validation {
    condition     = can(regex("9.[0-9]$|9.[1-9][0-9]$", var.os_ver_9))
    error_message = "The os_ver_9 value must be one of released or prereleased versions of AlmaLinux OS 9."
  }
}

locals {
  os_ver_minor_8 = split(".", var.os_ver_8)[1]
  os_ver_minor_9 = split(".", var.os_ver_9)[1]
}

locals {
  iso_url_8_x86_64       = "https://repo.almalinux.org/almalinux/${var.os_ver_8}/isos/x86_64/AlmaLinux-${var.os_ver_8}-x86_64-boot.iso"
  iso_checksum_8_x86_64  = "file:https://repo.almalinux.org/almalinux/${var.os_ver_8}/isos/x86_64/CHECKSUM"
  iso_url_8_aarch64      = "https://repo.almalinux.org/almalinux/${var.os_ver_8}/isos/aarch64/AlmaLinux-${var.os_ver_8}-aarch64-boot.iso"
  iso_checksum_8_aarch64 = "file:https://repo.almalinux.org/almalinux/${var.os_ver_8}/isos/aarch64/CHECKSUM"
  iso_url_8_ppc64le      = "https://repo.almalinux.org/almalinux/${var.os_ver_8}/isos/ppc64le/AlmaLinux-${var.os_ver_8}-ppc64le-boot.iso"
  iso_checksum_8_ppc64le = "file:https://repo.almalinux.org/almalinux/${var.os_ver_8}/isos/ppc64le/CHECKSUM"
  iso_url_9_x86_64       = "https://repo.almalinux.org/almalinux/${var.os_ver_9}/isos/x86_64/AlmaLinux-${var.os_ver_9}-x86_64-boot.iso"
  iso_checksum_9_x86_64  = "file:https://repo.almalinux.org/almalinux/${var.os_ver_9}/isos/x86_64/CHECKSUM"
  iso_url_9_aarch64      = "https://repo.almalinux.org/almalinux/${var.os_ver_9}/isos/aarch64/AlmaLinux-${var.os_ver_9}-aarch64-boot.iso"
  iso_checksum_9_aarch64 = "file:https://repo.almalinux.org/almalinux/${var.os_ver_9}/isos/aarch64/CHECKSUM"
  iso_url_9_ppc64le      = "https://repo.almalinux.org/almalinux/${var.os_ver_9}/isos/ppc64le/AlmaLinux-${var.os_ver_9}-ppc64le-boot.iso"
  iso_checksum_9_ppc64le = "file:https://repo.almalinux.org/almalinux/${var.os_ver_9}/isos/ppc64le/CHECKSUM"
}

# Common

variable "headless" {
  description = "Disable GUI"

  type    = bool
  default = true
}

variable "boot_wait" {
  description = "Time to wait before typing boot command"

  type    = string
  default = "10s"
}

variable "cpus" {
  description = "The number of virtual cpus"

  type    = number
  default = 2
}

variable "memory" {
  description = "The amount of memory"

  type    = number
  default = 2048
}

variable "post_cpus" {
  description = "The number of virtual cpus after the build"

  type    = number
  default = 1
}

variable "post_memory" {
  description = "The number of virtual cpus after the build"

  type    = number
  default = 1024
}

variable "http_directory" {
  description = "Path to a directory to serve kickstart files"

  type    = string
  default = "http"
}

variable "ssh_timeout" {
  description = "The time to wait for SSH to become available"

  type    = string
  default = "3600s"
}

variable "root_shutdown_command" {
  description = "The command to use to gracefully shut down the machine"

  type    = string
  default = "/sbin/shutdown -hP now"
}

variable "qemu_binary" {
  description = "Path of QEMU binary"

  type    = string
  default = null
}

variable "ovmf_code" {
  description = "Path of OVMF code file"

  type    = string
  default = "/usr/share/OVMF/OVMF_CODE.secboot.fd"
}

variable "ovmf_vars" {
  description = "Path of OVMF variables file"

  type    = string
  default = "/usr/share/OVMF/OVMF_VARS.secboot.fd"
}

variable "aavmf_code" {
  description = "Path of AAVMF code file"

  type    = string
  default = "/usr/share/AAVMF/AAVMF_CODE.fd"
}

# Generic Cloud (Cloud-init)

variable "gencloud_disk_size" {
  description = "The size in GB of hard disk of VM"

  type    = string
  default = "10G"
}

variable "gencloud_ssh_username" {
  description = "The username to connect to SSH with"

  type    = string
  default = "root"
}

variable "gencloud_ssh_password" {
  description = "A plaintext password to use to authenticate with SSH"

  type    = string
  default = "almalinux"
}

variable "gencloud_boot_wait_ppc64le" {
  description = "Time to wait before typing boot command for ppc64le VM"

  type    = string
  default = "8s"
}

variable "gencloud_boot_command_8_x86_64" {
  description = "Boot command for x86_64 BIOS"

  type = list(string)
  default = [
    "<tab>",
    "inst.text net.ifnames=0 inst.gpt",
    " inst.ks=http://{{ .HTTPIP }}:{{ .HTTPPort }}/almalinux-8.gencloud-x86_64.ks",
    "<enter><wait>"
  ]
}

local "gencloud_boot_command_8_x86_64_uefi" {
  expression = [
    "c<wait>",
    "linuxefi",
    " /images/pxeboot/vmlinuz",
    " inst.stage2=hd:LABEL=AlmaLinux-8-${local.os_ver_minor_8}-x86_64-dvd ro",
    " inst.text biosdevname=0 net.ifnames=0",
    " inst.ks=http://{{ .HTTPIP }}:{{ .HTTPPort }}/almalinux-8.gencloud-x86_64.ks",
    "<enter>",
    "initrdefi /images/pxeboot/initrd.img",
    "<enter>",
    "boot<enter><wait>"
  ]
}

local "gencloud_boot_command_8_aarch64" {
  expression = [
    "c<wait>",
    "linux /images/pxeboot/vmlinuz",
    " inst.stage2=hd:LABEL=AlmaLinux-8-${local.os_ver_minor_8}-aarch64-dvd ro",
    " inst.text biosdevname=0 net.ifnames=0",
    " inst.ks=http://{{ .HTTPIP }}:{{ .HTTPPort }}/almalinux-8.gencloud-aarch64.ks",
    "<enter>",
    "initrd /images/pxeboot/initrd.img",
    "<enter>",
    "boot<enter><wait>"
  ]
}

local "gencloud_boot_command_8_ppc64le" {
  expression = [
    "c<wait>",
    "linux /ppc/ppc64/vmlinuz",
    " inst.stage2=hd:LABEL=AlmaLinux-8-${local.os_ver_minor_8}-ppc64le-dvd ro",
    " inst.text biosdevname=0 net.ifnames=0",
    " inst.ks=http://{{ .HTTPIP }}:{{ .HTTPPort }}/almalinux-8.gencloud-ppc64le.ks",
    "<enter>",
    "initrd /ppc/ppc64/initrd.img",
    "<enter>",
    "boot<enter><wait>"
  ]
}

variable "gencloud_boot_command_9_x86_64_bios" {
  description = "Boot command for x86_64 BIOS"

  type = list(string)
  default = [
    "<tab>",
    "inst.text biosdevname=0 net.ifnames=0 inst.gpt",
    " inst.ks=http://{{ .HTTPIP }}:{{ .HTTPPort }}/almalinux-9.gencloud-x86_64-bios.ks",
    "<enter><wait>"
  ]
}

local "gencloud_boot_command_9_x86_64" {
  expression = [
    "c<wait>",
    "linuxefi /images/pxeboot/vmlinuz",
    " inst.stage2=hd:LABEL=AlmaLinux-9-${local.os_ver_minor_9}-x86_64-dvd ro",
    " inst.text biosdevname=0 net.ifnames=0",
    " inst.ks=http://{{ .HTTPIP }}:{{ .HTTPPort }}/almalinux-9.gencloud-x86_64.ks",
    "<enter>",
    "initrdefi /images/pxeboot/initrd.img",
    "<enter>",
    "boot<enter><wait>"
  ]
}

local "gencloud_boot_command_9_aarch64" {
  expression = [
    "c<wait>",
    "linux /images/pxeboot/vmlinuz",
    " inst.stage2=hd:LABEL=AlmaLinux-9-${local.os_ver_minor_9}-aarch64-dvd ro",
    " inst.text biosdevname=0 net.ifnames=0",
    " inst.ks=http://{{ .HTTPIP }}:{{ .HTTPPort }}/almalinux-9.gencloud-aarch64.ks",
    "<enter>",
    "initrd /images/pxeboot/initrd.img<enter>",
    "boot<enter><wait>"
  ]
}

local "gencloud_boot_command_9_ppc64le" {
  expression = [
    "c<wait>",
    "linux /ppc/ppc64/vmlinuz",
    " inst.stage2=hd:LABEL=AlmaLinux-9-${local.os_ver_minor_9}-ppc64le-dvd ro",
    " inst.text biosdevname=0 net.ifnames=0",
    " inst.ks=http://{{ .HTTPIP }}:{{ .HTTPPort }}/almalinux-9.gencloud-ppc64le.ks",
    "<enter>",
    "initrd /ppc/ppc64/initrd.img<enter>",
    "boot<enter><wait>"
  ]
}

# Azure

variable "azure_disk_size" {
  description = "The size in MiB of hard disk of VM"

  type    = number
  default = 30720
}

local "azure_boot_command_8_x86_64" {
  expression = [
    "c<wait>",
    "linuxefi /images/pxeboot/vmlinuz",
    " inst.stage2=hd:LABEL=AlmaLinux-8-${local.os_ver_minor_8}-x86_64-dvd ro",
    " inst.text biosdevname=0 net.ifnames=0",
    " inst.ks=http://{{ .HTTPIP }}:{{ .HTTPPort }}/almalinux-8.azure-x86_64.ks",
    "<enter>",
    "initrdefi /images/pxeboot/initrd.img",
    "<enter>",
    "boot<enter><wait>"
  ]
}

local "azure_boot_command_9_x86_64" {
  expression = [
    "c<wait>",
    "linuxefi /images/pxeboot/vmlinuz",
    " inst.stage2=hd:LABEL=AlmaLinux-9-${local.os_ver_minor_9}-x86_64-dvd ro",
    " inst.text biosdevname=0 net.ifnames=0",
    " inst.ks=http://{{ .HTTPIP }}:{{ .HTTPPort }}/almalinux-9.azure-x86_64.ks",
    "<enter>",
    "initrdefi /images/pxeboot/initrd.img",
    "<enter>",
    "boot<enter><wait>"
  ]
}

# AWS

variable "aws_disk_size" {
  description = "The size in MiB of hard disk of VM"

  type    = number
  default = 4096
}

variable "aws_ssh_username" {
  description = "The username to connect to SSH with"

  type    = string
  default = "root"
}

variable "aws_ssh_password" {
  description = "A plaintext password to use to authenticate with SSH"

  type    = string
  default = "almalinux"
}

variable "aws_s3_bucket_name" {
  description = "The name of the S3 bucket where the VM image will be copied to for import"

  type    = string
  default = null
}

variable "aws_role_name" {
  description = "The name of the role to use for VM Import"

  type    = string
  default = null
}

local "aws_ami_name_x86_64_8" {
  expression = "AlmaLinux OS ${var.os_ver_8}.${formatdate("YYYYMMDD", timestamp())} x86_64"
}

local "aws_ami_name_aarch64_8" {
  expression = "AlmaLinux OS ${var.os_ver_8}.${formatdate("YYYYMMDD", timestamp())} aarch64"
}

local "aws_ami_description_x86_64_8" {
  expression = "Official AlmaLinux OS ${var.os_ver_8} x86_64 image"
}

local "aws_ami_description_aarch64_8" {
  expression = "Official AlmaLinux OS ${var.os_ver_8} aarch64 image"
}

local "aws_ami_version_8" {
  expression = "${var.os_ver_8}.${formatdate("YYYYMMDD", timestamp())}"
}

local "aws_ami_name_x86_64_9" {
  expression = "AlmaLinux OS ${var.os_ver_9}.${formatdate("YYYYMMDD", timestamp())} x86_64"
}

local "aws_ami_name_aarch64_9" {
  expression = "AlmaLinux OS ${var.os_ver_9}.${formatdate("YYYYMMDD", timestamp())} aarch64"
}

local "aws_ami_description_x86_64_9" {
  expression = "Official AlmaLinux OS ${var.os_ver_9} x86_64 image"
}

local "aws_ami_description_aarch64_9" {
  expression = "Official AlmaLinux OS ${var.os_ver_9} aarch64 image"
}

local "aws_ami_version_9" {
  expression = "${var.os_ver_9}.${formatdate("YYYYMMDD", timestamp())}"
}

variable "aws_ami_architecture" {
  description = "The architecture of AMI"

  type    = string
  default = "x86_64"
}

variable "aws_ami_region" {
  description = "The region to create the AMI"

  type    = string
  default = "us-east-1"
}

variable "aws_ami_regions" {
  description = "The list of regions to copy the AMI to"

  type    = list(string)
  default = ["us-east-1"]
}

variable "aws_volume_type" {
  description = "Volume type for AMI"

  type    = string
  default = "gp3"
}

variable "aws_source_ami_8_aarch64" {
  description = "AlmaLinux OS 8 AArch64 AMI as source"

  type    = string
  default = "ami-02c9a8bba92028114"
}

variable "aws_source_ami_9_x86_64" {
  description = "AlmaLinux OS 9 x86_64 AMI as source"

  type    = string
  default = "ami-06bc84fafec254e1d"
}

variable "aws_source_ami_9_aarch64" {
  description = "AlmaLinux OS 9 AArch64 AMI as source"

  type    = string
  default = "ami-00a3e427999640fad"
}

variable "aws_boot_command_8" {
  description = "Boot command for x86_64 BIOS"

  type = list(string)
  default = [
    "<tab>",
    "inst.text net.ifnames=0",
    " inst.ks=http://{{ .HTTPIP }}:{{ .HTTPPort }}/almalinux-8.aws.ks",
    "<enter><wait>"
  ]
}

# Vagrant

variable "vagrant_disk_size" {
  description = "The size in MiB of hard disk of VM"

  type    = number
  default = 20000
}

variable "vagrant_shutdown_command" {
  description = "The command to use to gracefully shut down the machine"

  type    = string
  default = "echo vagrant | sudo -S /sbin/shutdown -hP now"
}

variable "vagrant_ssh_username" {
  description = "The username to connect to SSH with"

  type    = string
  default = "vagrant"
}

variable "vagrant_ssh_password" {
  description = "A plaintext password to use to authenticate with SSH"

  type    = string
  default = "vagrant"
}

variable "vagrant_boot_command_8_x86_64" {
  description = "Boot command for x86_64 BIOS"

  type = list(string)
  default = [
    "<tab>",
    " inst.text inst.ks=http://{{ .HTTPIP }}:{{ .HTTPPort }}/almalinux-8.vagrant.ks",
    "<enter><wait>"
  ]
}

local "vagrant_boot_command_8_x86_64_uefi" {
  expression = [
    "c<wait>",
    "linuxefi /images/pxeboot/vmlinuz",
    " inst.stage2=hd:LABEL=AlmaLinux-8-${local.os_ver_minor_8}-x86_64-dvd ro",
    " inst.text biosdevname=0 net.ifnames=0",
    " inst.ks=http://{{ .HTTPIP }}:{{ .HTTPPort }}/almalinux-8.vagrant.ks",
    "<enter>",
    "initrdefi /images/pxeboot/initrd.img<enter>",
    "boot<enter><wait>"
  ]
}

local "vagrant_boot_command_9_x86_64" {
  expression = [
    "c",
    "<wait>",
    "linuxefi /images/pxeboot/vmlinuz",
    " inst.stage2=hd:LABEL=AlmaLinux-9-${local.os_ver_minor_9}-x86_64-dvd ro",
    " inst.text biosdevname=0 net.ifnames=0",
    " inst.ks=http://{{ .HTTPIP }}:{{ .HTTPPort }}/almalinux-9.vagrant-x86_64.ks",
    "<enter>",
    "initrdefi /images/pxeboot/initrd.img",
    "<enter>",
    "boot<enter><wait>"
  ]
}

variable "vagrant_boot_command_9_x86_64_bios" {
  description = "Boot command for x86_64 BIOS"

  type = list(string)
  default = [
    "<tab>",
    "inst.text inst.gpt inst.ks=http://{{ .HTTPIP }}:{{ .HTTPPort }}/almalinux-9.vagrant-x86_64.ks",
    "<enter><wait>"
  ]
}

variable "vagrant_boot_command_9_aarch64" {
  description = "Boot command for AArch64"

  type = list(string)
  default = [
    "e",
    "<down><down><end><bs><bs><bs><bs><bs>",
    "inst.text inst.ks=http://{{ .HTTPIP }}:{{ .HTTPPort }}/almalinux-9.vagrant-aarch64.ks",
    "<leftCtrlOn>x<leftCtrlOff>"
  ]
}

# OpenNebula

variable "opennebula_boot_command_8_x86_64" {
  description = "Boot command for x86_64 BIOS"

  type = list(string)
  default = [
    "<tab>",
    " inst.text net.ifnames=0 inst.gpt inst.ks=http://{{ .HTTPIP }}:{{ .HTTPPort }}/almalinux-8.opennebula-x86_64.ks",
    "<enter><wait>"
  ]
}

local "opennebula_boot_command_8_aarch64" {
  expression = [
    "c",
    "<wait>",
    "linux /images/pxeboot/vmlinuz",
    " inst.stage2=hd:LABEL=AlmaLinux-8-${local.os_ver_minor_8}-aarch64-dvd ro",
    " inst.text biosdevname=0 net.ifnames=0",
    " inst.ks=http://{{ .HTTPIP }}:{{ .HTTPPort }}/almalinux-8.opennebula-aarch64.ks",
    "<enter>",
    "initrd /images/pxeboot/initrd.img",
    "<enter>",
    "boot<enter><wait>"
  ]
}

# Hyper-V

variable "hyperv_switch_name" {
  description = "The name of the switch to connect the virtual machine to"

  type    = string
  default = null
}

# Parallels

variable "parallels_tools_flavor_x86_64" {
  description = "The flavor of the Parallels Tools ISO to install into the x86_64 VM"

  type    = string
  default = "lin"
}

variable "parallels_tools_flavor_aarch64" {
  description = "The flavor of the Parallels Tools ISO to install into the AArch64 VM"

  type    = string
  default = "lin-arm"
}

# DigitalOcean

variable "do_api_token" {
  description = "A personal access token used to communicate with the DigitalOcean v2 API"

  sensitive = true
  type      = string
  default   = null
}

variable "do_spaces_key" {
  description = "The access key used to communicate with Spaces"

  sensitive = true
  type      = string
  default   = null
}

variable "do_spaces_secret" {
  description = "The secret key used to communicate with Spaces"

  sensitive = true
  type      = string
  default   = null
}

variable "do_spaces_region" {
  description = "The name of the region, such as nyc3, in which to upload the image to Spaces"

  sensitive = true
  type      = string
  default   = null
}

variable "do_space_name" {
  description = "The name of the specific Space where the image file will be copied to for import"

  type    = string
  default = null
}

variable "do_image_name_8" {
  description = "The name to be used for the resulting DigitalOcean custom image"

  type    = string
  default = null
}

variable "do_image_name_9" {
  description = "The name to be used for the resulting DigitalOcean custom image"

  type    = string
  default = null
}

variable "do_image_regions" {
  description = "A list of DigitalOcean regions"

  type    = list(string)
  default = null
}

variable "do_image_description" {
  description = "The description to set for the resulting imported image"

  type    = string
  default = "Official AlmaLinux OS Image"
}

variable "do_image_distribution" {
  description = "The name of the distribution to set for the resulting imported image"

  type    = string
  default = "AlmaLinux OS"
}

local "do_image_tags" {
  expression = ["AlmaLinux", "${var.os_ver_8}", "8"]
}
