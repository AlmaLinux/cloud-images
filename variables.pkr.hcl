variable "os_ver_8" {
  description = "AlmaLinux OS 8 version"

  type    = string
  default = "8.10"

  validation {
    condition     = can(regex("8.[3-9]$|8.[1-9][0-9]$", var.os_ver_8))
    error_message = "The os_ver_8 value must be one of released or prereleased versions of AlmaLinux OS 8."
  }
}

variable "os_ver_9" {
  description = "AlmaLinux OS 9 version"

  type    = string
  default = "9.8"

  validation {
    condition     = can(regex("9.[0-9]$|9.[1-9][0-9]$", var.os_ver_9))
    error_message = "The os_ver_9 value must be one of released or prereleased versions of AlmaLinux OS 9."
  }
}

variable "os_ver_10" {
  description = "AlmaLinux OS 10 version"

  type    = string
  default = "10.2"

  validation {
    condition     = can(regex("10.[0-9]$|10.[1-9][0-9]$", var.os_ver_10))
    error_message = "The os_ver_10 value must be one of released or prereleased versions of AlmaLinux OS 10."
  }
}

variable "build_number" {
  description = "Build number identifier of an image version"

  type    = number
  default = 0
}

locals {
  os_ver_minor_8 = split(".", var.os_ver_8)[1]
}

locals {
  iso_url_8_x86_64          = "https://repo.almalinux.org/almalinux/${var.os_ver_8}/isos/x86_64/AlmaLinux-${var.os_ver_8}-x86_64-boot.iso"
  iso_checksum_8_x86_64     = "file:https://repo.almalinux.org/almalinux/${var.os_ver_8}/isos/x86_64/CHECKSUM"
  iso_url_8_aarch64         = "https://repo.almalinux.org/almalinux/${var.os_ver_8}/isos/aarch64/AlmaLinux-${var.os_ver_8}-aarch64-boot.iso"
  iso_checksum_8_aarch64    = "file:https://repo.almalinux.org/almalinux/${var.os_ver_8}/isos/aarch64/CHECKSUM"
  iso_url_8_ppc64le         = "https://repo.almalinux.org/almalinux/${var.os_ver_8}/isos/ppc64le/AlmaLinux-${var.os_ver_8}-ppc64le-boot.iso"
  iso_checksum_8_ppc64le    = "file:https://repo.almalinux.org/almalinux/${var.os_ver_8}/isos/ppc64le/CHECKSUM"
  iso_url_9_x86_64          = "https://repo.almalinux.org/almalinux/${var.os_ver_9}/isos/x86_64/AlmaLinux-${var.os_ver_9}-x86_64-boot.iso"
  iso_checksum_9_x86_64     = "file:https://repo.almalinux.org/almalinux/${var.os_ver_9}/isos/x86_64/CHECKSUM"
  iso_url_9_aarch64         = "https://repo.almalinux.org/almalinux/${var.os_ver_9}/isos/aarch64/AlmaLinux-${var.os_ver_9}-aarch64-boot.iso"
  iso_checksum_9_aarch64    = "file:https://repo.almalinux.org/almalinux/${var.os_ver_9}/isos/aarch64/CHECKSUM"
  iso_url_9_ppc64le         = "https://repo.almalinux.org/almalinux/${var.os_ver_9}/isos/ppc64le/AlmaLinux-${var.os_ver_9}-ppc64le-boot.iso"
  iso_checksum_9_ppc64le    = "file:https://repo.almalinux.org/almalinux/${var.os_ver_9}/isos/ppc64le/CHECKSUM"
  iso_url_10_x86_64         = "https://repo.almalinux.org/almalinux/${var.os_ver_10}/isos/x86_64/AlmaLinux-${var.os_ver_10}-x86_64-boot.iso"
  iso_checksum_10_x86_64    = "file:https://repo.almalinux.org/almalinux/${var.os_ver_10}/isos/x86_64/CHECKSUM"
  iso_url_10_aarch64        = "https://repo.almalinux.org/almalinux/${var.os_ver_10}/isos/aarch64/AlmaLinux-${var.os_ver_10}-aarch64-boot.iso"
  iso_checksum_10_aarch64   = "file:https://repo.almalinux.org/almalinux/${var.os_ver_10}/isos/aarch64/CHECKSUM"
  iso_url_10_ppc64le        = "https://repo.almalinux.org/almalinux/${var.os_ver_10}/isos/ppc64le/AlmaLinux-${var.os_ver_10}-ppc64le-boot.iso"
  iso_checksum_10_ppc64le   = "file:https://repo.almalinux.org/almalinux/${var.os_ver_10}/isos/ppc64le/CHECKSUM"
  iso_url_10_x86_64_v2      = "https://repo.almalinux.org/almalinux/${var.os_ver_10}/isos/x86_64_v2/AlmaLinux-${var.os_ver_10}-x86_64_v2-boot.iso"
  iso_checksum_10_x86_64_v2 = "file:https://repo.almalinux.org/almalinux/${var.os_ver_10}/isos/x86_64_v2/CHECKSUM"
}

# s390x installer kernel and initrd for the direct-kernel boot of the
# GenericCloud s390x builds (see the s390x sources in the gencloud
# templates). shared-steps resolves them with 'packer console' and downloads
# them into var.s390x_boot_dir before packer runs, so they follow os_ver_*
# and any repository URL rewrite applied to this file beforehand.
locals {
  s390x_kernel_url_8         = "https://repo.almalinux.org/almalinux/${var.os_ver_8}/BaseOS/s390x/os/images/kernel.img"
  s390x_initrd_url_8         = "https://repo.almalinux.org/almalinux/${var.os_ver_8}/BaseOS/s390x/os/images/initrd.img"
  s390x_kernel_url_9         = "https://repo.almalinux.org/almalinux/${var.os_ver_9}/BaseOS/s390x/os/images/kernel.img"
  s390x_initrd_url_9         = "https://repo.almalinux.org/almalinux/${var.os_ver_9}/BaseOS/s390x/os/images/initrd.img"
  s390x_kernel_url_10        = "https://repo.almalinux.org/almalinux/${var.os_ver_10}/BaseOS/s390x/os/images/kernel.img"
  s390x_initrd_url_10        = "https://repo.almalinux.org/almalinux/${var.os_ver_10}/BaseOS/s390x/os/images/initrd.img"
  s390x_kernel_url_kitten_10 = "https://kitten.repo.almalinux.org/10-kitten/BaseOS/s390x/os/images/kernel.img"
  s390x_initrd_url_kitten_10 = "https://kitten.repo.almalinux.org/10-kitten/BaseOS/s390x/os/images/initrd.img"
}

variable "s390x_boot_dir" {
  description = "Directory with the s390x installer kernel.img / initrd.img and the blank target disk, prepared by shared-steps"

  type    = string
  default = "s390x-boot"
}

variable "s390x_install_timeout" {
  description = "How long a communicator-less s390x TCG install may take before Packer gives up waiting for QEMU to exit"

  type    = string
  default = "8h"
}

variable "iso_url_kitten_10_x86_64" {
  description = "The latest AlmaLinux OS Kitten 10 x86_64 ISO"

  type    = string
  default = "https://kitten.repo.almalinux.org/10-kitten/isos/x86_64/AlmaLinux-Kitten-10-latest-x86_64-boot.iso"
}

variable "iso_checksum_kitten_10_x86_64" {
  description = "The checksum of latest AlmaLinux OS Kitten 10 x86_64 ISO"

  type    = string
  default = "file:https://kitten.repo.almalinux.org/10-kitten/isos/x86_64/CHECKSUM"
}

variable "iso_url_kitten_10_aarch64" {
  description = "The latest AlmaLinux OS Kitten 10 AArch64 ISO"

  type    = string
  default = "https://kitten.repo.almalinux.org/10-kitten/isos/aarch64/AlmaLinux-Kitten-10-latest-aarch64-boot.iso"
}

variable "iso_checksum_kitten_10_aarch64" {
  description = "The checksum of latest AlmaLinux OS Kitten 10 AArch64 ISO"

  type    = string
  default = "file:https://kitten.repo.almalinux.org/10-kitten/isos/aarch64/CHECKSUM"
}

variable "iso_url_kitten_10_ppc64le" {
  description = "The latest AlmaLinux OS Kitten 10 ppc64le ISO"

  type    = string
  default = "https://kitten.repo.almalinux.org/10-kitten/isos/ppc64le/AlmaLinux-Kitten-10-latest-ppc64le-boot.iso"
}

variable "iso_checksum_kitten_10_ppc64le" {
  description = "The checksum of latest AlmaLinux OS Kitten 10 ppc64le ISO"

  type    = string
  default = "file:https://kitten.repo.almalinux.org/10-kitten/isos/ppc64le/CHECKSUM"
}

