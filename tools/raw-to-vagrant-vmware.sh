#!/bin/bash

# The script creates a Vagrant box for the VMware Desktop provider
# (vmware_desktop: VMware Fusion / Workstation) from a raw disk image built
# with QEMU, the way raw-to-vagrant-hyperv.sh does for Hyper-V. It is used
# for the aarch64 box, built under QEMU (TCG on an x86_64 runner) because
# there is no runner that can run VMware Fusion guests. The box contains:
# - <VM_NAME>.vmx, rendered from tpl/vagrant/vmware/box-aarch64.vmx: EFI
#   firmware, one NVMe disk, no network adapter (Vagrant adds its own, as
#   with the boxes packer's vmware-iso builder produces with
#   vmx_remove_ethernet_interfaces)
# - <VM_NAME>.vmxf and an empty <VM_NAME>.vmsd
# - disk.vmdk + disk-s00N.vmdk, converted with qemu-img from the raw image
#   (twoGbMaxExtentSparse, like the disks VMware Fusion itself writes)
# - Vagrantfile, empty file
# - metadata.json, with the architecture and provider information
#
# These files are packed by tar+gzip to match the Vagrant box format.
#
# The script is called by the shell-local post-processor from the packer
# template. The raw image is kept for the GitHub Actions workflow to check
# the release and extract the package list from it.

# Usage:
#  tools/raw-to-vagrant-vmware.sh <SOURCE_NAME> <BOX_NAME> [<NUMVCPUS> <MEMSIZE_MB>]

# Source Name, like:
#  almalinux-9-vmware-aarch64
#  almalinux_10_vagrant_vmware_qemu_aarch64
#  almalinux_kitten_10_vagrant_vmware_qemu_aarch64
source_name=$1

# Box Name, like:
#  AlmaLinux-9-Vagrant-vmware-9.8-YYYYMMDD.aarch64
#  AlmaLinux-10-Vagrant-vmware-10.2-YYYYMMDD.0.aarch64
#  AlmaLinux-Kitten-Vagrant-vmware-10-YYYYMMDD.0.aarch64
box_name=$2

# The VM defaults the box ships with (the hand-built Fusion boxes: 4 / 4096)
numvcpus=${3:-4}
memsize=${4:-4096}

# Creates:
#  <BOX_NAME>.box
#  <BOX_NAME>.raw

set -euo pipefail

case "${box_name}" in
  *.aarch64) guest_os=arm-rhel9-64; architecture=arm64 ;;
  *) echo "[Error] ${box_name}: only aarch64 boxes are built this way" >&2; exit 1 ;;
esac

# The VM name the hand-built boxes use: AlmaLinux-<major>-Vagrant-VMware-...
vm_name=${box_name/-Vagrant-vmware-/-Vagrant-VMware-}

rm -rf "${source_name}"
mkdir -p "${source_name}"
sed -e "s/@VM_NAME@/${vm_name}/g" -e "s/@GUEST_OS@/${guest_os}/" \
  -e "s/@NUMVCPUS@/${numvcpus}/" -e "s/@MEMSIZE@/${memsize}/" \
  ./tpl/vagrant/vmware/box-aarch64.vmx > "${source_name}/${vm_name}.vmx"
cat > "${source_name}/${vm_name}.vmxf" <<VMXF
<?xml version="1.0"?>
<Foundry>
<VM>
<VMId type="string">$(od -An -N16 -tx1 /dev/urandom | tr -s ' ' | sed -E 's/^ //; s/ $//; s/^(([0-9a-f]{2} ){7}[0-9a-f]{2}) /\1-/')</VMId>
<ClientMetaData>
<clientMetaDataAttributes/>
<HistoryEventList/></ClientMetaData>
<vmxPathName type="string">${vm_name}.vmx</vmxPathName></VM></Foundry>
VMXF
: > "${source_name}/${vm_name}.vmsd"
qemu-img convert -f raw -O vmdk -o subformat=twoGbMaxExtentSparse,adapter_type=lsilogic \
  "output-${source_name}/${source_name}.raw" "${source_name}/disk.vmdk"
touch "${source_name}/Vagrantfile"
echo "{\"architecture\":\"${architecture}\",\"provider\":\"vmware_desktop\"}" > "${source_name}/metadata.json"
ls -la "${source_name}"
cd "${source_name}" || exit 1
tar --use-compress-program='gzip -9' -cvf "../${box_name}.box" .
cd - > /dev/null 2>&1 || exit 1
mv "output-${source_name}/${source_name}.raw" "${box_name}.raw"
rm -rf "${source_name}" "output-${source_name}"
