#!/bin/bash

# The script creates Vagrant box file for the Hyper-V, with the following content:
# - Virtual Machines/box.xml, copied from the templated file
# - Virtual Hard Disks/almalinux.vhdx, converted with qemu-img from the raw image
# - Vagrantfile, empty file
# - metadata.json, with the architecture and provider information
#
# These files are packed by the tar+gzip to match Vagrant for Hyper-V box format
#
# The script is called by the shell-local post-processor from the packer template.
# The predefined vagrant post-processor is not used, because it skips 'Virtual Machines' and 'Virtual Hard Disks' directories.
#
# The raw image is not used by the Hyper-V, but it is kept for the GitHub Actions workflow to extract packages list from it

# Usage:
#  tools/raw-to-vagrant-hyperv.sh <SOURCE_NAME> <BOX_NAME>

# Source Name, like:
#  almalinux-8-hyperv-x86_64
#  almalinux-9-hyperv-x86_64
#  almalinux_10_vagrant_hyperv_x86_64
#  almalinux_kitten_10_vagrant_hyperv_x86_64
source_name=$1

# Box Name, like:
#  AlmaLinux-8-Vagrant-8.10-YYYYMMDD.x86_64.hyperv
#  AlmaLinux-9-Vagrant-hyperv-9.6-YYYYMMDD.x86_64
#  AlmaLinux-10-Vagrant-hyperv-10.0-YYYYMMDD.0.x86_64
#  AlmaLinux-Kitten-Vagrant-hyperv-10-YYYYMMDD.0.x86_64
box_name=$2

# Creates:
#  <BOX_NAME>.box
#  <BOX_NAME>.raw

mkdir -p "${source_name}/Virtual Machines" "${source_name}/Virtual Hard Disks"
touch "${source_name}/Vagrantfile"
echo '{"architecture":"amd64","provider":"hyperv"}' > "${source_name}/metadata.json"
cp -a ./tpl/vagrant/hyperv/box.xml "${source_name}/Virtual Machines/box.xml"
qemu-img convert -f raw -O vhdx "output-${source_name}/${source_name}.raw" "${source_name}/Virtual Hard Disks/almalinux.vhdx"
cd "${source_name}" || exit 1
tar --use-compress-program='gzip -9' -cvf "../${box_name}.box" .
cd - > /dev/null 2>&1 || exit 1
mv "output-${source_name}/${source_name}.raw" "${box_name}.raw"
rm -rf "${source_name}" "output-${source_name}"