variable "iso_url_kitten_10_x86_64_v2" {
  description = "The latest AlmaLinux OS Kitten 10 x86_64_v2 ISO"

  type    = string
  default = "https://kitten.repo.almalinux.org/10-kitten/isos/x86_64_v2/AlmaLinux-Kitten-10-latest-x86_64_v2-boot.iso"
}

variable "iso_checksum_kitten_10_x86_64_v2" {
  description = "The checksum of latest AlmaLinux OS Kitten 10 x86_64_v2 ISO"

  type    = string
  default = "file:https://kitten.repo.almalinux.org/10-kitten/isos/x86_64_v2/CHECKSUM"
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
  default = "30s"
}

variable "cpus" {
  description = "The number of virtual cpus"

  type    = number
  default = 4
}

variable "memory_x86_64" {
  description = "The amount of memory to use when building the x86_64 VM in megabytes"

  type    = number
  default = 3072
}

variable "memory_aarch64" {
  description = "The amount of memory to use when building the AArch64 VM in megabytes"

  type    = number
  default = 4096
}

variable "memory_ppc64le" {
  description = "The amount of memory to use when building the ppc64le VM in megabytes"

  type    = number
  default = 4096
}

variable "memory_s390x" {
  description = "Memory of the s390x TCG installer VM (MiB)"

  type    = number
  default = 4096
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

# ppc64le QEMU knobs. The defaults reproduce the Jenkins build on a POWER
# host (KVM-HV through the machine type, QEMU's default CPU = the host CPU).
# The GitHub ppc64le leg has no POWER runner and overrides them to run the
# whole install under TCG full-system emulation on an x86_64 runner:
#   -var ppc64le_accelerator=tcg -var ppc64le_machine_type=pseries
#   -var ppc64le_cpu_model=POWER9 -var ppc64le_console_log=<file>
# together with a longer gencloud_boot_wait_ppc64le and ssh_timeout, because
# SLOF, GRUB, anaconda and the ansible run are all several times slower.
variable "ppc64le_accelerator" {
  description = "Packer 'accelerator' of the ppc64le sources: 'none' lets the machine type pick KVM-HV (POWER host), 'tcg' emulates on any host"

  type    = string
  default = "none"
}

variable "ppc64le_machine_type" {
  description = "QEMU machine type of the ppc64le sources"

  type    = string
  default = "pseries,accel=kvm,kvm-type=HV"
}

variable "ppc64le_cpu_model" {
  description = "QEMU CPU model of the ppc64le sources; empty = QEMU's default (host CPU under KVM). Under TCG use POWER9 (the EL10 baseline)"

  type    = string
  default = ""
}

variable "ppc64le_grub_hold" {
  description = "Start the ppc64le boot commands with 30 s of once-a-second keypresses GRUB's menu ignores, then move to the plain Install entry. The ISO's GRUB auto-boots after 5 s, so the first press to reach the menu stops the countdown wherever SLOF's speed put it; off on Jenkins"

  type    = bool
  default = false
}

variable "ppc64le_extra_kernel_args" {
  description = "Extra installer kernel arguments typed at the end of the ppc64le boot commands; empty on Jenkins. The TCG leg passes console=hvc0 so anaconda's text UI goes to the captured serial console instead of the VGA one"

  type    = string
  default = ""
}

variable "ppc64le_console_log" {
  description = "If set, capture the ppc64le guest's serial console (hvc0) into this file"

  type    = string
  default = ""
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

# aarch64 QEMU knobs. The defaults reproduce the build on an arm64 host
# (KVM, host CPU). Where there is no arm64 runner (outside the AlmaLinux
# organisation, on a GitHub-hosted x86_64 runner) shared-steps overrides them
# to run the whole install under TCG full-system emulation:
#   -var aarch64_accelerator=tcg -var aarch64_cpu_model=max,pauth-impdef=on
#   -var aarch64_grub_hold=true -var aarch64_extra_kernel_args=console=ttyAMA0
#   -var aarch64_console_log=<file>
variable "aarch64_accelerator" {
  description = "Packer 'accelerator' of the aarch64 GenericCloud sources: 'kvm' on an arm64 host, 'tcg' to emulate on any host"

  type    = string
  default = "kvm"
}

variable "aarch64_cpu_model" {
  description = "QEMU CPU model of the aarch64 GenericCloud sources: 'host' under KVM; under TCG 'max,pauth-impdef=on' (every emulated feature, with the cheap pointer-authentication algorithm)"

  type    = string
  default = "host"
}

variable "aarch64_console_log" {
  description = "If set, capture the aarch64 guest's serial console (PL011, ttyAMA0) into this file"

  type    = string
  default = ""
}

variable "aarch64_extra_kernel_args" {
  description = "Extra installer kernel arguments typed at the end of the aarch64 GenericCloud boot commands; empty on the arm64 host. The TCG build passes console=ttyAMA0 so anaconda's output reaches the captured serial console"

  type    = string
  default = ""
}

variable "aarch64_grub_hold" {
  description = "Start the aarch64 GenericCloud boot commands with 90 s of once-a-second keypresses GRUB's menu ignores, then move to the plain Install entry. Under TCG the UEFI firmware needs an unpredictable time to reach GRUB; off on the arm64 host"

  type    = bool
  default = false
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

local "gencloud_boot_command_8_x86_64" {
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
    "boot<enter><wait>",
  ]
}

# Prefix of the aarch64 GenericCloud boot commands when aarch64_grub_hold is
# set (TCG). The emulated UEFI firmware takes an unpredictable time to reach
# GRUB, so instead of guessing the moment press a key GRUB's menu ignores once
# a second for 90 s from right after the VM starts: presses during the
# firmware are ignored, the first one that reaches the menu stops its
# countdown. Then move up from the ISO's default entry ("Test this media &
# install", whose rd.live.check hashes the whole ISO for the better part of an
# hour under emulation) to the plain "Install" entry; the "e" / "c" of the
# commands below then act on that entry.
local "aarch64_boot_prefix" {
  expression = var.aarch64_grub_hold ? concat(
    [for i in range(90) : "<spacebar><wait1>"],
    ["<up><wait1>"],
  ) : []
}

local "gencloud_boot_command_8_aarch64" {
  expression = [
    "c<wait>",
    "linux /images/pxeboot/vmlinuz",
    " inst.stage2=hd:LABEL=AlmaLinux-8-${local.os_ver_minor_8}-aarch64-dvd ro",
    " inst.text biosdevname=0 net.ifnames=0",
    " inst.ks=http://{{ .HTTPIP }}:{{ .HTTPPort }}/almalinux-8.gencloud-aarch64.ks",
    " ${var.aarch64_extra_kernel_args}",
    "<enter>",
    "initrd /images/pxeboot/initrd.img",
    "<enter>",
    "boot<enter><wait>",
  ]
}

local "gencloud_boot_command_8_ppc64le" {
  expression = concat(local.ppc64le_boot_prefix, [
    "c<wait>",
    "linux /ppc/ppc64/vmlinuz",
    " inst.stage2=hd:LABEL=AlmaLinux-8-${local.os_ver_minor_8}-ppc64le-dvd ro",
    " inst.text biosdevname=0 net.ifnames=0",
    " inst.ks=http://{{ .HTTPIP }}:{{ .HTTPPort }}/almalinux-8.gencloud-ppc64le.ks",
    " ${var.ppc64le_extra_kernel_args}",
    "<enter>",
    "initrd /ppc/ppc64/initrd.img",
    "<enter>",
    "boot<enter><wait>",
  ])
}

variable "gencloud_boot_command_9_x86_64" {
  description = "Boot command for AlmaLinux OS 9 Generic Cloud x86_64"

  type = list(string)
  default = [
    "e",
    "<down><down>",
    "<leftCtrlOn>e<leftCtrlOff>",
    "<spacebar>",
    "biosdevname=0",
    "<spacebar>",
    "net.ifnames=0",
    "<spacebar>",
    "inst.text",
    "<spacebar>",
    "inst.ks=http://{{ .HTTPIP }}:{{ .HTTPPort }}/almalinux-9.gencloud-x86_64.ks",
    "<leftCtrlOn>x<leftCtrlOff>",
  ]
}

variable "gencloud_boot_command_9_aarch64" {
  description = "Boot command for AlmaLinux OS 9 Generic Cloud AArch64"

  type = list(string)

  default = [
    "e",
    "<down><down>",
    "<leftCtrlOn>e<leftCtrlOff>",
    "<spacebar>",
    "biosdevname=0",
    "<spacebar>",
    "net.ifnames=0",
    "<spacebar>",
    "inst.text",
    "<spacebar>",
    "inst.ks=http://{{ .HTTPIP }}:{{ .HTTPPort }}/almalinux-9.gencloud-aarch64.ks",
    "<leftCtrlOn>x<leftCtrlOff>",
  ]
}

# Prefix of the ppc64le boot commands when ppc64le_grub_hold is set. Under
# TCG on the GitHub runner SLOF reaches GRUB about 8 s after the VM starts
# and the ISO's GRUB menu auto-boots 5 s later, so instead of guessing the
# moment, press a key GRUB's menu ignores once a second for 30 s starting
# right after the VM comes up: presses that arrive during SLOF are ignored,
# the first one that reaches the menu stops its countdown. Then move up from
# the ISO's default entry ("Test this media & install", rd.live.check: hashing
# the 1.5 GB ISO takes the better part of an hour under emulation) to the
# plain "Install" entry; the "e" / "c" of the commands below act on that
# entry. SLOF keeps auto-booting, so the reboot after the install brings up
# the installed system on its own.
local "ppc64le_boot_prefix" {
  expression = var.ppc64le_grub_hold ? concat(
    [for i in range(30) : "<spacebar><wait1>"],
    ["<up><wait1>"],
  ) : []
}

# Boot command for AlmaLinux OS 9 Generic Cloud ppc64le
local "gencloud_boot_command_9_ppc64le" {
  expression = concat(local.ppc64le_boot_prefix, [
    "e",
    "<down><down>",
    "<leftCtrlOn>e<leftCtrlOff>",
    "<spacebar>",
    "biosdevname=0",
    "<spacebar>",
    "net.ifnames=0",
    "<spacebar>",
    "inst.text",
    "<spacebar>",
    "inst.ks=http://{{ .HTTPIP }}:{{ .HTTPPort }}/almalinux-9.gencloud-ppc64le.ks",
    "<spacebar>",
    var.ppc64le_extra_kernel_args,
    "<leftCtrlOn>x<leftCtrlOff>",
  ])
}

variable "gencloud_boot_command_kitten_10_x86_64" {
  description = "Boot command for AlmaLinux OS Kitten 10 Generic Cloud x86_64"

  type = list(string)
  default = [
    "e",
    "<down><down>",
    "<leftCtrlOn>e<leftCtrlOff>",
    "<spacebar>",
    "biosdevname=0",
    "<spacebar>",
    "net.ifnames=0",
    "<spacebar>",
    "inst.text",
    "<spacebar>",
    "inst.ks=http://{{ .HTTPIP }}:{{ .HTTPPort }}/almalinux-kitten-10.gencloud-x86_64.ks",
    "<leftCtrlOn>x<leftCtrlOff>",
  ]
}

variable "gencloud_boot_command_kitten_10_aarch64" {
  description = "Boot command for AlmaLinux OS Kitten 10 Generic Cloud AArch64"

  type = list(string)

  default = [
    "e",
    "<down><down>",
    "<leftCtrlOn>e<leftCtrlOff>",
    "<spacebar>",
    "biosdevname=0",
    "<spacebar>",
    "net.ifnames=0",
    "<spacebar>",
    "inst.text",
    "<spacebar>",
    "inst.ks=http://{{ .HTTPIP }}:{{ .HTTPPort }}/almalinux-kitten-10.gencloud-aarch64.ks",
    "<leftCtrlOn>x<leftCtrlOff>",
  ]
}

# Boot command for AlmaLinux OS Kitten 10 Generic Cloud ppc64le
local "gencloud_boot_command_kitten_10_ppc64le" {
  expression = concat(local.ppc64le_boot_prefix, [
    "e",
    "<down><down>",
    "<leftCtrlOn>e<leftCtrlOff>",
    "<spacebar>",
    "biosdevname=0",
    "<spacebar>",
    "net.ifnames=0",
    "<spacebar>",
    "inst.text",
    "<spacebar>",
    "inst.ks=http://{{ .HTTPIP }}:{{ .HTTPPort }}/almalinux-kitten-10.gencloud-ppc64le.ks",
    "<spacebar>",
    var.ppc64le_extra_kernel_args,
    "<leftCtrlOn>x<leftCtrlOff>",
  ])
}

variable "gencloud_boot_command_kitten_10_x86_64_v2" {
  description = "Boot command for AlmaLinux OS Kitten 10 Generic Cloud x86_64_v2"

  type = list(string)
  default = [
    "e",
    "<down><down>",
    "<leftCtrlOn>e<leftCtrlOff>",
    "<spacebar>",
    "biosdevname=0",
    "<spacebar>",
    "net.ifnames=0",
    "<spacebar>",
    "inst.text",
    "<spacebar>",
    "inst.ks=http://{{ .HTTPIP }}:{{ .HTTPPort }}/almalinux-kitten-10.gencloud-x86_64_v2.ks",
    "<leftCtrlOn>x<leftCtrlOff>",
  ]
}

variable "gencloud_boot_command_10_x86_64" {
  description = "Boot command for AlmaLinux OS 10 Generic Cloud x86_64"

  type = list(string)
  default = [
    "e",
    "<down><down>",
    "<leftCtrlOn>e<leftCtrlOff>",
    "<spacebar>",
    "biosdevname=0",
    "<spacebar>",
    "net.ifnames=0",
    "<spacebar>",
    "inst.text",
    "<spacebar>",
    "inst.ks=http://{{ .HTTPIP }}:{{ .HTTPPort }}/almalinux-10.gencloud-x86_64.ks",
    "<leftCtrlOn>x<leftCtrlOff>",
  ]
}

variable "gencloud_boot_command_10_aarch64" {
  description = "Boot command for AlmaLinux OS 10 Generic Cloud AArch64"

  type = list(string)

  default = [
    "e",
    "<down><down>",
    "<leftCtrlOn>e<leftCtrlOff>",
    "<spacebar>",
    "biosdevname=0",
    "<spacebar>",
    "net.ifnames=0",
    "<spacebar>",
    "inst.text",
    "<spacebar>",
    "inst.ks=http://{{ .HTTPIP }}:{{ .HTTPPort }}/almalinux-10.gencloud-aarch64.ks",
    "<leftCtrlOn>x<leftCtrlOff>",
  ]
}

# Boot command for AlmaLinux OS 10 Generic Cloud ppc64le
local "gencloud_boot_command_10_ppc64le" {
  expression = concat(local.ppc64le_boot_prefix, [
    "e",
    "<down><down>",
    "<leftCtrlOn>e<leftCtrlOff>",
    "<spacebar>",
    "biosdevname=0",
    "<spacebar>",
    "net.ifnames=0",
    "<spacebar>",
    "inst.text",
    "<spacebar>",
    "inst.ks=http://{{ .HTTPIP }}:{{ .HTTPPort }}/almalinux-10.gencloud-ppc64le.ks",
    "<spacebar>",
    var.ppc64le_extra_kernel_args,
    "<leftCtrlOn>x<leftCtrlOff>",
  ])
}

variable "gencloud_boot_command_10_x86_64_v2" {
  description = "Boot command for AlmaLinux OS 10 Generic Cloud x86_64_v2"

  type = list(string)
  default = [
    "e",
    "<down><down>",
    "<leftCtrlOn>e<leftCtrlOff>",
    "<spacebar>",
    "biosdevname=0",
    "<spacebar>",
    "net.ifnames=0",
    "<spacebar>",
    "inst.text",
    "<spacebar>",
    "inst.ks=http://{{ .HTTPIP }}:{{ .HTTPPort }}/almalinux-10.gencloud-x86_64_v2.ks",
    "<leftCtrlOn>x<leftCtrlOff>",
  ]
}

# Generic Cloud ext4

local "gencloud_ext4_boot_command_8_x86_64" {
  expression = [
    "c<wait>",
    "linuxefi",
    " /images/pxeboot/vmlinuz",
    " inst.stage2=hd:LABEL=AlmaLinux-8-${local.os_ver_minor_8}-x86_64-dvd ro",
    " inst.text biosdevname=0 net.ifnames=0 fstype=ext4",
    " inst.ks=http://{{ .HTTPIP }}:{{ .HTTPPort }}/almalinux-8.gencloud-x86_64.ks",
    "<enter>",
    "initrdefi /images/pxeboot/initrd.img",
    "<enter>",
    "boot<enter><wait>",
  ]
}

local "gencloud_ext4_boot_command_8_aarch64" {
  expression = [
    "c<wait>",
    "linux /images/pxeboot/vmlinuz",
    " inst.stage2=hd:LABEL=AlmaLinux-8-${local.os_ver_minor_8}-aarch64-dvd ro",
    " inst.text biosdevname=0 net.ifnames=0 fstype=ext4",
    " inst.ks=http://{{ .HTTPIP }}:{{ .HTTPPort }}/almalinux-8.gencloud-aarch64.ks",
    " ${var.aarch64_extra_kernel_args}",
    "<enter>",
    "initrd /images/pxeboot/initrd.img",
    "<enter>",
    "boot<enter><wait>",
  ]
}

local "gencloud_ext4_boot_command_8_ppc64le" {
  expression = concat(local.ppc64le_boot_prefix, [
    "c<wait>",
    "linux /ppc/ppc64/vmlinuz",
    " inst.stage2=hd:LABEL=AlmaLinux-8-${local.os_ver_minor_8}-ppc64le-dvd ro",
    " inst.text biosdevname=0 net.ifnames=0 fstype=ext4",
    " inst.ks=http://{{ .HTTPIP }}:{{ .HTTPPort }}/almalinux-8.gencloud-ppc64le.ks",
    " ${var.ppc64le_extra_kernel_args}",
    "<enter>",
    "initrd /ppc/ppc64/initrd.img",
    "<enter>",
    "boot<enter><wait>",
  ])
}

variable "gencloud_ext4_boot_command_9_x86_64" {
  description = "Boot command for AlmaLinux OS 9 Generic Cloud ext4 x86_64"

  type = list(string)
  default = [
    "e",
    "<down><down>",
    "<leftCtrlOn>e<leftCtrlOff>",
    "<spacebar>",
    "biosdevname=0",
    "<spacebar>",
    "net.ifnames=0",
    "<spacebar>",
    "inst.text",
    "<spacebar>",
    "fstype=ext4",
    "<spacebar>",
    "inst.ks=http://{{ .HTTPIP }}:{{ .HTTPPort }}/almalinux-9.gencloud-x86_64.ks",
    "<leftCtrlOn>x<leftCtrlOff>",
  ]
}

variable "gencloud_ext4_boot_command_9_aarch64" {
  description = "Boot command for AlmaLinux OS 9 Generic Cloud ext4 AArch64"

  type = list(string)

  default = [
    "e",
    "<down><down>",
    "<leftCtrlOn>e<leftCtrlOff>",
    "<spacebar>",
    "biosdevname=0",
    "<spacebar>",
    "net.ifnames=0",
    "<spacebar>",
    "inst.text",
    "<spacebar>",
    "fstype=ext4",
    "<spacebar>",
    "inst.ks=http://{{ .HTTPIP }}:{{ .HTTPPort }}/almalinux-9.gencloud-aarch64.ks",
    "<leftCtrlOn>x<leftCtrlOff>",
  ]
}

# Boot command for AlmaLinux OS 9 Generic Cloud ext4 ppc64le
local "gencloud_ext4_boot_command_9_ppc64le" {
  expression = concat(local.ppc64le_boot_prefix, [
    "e",
    "<down><down>",
    "<leftCtrlOn>e<leftCtrlOff>",
    "<spacebar>",
    "biosdevname=0",
    "<spacebar>",
    "net.ifnames=0",
    "<spacebar>",
    "inst.text",
    "<spacebar>",
    "fstype=ext4",
    "<spacebar>",
    "inst.ks=http://{{ .HTTPIP }}:{{ .HTTPPort }}/almalinux-9.gencloud-ppc64le.ks",
    "<spacebar>",
    var.ppc64le_extra_kernel_args,
    "<leftCtrlOn>x<leftCtrlOff>",
  ])
}

variable "gencloud_ext4_boot_command_kitten_10_x86_64" {
  description = "Boot command for AlmaLinux OS Kitten 10 Generic Cloud ext4 x86_64"

  type = list(string)
  default = [
    "e",
    "<down><down>",
    "<leftCtrlOn>e<leftCtrlOff>",
    "<spacebar>",
    "biosdevname=0",
    "<spacebar>",
    "net.ifnames=0",
    "<spacebar>",
    "inst.text",
    "<spacebar>",
    "fstype=ext4",
    "<spacebar>",
    "inst.ks=http://{{ .HTTPIP }}:{{ .HTTPPort }}/almalinux-kitten-10.gencloud-x86_64.ks",
    "<leftCtrlOn>x<leftCtrlOff>",
  ]
}

variable "gencloud_ext4_boot_command_kitten_10_aarch64" {
  description = "Boot command for AlmaLinux OS Kitten 10 Generic Cloud ext4 AArch64"

  type = list(string)

  default = [
    "e",
    "<down><down>",
    "<leftCtrlOn>e<leftCtrlOff>",
    "<spacebar>",
    "biosdevname=0",
    "<spacebar>",
    "net.ifnames=0",
    "<spacebar>",
    "inst.text",
    "<spacebar>",
    "fstype=ext4",
    "<spacebar>",
    "inst.ks=http://{{ .HTTPIP }}:{{ .HTTPPort }}/almalinux-kitten-10.gencloud-aarch64.ks",
    "<leftCtrlOn>x<leftCtrlOff>",
  ]
}

# Boot command for AlmaLinux OS Kitten 10 Generic Cloud ext4 ppc64le
local "gencloud_ext4_boot_command_kitten_10_ppc64le" {
  expression = concat(local.ppc64le_boot_prefix, [
    "e",
    "<down><down>",
    "<leftCtrlOn>e<leftCtrlOff>",
    "<spacebar>",
    "biosdevname=0",
    "<spacebar>",
    "net.ifnames=0",
    "<spacebar>",
    "inst.text",
    "<spacebar>",
    "fstype=ext4",
    "<spacebar>",
    "inst.ks=http://{{ .HTTPIP }}:{{ .HTTPPort }}/almalinux-kitten-10.gencloud-ppc64le.ks",
    "<spacebar>",
    var.ppc64le_extra_kernel_args,
    "<leftCtrlOn>x<leftCtrlOff>",
  ])
}

variable "gencloud_ext4_boot_command_kitten_10_x86_64_v2" {
  description = "Boot command for AlmaLinux OS Kitten 10 Generic Cloud ext4 x86_64_v2"

  type = list(string)
  default = [
    "e",
    "<down><down>",
    "<leftCtrlOn>e<leftCtrlOff>",
    "<spacebar>",
    "biosdevname=0",
    "<spacebar>",
    "net.ifnames=0",
    "<spacebar>",
    "inst.text",
    "<spacebar>",
    "fstype=ext4",
    "<spacebar>",
    "inst.ks=http://{{ .HTTPIP }}:{{ .HTTPPort }}/almalinux-kitten-10.gencloud-x86_64_v2.ks",
    "<leftCtrlOn>x<leftCtrlOff>",
  ]
}

variable "gencloud_ext4_boot_command_10_x86_64" {
  description = "Boot command for AlmaLinux OS 10 Generic Cloud ext4 x86_64"

  type = list(string)
  default = [
    "e",
    "<down><down>",
    "<leftCtrlOn>e<leftCtrlOff>",
    "<spacebar>",
    "biosdevname=0",
    "<spacebar>",
    "net.ifnames=0",
    "<spacebar>",
    "inst.text",
    "<spacebar>",
    "fstype=ext4",
    "<spacebar>",
    "inst.ks=http://{{ .HTTPIP }}:{{ .HTTPPort }}/almalinux-10.gencloud-x86_64.ks",
    "<leftCtrlOn>x<leftCtrlOff>",
  ]
}

variable "gencloud_ext4_boot_command_10_aarch64" {
  description = "Boot command for AlmaLinux OS 10 Generic Cloud ext4 AArch64"

  type = list(string)

  default = [
    "e",
    "<down><down>",
    "<leftCtrlOn>e<leftCtrlOff>",
    "<spacebar>",
    "biosdevname=0",
    "<spacebar>",
    "net.ifnames=0",
    "<spacebar>",
    "inst.text",
    "<spacebar>",
    "fstype=ext4",
    "<spacebar>",
    "inst.ks=http://{{ .HTTPIP }}:{{ .HTTPPort }}/almalinux-10.gencloud-aarch64.ks",
    "<leftCtrlOn>x<leftCtrlOff>",
  ]
}

# Boot command for AlmaLinux OS 10 Generic Cloud ext4 ppc64le
local "gencloud_ext4_boot_command_10_ppc64le" {
  expression = concat(local.ppc64le_boot_prefix, [
    "e",
    "<down><down>",
    "<leftCtrlOn>e<leftCtrlOff>",
    "<spacebar>",
    "biosdevname=0",
    "<spacebar>",
    "net.ifnames=0",
    "<spacebar>",
    "inst.text",
    "<spacebar>",
    "fstype=ext4",
    "<spacebar>",
    "inst.ks=http://{{ .HTTPIP }}:{{ .HTTPPort }}/almalinux-10.gencloud-ppc64le.ks",
    "<spacebar>",
    var.ppc64le_extra_kernel_args,
    "<leftCtrlOn>x<leftCtrlOff>",
  ])
}

variable "gencloud_ext4_boot_command_10_x86_64_v2" {
  description = "Boot command for AlmaLinux OS 10 Generic Cloud ext4 x86_64_v2"

  type = list(string)
  default = [
    "e",
    "<down><down>",
    "<leftCtrlOn>e<leftCtrlOff>",
    "<spacebar>",
    "biosdevname=0",
    "<spacebar>",
    "net.ifnames=0",
    "<spacebar>",
    "inst.text",
    "<spacebar>",
    "fstype=ext4",
    "<spacebar>",
    "inst.ks=http://{{ .HTTPIP }}:{{ .HTTPPort }}/almalinux-10.gencloud-x86_64_v2.ks",
    "<leftCtrlOn>x<leftCtrlOff>",
  ]
}

# Azure

variable "azure_disk_size" {
  description = "The size in bytes of hard disk of VM"

  type    = string
  default = "32212254720b"
}

variable "gcp_disk_size" {
  description = "The size in GB of hard disk of VM"

  type    = string
  default = "10G"
}

local "gcp_boot_command_8_x86_64" {
  expression = [
    "c<wait>",
    "linuxefi /images/pxeboot/vmlinuz",
    " inst.stage2=hd:LABEL=AlmaLinux-8-${local.os_ver_minor_8}-x86_64-dvd ro",
    " inst.text biosdevname=0 net.ifnames=0",
    " inst.ks=http://{{ .HTTPIP }}:{{ .HTTPPort }}/almalinux-8.gcp-x86_64.ks",
    " console=ttyS0",
    "<enter>",
    "initrdefi /images/pxeboot/initrd.img",
    "<enter>",
    "boot<enter><wait>",
  ]
}

local "gcp_boot_command_8_aarch64" {
  expression = [
    "c<wait>",
    "linux /images/pxeboot/vmlinuz",
    " inst.stage2=hd:LABEL=AlmaLinux-8-${local.os_ver_minor_8}-aarch64-dvd ro",
    " inst.text biosdevname=0 net.ifnames=0",
    " inst.ks=http://{{ .HTTPIP }}:{{ .HTTPPort }}/almalinux-8.gcp-aarch64.ks",
    "<enter>",
    "initrd /images/pxeboot/initrd.img",
    "<enter>",
    "boot<enter><wait>"
  ]
}

variable "gcp_boot_command_9_x86_64" {
  description = "Boot command for AlmaLinux OS 9 GCP x86_64"

  type = list(string)

  default = [
    "e",
    "<down><down>",
    "<leftCtrlOn>e<leftCtrlOff>",
    "<spacebar>",
    "biosdevname=0",
    "<spacebar>",
    "net.ifnames=0",
    "<spacebar>",
    "inst.text",
    "<spacebar>",
    "inst.ks=http://{{ .HTTPIP }}:{{ .HTTPPort }}/almalinux-9.gcp-x86_64.ks",
    " console=ttyS0",
    "<leftCtrlOn>x<leftCtrlOff>",
  ]
}

variable "gcp_boot_command_9_aarch64" {
  description = "Boot command for AlmaLinux OS 9 GCP AArch64"

  type = list(string)

  default = [
    "e",
    "<down><down>",
    "<leftCtrlOn>e<leftCtrlOff>",
    "<spacebar>",
    "biosdevname=0",
    "<spacebar>",
    "net.ifnames=0",
    "<spacebar>",
    "inst.text",
    "<spacebar>",
    "inst.ks=http://{{ .HTTPIP }}:{{ .HTTPPort }}/almalinux-9.gcp-aarch64.ks",
    "<leftCtrlOn>x<leftCtrlOff>",
  ]
}

variable "gcp_boot_command_10_x86_64" {
  description = "Boot command for AlmaLinux OS 10 GCP x86_64"

  type = list(string)

  default = [
    "e",
    "<down><down>",
    "<leftCtrlOn>e<leftCtrlOff>",
    "<spacebar>",
    "biosdevname=0",
    "<spacebar>",
    "net.ifnames=0",
    "<spacebar>",
    "inst.text",
    "<spacebar>",
    "inst.ks=http://{{ .HTTPIP }}:{{ .HTTPPort }}/almalinux-10.gcp-x86_64.ks",
    "<leftCtrlOn>x<leftCtrlOff>",
  ]
}

variable "gcp_boot_command_10_aarch64" {
  description = "Boot command for AlmaLinux OS 10 GCP AArch64"

  type = list(string)

  default = [
    "e",
    "<down><down>",
    "<leftCtrlOn>e<leftCtrlOff>",
    "<spacebar>",
    "biosdevname=0",
    "<spacebar>",
    "net.ifnames=0",
    "<spacebar>",
    "inst.text",
    "<spacebar>",
    "inst.ks=http://{{ .HTTPIP }}:{{ .HTTPPort }}/almalinux-10.gcp-aarch64.ks",
    "<leftCtrlOn>x<leftCtrlOff>",
  ]
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
    "boot<enter><wait>",
  ]
}

local "azure_boot_command_8_aarch64" {
  expression = [
    "c<wait>",
    "linux /images/pxeboot/vmlinuz",
    " inst.stage2=hd:LABEL=AlmaLinux-8-${local.os_ver_minor_8}-aarch64-dvd ro",
    " inst.text biosdevname=0 net.ifnames=0",
    " inst.ks=http://{{ .HTTPIP }}:{{ .HTTPPort }}/almalinux-8.azure-aarch64.ks",
    "<enter>",
    "initrd /images/pxeboot/initrd.img",
    "<enter>",
    "boot<enter><wait>"
  ]
}

variable "azure_boot_command_9_x86_64" {
  description = "Boot command for AlmaLinux OS 9 Azure x86_64"

  type = list(string)

  default = [
    "e",
    "<down><down>",
    "<leftCtrlOn>e<leftCtrlOff>",
    "<spacebar>",
    "biosdevname=0",
    "<spacebar>",
    "net.ifnames=0",
    "<spacebar>",
    "inst.text",
    "<spacebar>",
    "inst.ks=http://{{ .HTTPIP }}:{{ .HTTPPort }}/almalinux-9.azure-x86_64.ks",
    "<leftCtrlOn>x<leftCtrlOff>",
  ]
}

variable "azure_boot_command_9_aarch64" {
  description = "Boot command for AlmaLinux OS 9 Azure AArch64"

  type = list(string)

  default = [
    "e",
    "<down><down>",
    "<leftCtrlOn>e<leftCtrlOff>",
    "<spacebar>",
    "biosdevname=0",
    "<spacebar>",
    "net.ifnames=0",
    "<spacebar>",
    "inst.text",
    "<spacebar>",
    "inst.ks=http://{{ .HTTPIP }}:{{ .HTTPPort }}/almalinux-9.azure-aarch64.ks",
    "<leftCtrlOn>x<leftCtrlOff>",
  ]
}

variable "azure_boot_command_9_64k_aarch64" {
  description = "Boot command for AlmaLinux OS 9 Azure with 64k page size kernel AArch64"

  type = list(string)

  default = [
    "e",
    "<down><down>",
    "<leftCtrlOn>e<leftCtrlOff>",
    "<spacebar>",
    "biosdevname=0",
    "<spacebar>",
    "net.ifnames=0",
    "<spacebar>",
    "inst.text",
    "<spacebar>",
    "inst.ks=http://{{ .HTTPIP }}:{{ .HTTPPort }}/almalinux-9.azure-64k-aarch64.ks",
    "<leftCtrlOn>x<leftCtrlOff>",
  ]
}

variable "azure_boot_command_kitten_10_x86_64" {
  description = "Boot command for AlmaLinux OS Kitten 10 Azure x86_64"

  type = list(string)

  default = [
    "e",
    "<down><down>",
    "<leftCtrlOn>e<leftCtrlOff>",
    "<spacebar>",
    "biosdevname=0",
    "<spacebar>",
    "net.ifnames=0",
    "<spacebar>",
    "inst.text",
    "<spacebar>",
    "inst.ks=http://{{ .HTTPIP }}:{{ .HTTPPort }}/almalinux-kitten-10.azure-x86_64.ks",
    "<leftCtrlOn>x<leftCtrlOff>",
  ]
}

variable "azure_boot_command_kitten_10_aarch64" {
  description = "Boot command for AlmaLinux OS Kitten 10 Azure AArch64"

  type = list(string)

  default = [
    "e",
    "<down><down>",
    "<leftCtrlOn>e<leftCtrlOff>",
    "<spacebar>",
    "biosdevname=0",
    "<spacebar>",
    "net.ifnames=0",
    "<spacebar>",
    "inst.text",
    "<spacebar>",
    "inst.ks=http://{{ .HTTPIP }}:{{ .HTTPPort }}/almalinux-kitten-10.azure-aarch64.ks",
    "<leftCtrlOn>x<leftCtrlOff>",
  ]
}

variable "azure_boot_command_kitten_10_64k_aarch64" {
  description = "Boot command for AlmaLinux OS Kitten 10 Azure with 64k page size kernel AArch64"

  type = list(string)

  default = [
    "e",
    "<down><down>",
    "<leftCtrlOn>e<leftCtrlOff>",
    "<spacebar>",
    "biosdevname=0",
    "<spacebar>",
    "net.ifnames=0",
    "<spacebar>",
    "inst.text",
    "<spacebar>",
    "inst.ks=http://{{ .HTTPIP }}:{{ .HTTPPort }}/almalinux-kitten-10.azure-64k-aarch64.ks",
    "<leftCtrlOn>x<leftCtrlOff>",
  ]
}

variable "azure_boot_command_10_x86_64" {
  description = "Boot command for AlmaLinux OS 10 Azure x86_64"

  type = list(string)

  default = [
    "e",
    "<down><down>",
    "<leftCtrlOn>e<leftCtrlOff>",
    "<spacebar>",
    "biosdevname=0",
    "<spacebar>",
    "net.ifnames=0",
    "<spacebar>",
    "inst.text",
    "<spacebar>",
    "inst.ks=http://{{ .HTTPIP }}:{{ .HTTPPort }}/almalinux-10.azure-x86_64.ks",
    "<leftCtrlOn>x<leftCtrlOff>",
  ]
}

variable "azure_boot_command_10_aarch64" {
  description = "Boot command for AlmaLinux OS 10 Azure AArch64"

  type = list(string)

  default = [
    "e",
    "<down><down>",
    "<leftCtrlOn>e<leftCtrlOff>",
    "<spacebar>",
    "biosdevname=0",
    "<spacebar>",
    "net.ifnames=0",
    "<spacebar>",
    "inst.text",
    "<spacebar>",
    "inst.ks=http://{{ .HTTPIP }}:{{ .HTTPPort }}/almalinux-10.azure-aarch64.ks",
    "<leftCtrlOn>x<leftCtrlOff>",
  ]
}

variable "azure_boot_command_10_64k_aarch64" {
  description = "Boot command for AlmaLinux OS 10 Azure with 64k page size kernel AArch64"

  type = list(string)

  default = [
    "e",
    "<down><down>",
    "<leftCtrlOn>e<leftCtrlOff>",
    "<spacebar>",
    "biosdevname=0",
    "<spacebar>",
    "net.ifnames=0",
    "<spacebar>",
    "inst.text",
    "<spacebar>",
    "inst.ks=http://{{ .HTTPIP }}:{{ .HTTPPort }}/almalinux-10.azure-64k-aarch64.ks",
    "<leftCtrlOn>x<leftCtrlOff>",
  ]
}

# AWS

variable "aws_profile" {
  description = "The profile to use in the shared credentials file for AWS"
  default     = null
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

variable "aws_volume_size" {
  description = "Volume size for AMI in GiB"

  type    = number
  default = 5
}

variable "aws_instance_type_x86_64" {
  description = "Instance type for builder. Only Nitro based is supported"

  type    = string
  default = "t3.small"
}

variable "aws_instance_type_aarch64" {
  description = "Instance type for builder. Only Nitro based is supported"

  type    = string
  default = "t4g.small"
}
# AlmaLinux OS 8
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
# AlmaLinux OS 9
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
# AlmaLinux OS Kitten 10
local "aws_ami_name_x86_64_kitten_10" {
  expression = "AlmaLinux OS Kitten 10.${formatdate("YYYYMMDD", timestamp())}.${var.build_number} x86_64"
}

local "aws_ami_name_aarch64_kitten_10" {
  expression = "AlmaLinux OS Kitten 10.${formatdate("YYYYMMDD", timestamp())}.${var.build_number} aarch64"
}

local "aws_ami_description_x86_64_kitten_10" {
  expression = "Official AlmaLinux OS Kitten 10 x86_64 Amazon Machine Image"
}

local "aws_ami_description_aarch64_kitten_10" {
  expression = "Official AlmaLinux OS Kitten 10 aarch64 Amazon Machine Image"
}

local "aws_ami_version_kitten_10" {
  expression = "10.${formatdate("YYYYMMDD", timestamp())}.${var.build_number}"
}
# AlmaLinux OS 10
local "aws_ami_name_x86_64_10" {
  expression = "AlmaLinux OS ${var.os_ver_10}.${formatdate("YYYYMMDD", timestamp())}.${var.build_number} x86_64"
}

local "aws_ami_name_aarch64_10" {
  expression = "AlmaLinux OS ${var.os_ver_10}.${formatdate("YYYYMMDD", timestamp())}.${var.build_number} aarch64"
}

local "aws_ami_description_x86_64_10" {
  expression = "Official AlmaLinux OS ${var.os_ver_10} x86_64 Amazon Machine Image"
}

local "aws_ami_description_aarch64_10" {
  expression = "Official AlmaLinux OS ${var.os_ver_10} aarch64 Amazon Machine Image"
}

local "aws_ami_version_10" {
  expression = "${var.os_ver_10}.${formatdate("YYYYMMDD", timestamp())}.${var.build_number}"
}
# AlmaLinux OS 8
variable "aws_source_ami_8_x86_64" {
  description = "AlmaLinux OS 8 x86_64 AMI as source"

  type    = string
  default = "ami-0f384fefb431fbea2"
}

variable "aws_source_ami_8_aarch64" {
  description = "AlmaLinux OS 8 AArch64 AMI as source"

  type    = string
  default = "ami-099b4f20875da4c84"
}
# AlmaLinux OS 9
variable "aws_source_ami_9_x86_64" {
  description = "AlmaLinux OS 9 x86_64 AMI as source"

  type    = string
  default = "ami-0dcac383e85adfc33"
}

variable "aws_source_ami_9_aarch64" {
  description = "AlmaLinux OS 9 AArch64 AMI as source"

  type    = string
  default = "ami-05d791113b059bae4"
}
# AlmaLinux OS Kitten 10
variable "aws_source_ami_kitten_10_x86_64" {
  description = "AlmaLinux OS Kitten 10 x86_64 AMI as source"

  type    = string
  default = "ami-0bcea1e66829fec5b"
}

variable "aws_source_ami_kitten_10_aarch64" {
  description = "AlmaLinux OS Kitten 10 AArch64 AMI as source"

  type    = string
  default = "ami-0707e89f669cb9128"
}
# AlmaLinux OS 10
variable "aws_source_ami_10_x86_64" {
  description = "AlmaLinux OS 10 x86_64 AMI as source"

  type    = string
  default = "ami-01d87dc7c538eb2b3"
}

variable "aws_source_ami_10_aarch64" {
  description = "AlmaLinux OS 10 AArch64 AMI as source"

  type    = string
  default = "ami-0088cc5c1715837e1"
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

variable "vagrant_boot_command_8_x86_64_bios" {
  description = "Boot command for x86_64 BIOS"

  type = list(string)
  default = [
    "<tab>",
    " inst.text inst.ks=http://{{ .HTTPIP }}:{{ .HTTPPort }}/almalinux-8.vagrant-x86_64-bios.ks",
    "<enter><wait>",
  ]
}

local "vagrant_boot_command_8_x86_64" {
  expression = [
    "c<wait>",
    "linuxefi /images/pxeboot/vmlinuz",
    " inst.stage2=hd:LABEL=AlmaLinux-8-${local.os_ver_minor_8}-x86_64-dvd ro",
    " inst.text biosdevname=0 net.ifnames=0",
    " inst.ks=http://{{ .HTTPIP }}:{{ .HTTPPort }}/almalinux-8.vagrant-x86_64.ks",
    "<enter>",
    "initrdefi /images/pxeboot/initrd.img<enter>",
    "boot<enter><wait>",
  ]
}

variable "vagrant_boot_command_9_x86_64" {
  description = "Boot command for AlmaLinux OS 9 Vagrant x86_64"

  type = list(string)

  default = [
    "e",
    "<down><down>",
    "<leftCtrlOn>e<leftCtrlOff>",
    "<spacebar>",
    "biosdevname=0",
    "<spacebar>",
    "net.ifnames=0",
    "<spacebar>",
    "inst.text",
    "<spacebar>",
    "inst.ks=http://{{ .HTTPIP }}:{{ .HTTPPort }}/almalinux-9.vagrant-x86_64.ks",
    "<leftCtrlOn>x<leftCtrlOff>",
  ]
}

variable "vagrant_boot_command_9_x86_64_bios" {
  description = "Boot command for x86_64 BIOS"

  type = list(string)
  default = [
    "<tab>",
    "inst.text inst.gpt inst.ks=http://{{ .HTTPIP }}:{{ .HTTPPort }}/almalinux-9.vagrant-x86_64-bios.ks",
    "<enter><wait>",
  ]
}

variable "vagrant_boot_command_9_aarch64" {
  description = "Boot command for AlmaLinux OS 9 Vagrant AArch64"

  type = list(string)
  default = [
    "e",
    "<down><down>",
    "<leftCtrlOn>e<leftCtrlOff>",
    "<spacebar>",
    "biosdevname=0",
    "<spacebar>",
    "net.ifnames=0",
    "<spacebar>",
    "inst.text",
    "<spacebar>",
    "inst.ks=http://{{ .HTTPIP }}:{{ .HTTPPort }}/almalinux-9.vagrant-aarch64.ks",
    "<leftCtrlOn>x<leftCtrlOff>",
  ]
}

variable "vagrant_boot_command_kitten_10_x86_64" {
  description = "Boot command for AlmaLinux OS Kitten 10 Vagrant x86_64"

  type = list(string)

  default = [
    "e",
    "<down><down>",
    "<leftCtrlOn>e<leftCtrlOff>",
    "<spacebar>",
    "biosdevname=0",
    "<spacebar>",
    "net.ifnames=0",
    "<spacebar>",
    "inst.text",
    "<spacebar>",
    "inst.ks=http://{{ .HTTPIP }}:{{ .HTTPPort }}/almalinux-kitten-10.vagrant-x86_64.ks",
    "<leftCtrlOn>x<leftCtrlOff>",
  ]
}

variable "vagrant_boot_command_kitten_10_x86_64_v2" {
  description = "Boot command for AlmaLinux OS Kitten 10 Vagrant x86_64_v2"

  type = list(string)

  default = [
    "e",
    "<down><down>",
    "<leftCtrlOn>e<leftCtrlOff>",
    "<spacebar>",
    "biosdevname=0",
    "<spacebar>",
    "net.ifnames=0",
    "<spacebar>",
    "inst.text",
    "<spacebar>",
    "inst.ks=http://{{ .HTTPIP }}:{{ .HTTPPort }}/almalinux-kitten-10.vagrant-x86_64_v2.ks",
    "<leftCtrlOn>x<leftCtrlOff>",
  ]
}

variable "vagrant_boot_command_kitten_10_aarch64" {
  description = "Boot command for AlmaLinux OS Kitten 10 Vagrant aarch64"

  type = list(string)

  default = [
    "e",
    "<down><down>",
    "<leftCtrlOn>e<leftCtrlOff>",
    "<spacebar>",
    "biosdevname=0",
    "<spacebar>",
    "net.ifnames=0",
    "<spacebar>",
    "inst.text",
    "<spacebar>",
    "inst.ks=http://{{ .HTTPIP }}:{{ .HTTPPort }}/almalinux-kitten-10.vagrant-aarch64.ks",
    "<leftCtrlOn>x<leftCtrlOff>",
  ]
}

variable "vagrant_boot_command_10_x86_64" {
  description = "Boot command for AlmaLinux OS 10 Vagrant x86_64"

  type = list(string)

  default = [
    "e",
    "<down><down>",
    "<leftCtrlOn>e<leftCtrlOff>",
    "<spacebar>",
    "biosdevname=0",
    "<spacebar>",
    "net.ifnames=0",
    "<spacebar>",
    "inst.text",
    "<spacebar>",
    "inst.ks=http://{{ .HTTPIP }}:{{ .HTTPPort }}/almalinux-10.vagrant-x86_64.ks",
    "<leftCtrlOn>x<leftCtrlOff>",
  ]
}

variable "vagrant_boot_command_10_x86_64_v2" {
  description = "Boot command for AlmaLinux OS 10 Vagrant x86_64_v2"

  type = list(string)

  default = [
    "e",
    "<down><down>",
    "<leftCtrlOn>e<leftCtrlOff>",
    "<spacebar>",
    "biosdevname=0",
    "<spacebar>",
    "net.ifnames=0",
    "<spacebar>",
    "inst.text",
    "<spacebar>",
    "inst.ks=http://{{ .HTTPIP }}:{{ .HTTPPort }}/almalinux-10.vagrant-x86_64_v2.ks",
    "<leftCtrlOn>x<leftCtrlOff>",
  ]
}

variable "vagrant_boot_command_10_aarch64" {
  description = "Boot command for AlmaLinux OS 10 Vagrant aarch64"

  type = list(string)

  default = [
    "e",
    "<down><down>",
    "<leftCtrlOn>e<leftCtrlOff>",
    "<spacebar>",
    "biosdevname=0",
    "<spacebar>",
    "net.ifnames=0",
    "<spacebar>",
    "inst.text",
    "<spacebar>",
    "inst.ks=http://{{ .HTTPIP }}:{{ .HTTPPort }}/almalinux-10.vagrant-aarch64.ks",
    "<leftCtrlOn>x<leftCtrlOff>",
  ]
}
# Hyper-V

variable "hyperv_switch_name" {
  description = "The name of the switch to connect the virtual machine to"

  type    = string
  default = null
}

variable "hyperv_boot_command_8_x86_64" {
  description = "Boot command for AlmaLinux OS 8 Hyper-V x86_64"

  type = list(string)

  default = [
    "e",
    "<down><down>",
    "<leftCtrlOn>e<leftCtrlOff>",
    "<spacebar>",
    "biosdevname=0",
    "<spacebar>",
    "net.ifnames=0",
    "<spacebar>",
    "inst.text",
    "<spacebar>",
    "inst.ks=http://{{ .HTTPIP }}:{{ .HTTPPort }}/almalinux-8.vagrant-x86_64.ks",
    "<leftCtrlOn>x<leftCtrlOff>",
  ]
}

variable "hyperv_boot_command_9_x86_64" {
  description = "Boot command for AlmaLinux OS 9 Hyper-V x86_64"

  type = list(string)

  default = [
    "e",
    "<down><down>",
    "<leftCtrlOn>e<leftCtrlOff>",
    "<spacebar>",
    "biosdevname=0",
    "<spacebar>",
    "net.ifnames=0",
    "<spacebar>",
    "inst.text",
    "<spacebar>",
    "inst.ks=http://{{ .HTTPIP }}:{{ .HTTPPort }}/almalinux-9.vagrant-x86_64.ks",
    "<leftCtrlOn>x<leftCtrlOff>",
  ]
}

variable "hyperv_boot_command_kitten_10_x86_64" {
  description = "Boot command for AlmaLinux OS Kitten 10 Hyper-V x86_64"

  type = list(string)

  default = [
    "e",
    "<down><down>",
    "<leftCtrlOn>e<leftCtrlOff>",
    "<spacebar>",
    "biosdevname=0",
    "<spacebar>",
    "net.ifnames=0",
    "<spacebar>",
    "inst.text",
    "<spacebar>",
    "inst.ks=http://{{ .HTTPIP }}:{{ .HTTPPort }}/almalinux-kitten-10.vagrant-x86_64.ks",
    "<leftCtrlOn>x<leftCtrlOff>",
  ]
}

variable "hyperv_boot_command_kitten_10_x86_64_v2" {
  description = "Boot command for AlmaLinux OS Kitten 10 Hyper-V x86_64_v2"

  type = list(string)

  default = [
    "e",
    "<down><down>",
    "<leftCtrlOn>e<leftCtrlOff>",
    "<spacebar>",
    "biosdevname=0",
    "<spacebar>",
    "net.ifnames=0",
    "<spacebar>",
    "inst.text",
    "<spacebar>",
    "inst.ks=http://{{ .HTTPIP }}:{{ .HTTPPort }}/almalinux-kitten-10.vagrant-x86_64_v2.ks",
    "<leftCtrlOn>x<leftCtrlOff>",
  ]
}

variable "hyperv_boot_command_10_x86_64" {
  description = "Boot command for AlmaLinux OS 10 Hyper-V x86_64"

  type = list(string)

  default = [
    "e",
    "<down><down>",
    "<leftCtrlOn>e<leftCtrlOff>",
    "<spacebar>",
    "biosdevname=0",
    "<spacebar>",
    "net.ifnames=0",
    "<spacebar>",
    "inst.text",
    "<spacebar>",
    "inst.ks=http://{{ .HTTPIP }}:{{ .HTTPPort }}/almalinux-10.vagrant-x86_64.ks",
    "<leftCtrlOn>x<leftCtrlOff>",
  ]
}

variable "hyperv_boot_command_10_x86_64_v2" {
  description = "Boot command for AlmaLinux OS 10 Hyper-V x86_64_v2"

  type = list(string)

  default = [
    "e",
    "<down><down>",
    "<leftCtrlOn>e<leftCtrlOff>",
    "<spacebar>",
    "biosdevname=0",
    "<spacebar>",
    "net.ifnames=0",
    "<spacebar>",
    "inst.text",
    "<spacebar>",
    "inst.ks=http://{{ .HTTPIP }}:{{ .HTTPPort }}/almalinux-10.vagrant-x86_64_v2.ks",
    "<leftCtrlOn>x<leftCtrlOff>",
  ]
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

# Oracle Cloud Infrastructure (OCI)

local "oci_boot_command_8_x86_64" {
  expression = [
    "c<wait>",
    "linuxefi",
    " /images/pxeboot/vmlinuz",
    " inst.stage2=hd:LABEL=AlmaLinux-8-${local.os_ver_minor_8}-x86_64-dvd ro",
    " inst.text biosdevname=0 net.ifnames=0",
    " inst.ks=http://{{ .HTTPIP }}:{{ .HTTPPort }}/almalinux-8.oci-x86_64.ks",
    "<enter>",
    "initrdefi /images/pxeboot/initrd.img",
    "<enter>",
    "boot<enter><wait>",
  ]
}

local "oci_boot_command_8_aarch64" {
  expression = [
    "c<wait>",
    "linux /images/pxeboot/vmlinuz",
    " inst.stage2=hd:LABEL=AlmaLinux-8-${local.os_ver_minor_8}-aarch64-dvd ro",
    " inst.text biosdevname=0 net.ifnames=0",
    " inst.ks=http://{{ .HTTPIP }}:{{ .HTTPPort }}/almalinux-8.oci-aarch64.ks",
    "<enter>",
    "initrd /images/pxeboot/initrd.img",
    "<enter>",
    "boot<enter><wait>",
  ]
}

variable "oci_boot_command_9_x86_64" {
  description = "Boot command for AlmaLinux OS 9 OCI x86_64"

  type = list(string)
  default = [
    "e",
    "<down><down>",
    "<leftCtrlOn>e<leftCtrlOff>",
    "<spacebar>",
    "biosdevname=0",
    "<spacebar>",
    "net.ifnames=0",
    "<spacebar>",
    "inst.text",
    "<spacebar>",
    "inst.ks=http://{{ .HTTPIP }}:{{ .HTTPPort }}/almalinux-9.oci-x86_64.ks",
    "<leftCtrlOn>x<leftCtrlOff>",
  ]
}

variable "oci_boot_command_9_aarch64" {
  description = "Boot command for AlmaLinux OS 9 OCI AArch64"

  type = list(string)

  default = [
    "e",
    "<down><down>",
    "<leftCtrlOn>e<leftCtrlOff>",
    "<spacebar>",
    "biosdevname=0",
    "<spacebar>",
    "net.ifnames=0",
    "<spacebar>",
    "inst.text",
    "<spacebar>",
    "inst.ks=http://{{ .HTTPIP }}:{{ .HTTPPort }}/almalinux-9.oci-aarch64.ks",
    "<leftCtrlOn>x<leftCtrlOff>",
  ]
}

variable "oci_boot_command_10_x86_64" {
  description = "Boot command for AlmaLinux OS 10 OCI x86_64"

  type = list(string)
  default = [
    "e",
    "<down><down>",
    "<leftCtrlOn>e<leftCtrlOff>",
    "<spacebar>",
    "biosdevname=0",
    "<spacebar>",
    "net.ifnames=0",
    "<spacebar>",
    "inst.text",
    "<spacebar>",
    "inst.ks=http://{{ .HTTPIP }}:{{ .HTTPPort }}/almalinux-10.oci-x86_64.ks",
    "<leftCtrlOn>x<leftCtrlOff>",
  ]
}

variable "oci_boot_command_10_aarch64" {
  description = "Boot command for AlmaLinux OS 10 OCI AArch64"

  type = list(string)

  default = [
    "e",
    "<down><down>",
    "<leftCtrlOn>e<leftCtrlOff>",
    "<spacebar>",
    "biosdevname=0",
    "<spacebar>",
    "net.ifnames=0",
    "<spacebar>",
    "inst.text",
    "<spacebar>",
    "inst.ks=http://{{ .HTTPIP }}:{{ .HTTPPort }}/almalinux-10.oci-aarch64.ks",
    "<leftCtrlOn>x<leftCtrlOff>",
  ]
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

# The aarch64 GenericCloud boot commands as the gencloud templates use them:
# the TCG prefix (empty on the arm64 host) plus the command, with the extra
# installer arguments (empty on the arm64 host) typed before GRUB's Ctrl-X.
# The 8 commands are GRUB command-line sequences that carry the extra
# arguments on their "linux" line already.
local "aarch64_gencloud_boot_command_8" {
  expression = concat(local.aarch64_boot_prefix, local.gencloud_boot_command_8_aarch64)
}

local "aarch64_gencloud_boot_command_9" {
  expression = concat(
    local.aarch64_boot_prefix,
    slice(var.gencloud_boot_command_9_aarch64, 0, length(var.gencloud_boot_command_9_aarch64) - 1),
    var.aarch64_extra_kernel_args != "" ? ["<spacebar>", var.aarch64_extra_kernel_args] : [],
    [var.gencloud_boot_command_9_aarch64[length(var.gencloud_boot_command_9_aarch64) - 1]],
  )
}

local "aarch64_gencloud_boot_command_10" {
  expression = concat(
    local.aarch64_boot_prefix,
    slice(var.gencloud_boot_command_10_aarch64, 0, length(var.gencloud_boot_command_10_aarch64) - 1),
    var.aarch64_extra_kernel_args != "" ? ["<spacebar>", var.aarch64_extra_kernel_args] : [],
    [var.gencloud_boot_command_10_aarch64[length(var.gencloud_boot_command_10_aarch64) - 1]],
  )
}

local "aarch64_gencloud_boot_command_kitten_10" {
  expression = concat(
    local.aarch64_boot_prefix,
    slice(var.gencloud_boot_command_kitten_10_aarch64, 0, length(var.gencloud_boot_command_kitten_10_aarch64) - 1),
    var.aarch64_extra_kernel_args != "" ? ["<spacebar>", var.aarch64_extra_kernel_args] : [],
    [var.gencloud_boot_command_kitten_10_aarch64[length(var.gencloud_boot_command_kitten_10_aarch64) - 1]],
  )
}

local "aarch64_gencloud_ext4_boot_command_8" {
  expression = concat(local.aarch64_boot_prefix, local.gencloud_ext4_boot_command_8_aarch64)
}

local "aarch64_gencloud_ext4_boot_command_9" {
  expression = concat(
    local.aarch64_boot_prefix,
    slice(var.gencloud_ext4_boot_command_9_aarch64, 0, length(var.gencloud_ext4_boot_command_9_aarch64) - 1),
    var.aarch64_extra_kernel_args != "" ? ["<spacebar>", var.aarch64_extra_kernel_args] : [],
    [var.gencloud_ext4_boot_command_9_aarch64[length(var.gencloud_ext4_boot_command_9_aarch64) - 1]],
  )
}

local "aarch64_gencloud_ext4_boot_command_10" {
  expression = concat(
    local.aarch64_boot_prefix,
    slice(var.gencloud_ext4_boot_command_10_aarch64, 0, length(var.gencloud_ext4_boot_command_10_aarch64) - 1),
    var.aarch64_extra_kernel_args != "" ? ["<spacebar>", var.aarch64_extra_kernel_args] : [],
    [var.gencloud_ext4_boot_command_10_aarch64[length(var.gencloud_ext4_boot_command_10_aarch64) - 1]],
  )
}

local "aarch64_gencloud_ext4_boot_command_kitten_10" {
  expression = concat(
    local.aarch64_boot_prefix,
    slice(var.gencloud_ext4_boot_command_kitten_10_aarch64, 0, length(var.gencloud_ext4_boot_command_kitten_10_aarch64) - 1),
    var.aarch64_extra_kernel_args != "" ? ["<spacebar>", var.aarch64_extra_kernel_args] : [],
    [var.gencloud_ext4_boot_command_kitten_10_aarch64[length(var.gencloud_ext4_boot_command_kitten_10_aarch64) - 1]],
  )
}
