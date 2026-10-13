#!/bin/bash

# The script creates a Vagrant box for the VirtualBox provider from a raw disk
# image built with QEMU, the way raw-to-vagrant-parallels.sh does for
# Parallels Desktop. It is used for the aarch64 box (VirtualBox 7.1+ on Apple
# Silicon), built under QEMU (TCG on an x86_64 runner, natively on an arm64
# one) because there is no runner that can run VirtualBox ARM guests. The box
# contains:
# - box.ovf, rendered from tpl/vagrant/virtualbox/box-aarch64.ovf (exported by
#   VirtualBox 7.2 from an ARM VM of its own defaults for the guest type:
#   ARMv8Virtual chipset, EFI, one VirtioSCSI disk, a virtio NIC on NAT), with
#   fresh VM and disk UUIDs and MAC address
# - box-disk001.vmdk, converted with qemu-img from the raw image
#   (streamOptimized, like the disks VirtualBox exports)
# - Vagrantfile, with the base MAC address, as the packer vagrant
#   post-processor writes it for the x86_64 box
# - metadata.json, with the architecture and provider information
#
# These files are packed by tar+gzip to match the Vagrant box format.
#
# The script is called by the shell-local post-processor from the packer
# template. The raw image is kept for the GitHub Actions workflow to check
# the release and extract the package list from it.

# Usage:
#  tools/raw-to-vagrant-virtualbox.sh <SOURCE_NAME> <BOX_NAME> [<NUMVCPUS> <MEMSIZE_MB>]

# Source Name, like:
#  almalinux-9-virtualbox-aarch64
#  almalinux_10_vagrant_virtualbox_qemu_aarch64
#  almalinux_kitten_10_vagrant_virtualbox_qemu_aarch64
source_name=$1

# Box Name, like:
#  AlmaLinux-9-Vagrant-virtualbox-9.8-YYYYMMDD.aarch64
#  AlmaLinux-10-Vagrant-virtualbox-10.2-YYYYMMDD.0.aarch64
#  AlmaLinux-Kitten-Vagrant-virtualbox-10-YYYYMMDD.0.aarch64
box_name=$2

# The VM defaults the box ships with: VirtualBox's own memory default for the
# guest type, and two vCPUs (EFI VirtualBox guests with one vCPU have been
# seen to hang early in boot)
numvcpus=${3:-2}
memsize=${4:-2048}

# Creates:
#  <BOX_NAME>.box
#  <BOX_NAME>.raw

set -euo pipefail

case "${box_name}" in
  *.aarch64) architecture=arm64 ;;
  *) echo "[Error] ${box_name}: only aarch64 boxes are built this way" >&2; exit 1 ;;
esac

# The VirtualBox guest OS type: Red Hat 9.x or 10.x (ARM 64-bit)
case "${box_name}" in
  AlmaLinux-9-*) ostype=RedHat9_arm64 ;;
  AlmaLinux-10-*|AlmaLinux-Kitten-*) ostype=RedHat10_arm64 ;;
  *) echo "[Error] ${box_name}: unknown AlmaLinux version" >&2; exit 1 ;;
esac

raw="output-${source_name}/${source_name}.raw"

uuid() { cat /proc/sys/kernel/random/uuid; }
# A MAC address in the VirtualBox range (08:00:27), as VirtualBox assigns them
mac() { printf '080027%s' "$(od -An -N3 -tx1 /dev/urandom | tr -d ' \n' | tr 'a-f' 'A-F')"; }

vm_name=${box_name/-Vagrant-virtualbox-/-Vagrant-VirtualBox-}
disk_file=box-disk001.vmdk
base_mac=$(mac)

rm -rf "${source_name}"
mkdir -p "${source_name}"

# The disk: streamOptimized, the VMDK flavour VirtualBox exports and imports
qemu-img convert -f raw -O vmdk -o subformat=streamOptimized "${raw}" "${source_name}/${disk_file}"
qemu-img check -f vmdk "${source_name}/${disk_file}"

sed -e "s/@VM_UUID@/$(uuid)/" -e "s/@VM_NAME@/${vm_name}/g" \
  -e "s/@CREATION_DATE@/$(date -u '+%Y-%m-%dT%H:%M:%SZ')/" \
  -e "s/@OSTYPE@/${ostype}/g" -e "s/@DISK_UUID@/$(uuid)/g" \
  -e "s/@DISK_FILE@/${disk_file}/" -e "s/@DISK_CAPACITY@/$(stat -c %s "${raw}")/" \
  -e "s/@NUMVCPUS@/${numvcpus}/g" -e "s/@MEMSIZE@/${memsize}/g" \
  -e "s/@MAC@/${base_mac}/" \
  ./tpl/vagrant/virtualbox/box-aarch64.ovf > "${source_name}/box.ovf"
if grep -nE '@(VM_UUID|VM_NAME|CREATION_DATE|OSTYPE|DISK_UUID|DISK_FILE|DISK_CAPACITY|NUMVCPUS|MEMSIZE|MAC)@' "${source_name}/box.ovf"; then
  echo "[Error] unrendered placeholders in box.ovf" >&2
  exit 1
fi

cat > "${source_name}/Vagrantfile" <<EOF
Vagrant.configure("2") do |config|
  config.vm.base_mac = "${base_mac}"
end
EOF
echo "{\"architecture\":\"${architecture}\",\"provider\":\"virtualbox\"}" > "${source_name}/metadata.json"
ls -la "${source_name}"
cd "${source_name}" || exit 1
tar --use-compress-program='gzip -9' -cvf "../${box_name}.box" .
cd - > /dev/null 2>&1 || exit 1
mv "${raw}" "${box_name}.raw"
rm -rf "${source_name}" "output-${source_name}"
