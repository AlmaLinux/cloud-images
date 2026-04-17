#!/usr/bin/env bash
#
# Resolve packer_source, output_mask, and aws_s3_path for a given image
# type / version combination.
#
# Usage:
#   resolve-image-config.sh <type> <version_major> <alma_arch> \
#                           <variant> <release> <timestamp>
#
# Prints KEY=VALUE lines to stdout (suitable for appending to $GITHUB_ENV).
#
# Outputs:
#   packer_source  - full Packer source with builder prefix
#   output_mask    - glob to locate the built image file
#   AWS_S3_PATH    - S3 upload path
#   packer_builder - builder type: qemu, virtualbox-iso, or vmware-iso

set -euo pipefail

type=$1
version_major=$2
alma_arch=$3
variant=$4
release=$5
timestamp=$6

# -------------------------------------------------------------------
# Defaults
# -------------------------------------------------------------------
packer_source="almalinux-${version_major}-${type}-${alma_arch}"
output_mask="${packer_source}/AlmaLinux-${version_major}-*.${alma_arch}.qcow2"
aws_s3_path="images/${version_major}/${release}/${type}/${timestamp}"
packer_builder=qemu

# -------------------------------------------------------------------
# Override packer source, output mask and S3 path where necessary
# -------------------------------------------------------------------
case "${type}_${version_major}" in

  azure_8|azure_9)
    [[ ${variant} == *"64k"* ]] && packer_source="almalinux_${version_major}_${type}_64k_${alma_arch}"
    output_mask="output-${packer_source}/AlmaLinux-*${version_major}*.${alma_arch}.raw"
    packer_source="qemu.${packer_source}"
    ;;

  hyperv_8)
    packer_source="almalinux-${version_major}-hyperv-${alma_arch}"
    output_mask="AlmaLinux-${version_major}-Vagrant-*.${alma_arch}.hyperv.box"
    packer_source="qemu.${packer_source}"
    aws_s3_path="images/${version_major}/${release}/vagrant/${timestamp}"
    ;;

  hyperv_9)
    output_mask="AlmaLinux-${version_major}-Vagrant-hyperv-*.${alma_arch}.box"
    packer_source="qemu.${packer_source}"
    aws_s3_path="images/${version_major}/${release}/vagrant/${timestamp}"
    ;;

  hyperv_10)
    packer_source="almalinux_10_vagrant_hyperv_${alma_arch}"
    [[ ${version_major} == *"v2"* ]] && packer_source="${packer_source}_v2"
    output_mask="AlmaLinux-${version_major}-Vagrant-hyperv-*.${alma_arch}.box"
    packer_source="qemu.${packer_source}"
    aws_s3_path="images/${version_major}/${release}/vagrant/${timestamp}"
    ;;

  hyperv*kitten*)
    packer_source="almalinux_kitten_10_vagrant_hyperv_${alma_arch}"
    [[ ${version_major} == *"v2"* ]] && packer_source="${packer_source}_v2"
    output_mask="AlmaLinux-Kitten-Vagrant-hyperv-10-*.${alma_arch}.box"
    aws_s3_path="images/kitten/10/vagrant/${timestamp}"
    packer_source="qemu.${packer_source}"
    ;;

  azure*kitten*)
    packer_source="almalinux_kitten_10_${type}_${alma_arch}"
    [[ ${version_major} == *"v2"* ]] && packer_source="${packer_source}_v2"
    [[ ${variant} == *"64k"* ]] && packer_source="${packer_source}_64k"
    output_mask="output-${packer_source}/AlmaLinux-Kitten-*.${alma_arch}*.raw"
    aws_s3_path="images/kitten/10/${type}/${timestamp}"
    packer_source="qemu.${packer_source}"
    ;;

  azure_10)
    packer_source="almalinux_${version_major}_${type}_${alma_arch}"
    [[ ${version_major} == *"v2"* ]] && packer_source="${packer_source}_v2"
    [[ ${variant} == *"64k"* ]] && packer_source="almalinux_${version_major}_${type}_64k_${alma_arch}"
    output_mask="output-${packer_source}/AlmaLinux-*.${alma_arch}*.raw"
    packer_source="qemu.${packer_source}"
    ;;

  digitalocean*)
    output_mask="output-${packer_source}/AlmaLinux-${version_major}-DigitalOcean-*.${alma_arch}.qcow2"
    packer_source="qemu.${packer_source}"
    ;;

  vagrant_libvirt_8)
    packer_source="qemu.almalinux-${version_major}"
    output_mask="AlmaLinux-${version_major}-Vagrant-*.${alma_arch}.libvirt.box"
    aws_s3_path="images/${version_major}/${release}/vagrant/${timestamp}"
    ;;

  vagrant_libvirt_9)
    packer_source="qemu.almalinux-${version_major}"
    output_mask="AlmaLinux-${version_major}-Vagrant-libvirt-*.${alma_arch}.box"
    aws_s3_path="images/${version_major}/${release}/vagrant/${timestamp}"
    ;;

  vagrant_libvirt_10)
    packer_source="qemu.almalinux_${version_major}_vagrant_libvirt_${alma_arch}"
    output_mask="AlmaLinux-${version_major}-Vagrant-libvirt-*.${alma_arch}.box"
    aws_s3_path="images/${version_major}/${release}/vagrant/${timestamp}"
    ;;

  vagrant_virtualbox_8)
    packer_builder=virtualbox-iso
    packer_source="virtualbox-iso.almalinux-${version_major}"
    output_mask="AlmaLinux-${version_major}-Vagrant-*.${alma_arch}.virtualbox.box"
    aws_s3_path="images/${version_major}/${release}/vagrant/${timestamp}"
    ;;

  vagrant_virtualbox_9)
    packer_builder=virtualbox-iso
    packer_source="virtualbox-iso.almalinux-${version_major}"
    output_mask="AlmaLinux-${version_major}-Vagrant-virtualbox-*.${alma_arch}.box"
    aws_s3_path="images/${version_major}/${release}/vagrant/${timestamp}"
    ;;

  vagrant_virtualbox_10)
    packer_builder=virtualbox-iso
    packer_source="virtualbox-iso.almalinux_${version_major}_vagrant_virtualbox_${alma_arch}"
    output_mask="AlmaLinux-${version_major}-Vagrant-virtualbox-*.${alma_arch}.box"
    aws_s3_path="images/${version_major}/${release}/vagrant/${timestamp}"
    ;;

  vagrant_vmware_8)
    packer_builder=vmware-iso
    packer_source="vmware-iso.almalinux-${version_major}"
    output_mask="AlmaLinux-${version_major}-Vagrant-*.${alma_arch}.vmware.box"
    aws_s3_path="images/${version_major}/${release}/vagrant/${timestamp}"
    ;;

  vagrant_vmware_9)
    packer_builder=vmware-iso
    packer_source="vmware-iso.almalinux-${version_major}"
    output_mask="AlmaLinux-${version_major}-Vagrant-vmware-*.${alma_arch}.box"
    aws_s3_path="images/${version_major}/${release}/vagrant/${timestamp}"
    ;;

  vagrant_vmware_10)
    packer_builder=vmware-iso
    packer_source="vmware-iso.almalinux_${version_major}_vagrant_vmware_${alma_arch}"
    output_mask="AlmaLinux-${version_major}-Vagrant-vmware-*.${alma_arch}.box"
    aws_s3_path="images/${version_major}/${release}/vagrant/${timestamp}"
    ;;

  vagrant_vmware*kitten*)
    packer_builder=vmware-iso
    packer_source="vmware-iso.almalinux_kitten_10_vagrant_vmware_${alma_arch}"
    output_mask="AlmaLinux-Kitten-Vagrant-vmware-10-*.${alma_arch}.box"
    aws_s3_path="images/kitten/10/vagrant/${timestamp}"
    ;;

  vagrant_libvirt*kitten*)
    packer_source="qemu.almalinux_kitten_10_${type}_${alma_arch}"
    [[ ${version_major} == *"v2"* ]] && packer_source="${packer_source}_v2"
    output_mask="AlmaLinux-Kitten-Vagrant-libvirt-10-*.${alma_arch}*.box"
    aws_s3_path="images/kitten/10/vagrant/${timestamp}"
    ;;

  vagrant_virtualbox*kitten*)
    packer_builder=virtualbox-iso
    packer_source="virtualbox-iso.almalinux_kitten_10_${type}_${alma_arch}"
    [[ ${version_major} == *"v2"* ]] && packer_source="${packer_source}_v2"
    output_mask="AlmaLinux-Kitten-Vagrant-virtualbox-10-*.${alma_arch}*.box"
    aws_s3_path="images/kitten/10/vagrant/${timestamp}"
    ;;

  *kitten*)
    packer_source="almalinux_kitten_10_${type}_${alma_arch}"
    [[ ${version_major} == *"v2"* ]] && packer_source="${packer_source}_v2"
    output_mask="output-${packer_source}/AlmaLinux-Kitten-*.${alma_arch}*.qcow2"
    aws_s3_path="images/kitten/10/${type}/${timestamp}"
    packer_source="qemu.${packer_source}"
    ;;

  gencloud_ext4_8|gencloud_ext4_9)
    packer_source="almalinux-${version_major}-gencloud-ext4-${alma_arch}"
    output_mask="output-${packer_source}/AlmaLinux-${version_major}-*.${alma_arch}.qcow2"
    packer_source="qemu.${packer_source}"
    aws_s3_path="images/${version_major}/${release}/gencloud_ext4/${timestamp}"
    ;;

  gencloud_10|gencloud_ext4_10|opennebula_10)
    packer_source="almalinux_${version_major}_${type}_${alma_arch}"
    [[ ${version_major} == *"v2"* ]] && packer_source="${packer_source}_v2"
    output_mask="output-${packer_source}/AlmaLinux-*.${alma_arch}*.qcow2"
    packer_source="qemu.${packer_source}"
    ;;

  *)
    output_mask="output-${output_mask}"
    packer_source="qemu.${packer_source}"
    ;;

esac

echo "packer_source=${packer_source}"
echo "output_mask=${output_mask}"
echo "AWS_S3_PATH=${aws_s3_path}"
echo "packer_builder=${packer_builder}"
