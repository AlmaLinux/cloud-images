#!/bin/bash

# The script creates a Vagrant box for the Parallels provider (Parallels
# Desktop) from a raw disk image built with QEMU, the way
# raw-to-vagrant-hyperv.sh does for Hyper-V. It is used for the aarch64 box,
# built under QEMU (TCG on an x86_64 runner) because there is no runner that
# can run Parallels guests. The box contains:
# - <VM_NAME>.pvm/config.pvs, rendered from tpl/vagrant/parallels/box-aarch64.pvs
#   (cut from the box the parallels-iso builder produces: EFI, one SATA disk,
#   one virtio network adapter, 4 vCPUs / 4096 MB), with fresh VM and disk
#   UUIDs and MAC addresses
# - <VM_NAME>.pvm/harddisk1.hdd/: the disk as an expanding Parallels image
#   (DiskDescriptor.xml + one .hds with the fixed base image ID), converted
#   with qemu-img from the raw image and rewritten into the "WithoutFreeSpace"
#   layout Parallels Desktop itself writes (qemu-img writes the
#   "WithouFreSpacExt" one)
# - Vagrantfile, empty file
# - metadata.json, with the architecture and provider information
#
# Parallels Desktop creates the rest (NVRAM.dat, VmInfo.pvi) on the first
# boot.
#
# These files are packed by tar+gzip to match the Vagrant box format.
#
# The script is called by the shell-local post-processor from the packer
# template. The raw image is kept for the GitHub Actions workflow to check
# the release and extract the package list from it.

# Usage:
#  tools/raw-to-vagrant-parallels.sh <SOURCE_NAME> <BOX_NAME> [<NUMVCPUS> <MEMSIZE_MB>]

# Source Name, like:
#  almalinux-9-parallels-aarch64
#  almalinux_10_vagrant_parallels_qemu_aarch64
#  almalinux_kitten_10_vagrant_parallels_qemu_aarch64
source_name=$1

# Box Name, like:
#  AlmaLinux-9-Vagrant-parallels-9.8-YYYYMMDD.aarch64
#  AlmaLinux-10-Vagrant-parallels-10.2-YYYYMMDD.0.aarch64
#  AlmaLinux-Kitten-Vagrant-parallels-10-YYYYMMDD.0.aarch64
box_name=$2

# The VM defaults the box ships with (the parallels-iso boxes: 4 / 4096)
numvcpus=${3:-4}
memsize=${4:-4096}

# Creates:
#  <BOX_NAME>.box
#  <BOX_NAME>.raw

set -euo pipefail

case "${box_name}" in
  *.aarch64) architecture=arm64 ;;
  *) echo "[Error] ${box_name}: only aarch64 boxes are built this way" >&2; exit 1 ;;
esac

raw="output-${source_name}/${source_name}.raw"
# The Parallels Tools version the provisioning installed, downloaded from the
# guest by the packer template
tools_version_file="output-${source_name}/parallels-tools.version"
tools_version=$(sed -E 's/\.([0-9]+)$/-\1/' "${tools_version_file}" 2>/dev/null || true)

uuid() { cat /proc/sys/kernel/random/uuid; }
# A MAC address in the Parallels range (00:1C:42), as Parallels assigns them
mac() { printf '001C42%s' "$(od -An -N3 -tx1 /dev/urandom | tr -d ' \n' | tr 'a-f' 'A-F')"; }

vm_name=${box_name/-Vagrant-parallels-/-Vagrant-Parallels-}
pvm="${source_name}/${vm_name}.pvm"
hdd="${pvm}/harddisk1.hdd"
# The base image (the first snapshot) of a Parallels disk must carry this
# fixed ID, in the .hds file name and in DiskDescriptor.xml: Parallels does
# not find a base image with any other ID (the disk directory "does not
# contain any virtual hard disk images"), see qemu's docs/interop/prl-xml.txt.
# Every disk Parallels Desktop creates uses it too.
hds_uuid=5fbaabe3-6958-40ff-92a7-860e329aab41
hds="${hdd}/harddisk1.hdd.0.{${hds_uuid}}.hds"

rm -rf "${source_name}"
mkdir -p "${hdd}"

# The disk: an expanding image with 1 MiB clusters, as Parallels creates it
qemu-img convert -f raw -O parallels -o cluster_size=1M "${raw}" "${hds}"
# qemu-img writes the "WithouFreSpacExt" header, whose allocation table holds
# cluster numbers; Parallels Desktop writes "WithoutFreeSpace", whose table
# holds sector offsets. Rewrite it to match the disks Parallels Desktop makes.
python3 - "${hds}" <<'PY'
import struct, sys
with open(sys.argv[1], "r+b") as f:
    header = bytearray(f.read(64))
    if header[:16] != b"WithouFreSpacExt":
        sys.exit(f"unexpected header {bytes(header[:16])!r}")
    tracks, bat_entries = struct.unpack_from("<II", header, 28)
    bat = list(struct.unpack(f"<{bat_entries}I", f.read(4 * bat_entries)))
    bat = [c * tracks for c in bat]
    if max(bat, default=0) > 0xFFFFFFFF:
        sys.exit("the disk is too large for the WithoutFreeSpace layout")
    header[:16] = b"WithoutFreeSpace"
    f.seek(0)
    f.write(header)
    f.write(struct.pack(f"<{bat_entries}I", *bat))
PY
qemu-img check -f parallels "${hds}"
: > "${hdd}/harddisk1.hdd"

disk_sectors=$(( $(stat -c %s "${raw}") / 512 ))
disk_size_mb=$(( disk_sectors / 2048 ))
disk_size_on_disk_mb=$(( ($(stat -c %s "${hds}") + 1048575) / 1048576 ))

cat > "${hdd}/DiskDescriptor.xml" <<XML
<?xml version='1.0' encoding='UTF-8'?>
<Parallels_disk_image Version="1.0">
    <Disk_Parameters>
        <Disk_size>${disk_sectors}</Disk_size>
        <Cylinders>$(( disk_sectors / (16 * 32) ))</Cylinders>
        <PhysicalSectorSize>4096</PhysicalSectorSize>
        <LogicSectorSize>512</LogicSectorSize>
        <Heads>16</Heads>
        <Sectors>32</Sectors>
        <Padding>0</Padding>
        <Encryption>
            <Engine>{00000000-0000-0000-0000-000000000000}</Engine>
            <Data></Data>
            <Salt></Salt>
        </Encryption>
        <UID>{$(uuid)}</UID>
        <Name>harddisk1 SSD</Name>
        <Miscellaneous>
            <CompatLevel>level2</CompatLevel>
            <SuspendState>0</SuspendState>
            <DupBlocksCnt>0</DupBlocksCnt>
            <CorruptBlocksCnt>0</CorruptBlocksCnt>
            <UnrefBlocksCnt>0</UnrefBlocksCnt>
            <OutOfDiskBlocksCnt>0</OutOfDiskBlocksCnt>
            <BatOverlapBlocksCnt>0</BatOverlapBlocksCnt>
            <BlocksCnt>0</BlocksCnt>
            <TruncatedBlocksCnt>0</TruncatedBlocksCnt>
            <ReferencedBlocksCnt>0</ReferencedBlocksCnt>
            <Bootable>1</Bootable>
            <ChangeState>1</ChangeState>
            <GuestToolsVersion>${tools_version}</GuestToolsVersion>
            <ShutdownState>0</ShutdownState>
        </Miscellaneous>
    </Disk_Parameters>
    <StorageData>
        <Storage>
            <Start>0</Start>
            <End>${disk_sectors}</End>
            <Blocksize>2048</Blocksize>
            <Image>
                <GUID>{${hds_uuid}}</GUID>
                <Type>Compressed</Type>
                <File>${hds##*/}</File>
            </Image>
        </Storage>
    </StorageData>
    <Snapshots>
        <Shot>
            <GUID>{${hds_uuid}}</GUID>
            <ParentGUID>{00000000-0000-0000-0000-000000000000}</ParentGUID>
        </Shot>
    </Snapshots>
</Parallels_disk_image>
XML

sed -e "s/@VM_UUID@/$(uuid)/g" -e "s/@VM_NAME@/${vm_name}/" \
  -e "s/@CREATION_DATE@/$(date -u '+%Y-%m-%d %H:%M:%S')/g" \
  -e "s/@TOOLS_VERSION@/${tools_version}/" -e "s/@HDD_UUID@/$(uuid)/" \
  -e "s/@DISK_SIZE_MB@/${disk_size_mb}/" -e "s/@DISK_SIZE_ON_DISK_MB@/${disk_size_on_disk_mb}/" \
  -e "s/@NUMVCPUS@/${numvcpus}/" -e "s/@MEMSIZE@/${memsize}/" \
  -e "s/@MAC@/$(mac)/" -e "s/@HOST_MAC@/$(mac)/" \
  ./tpl/vagrant/parallels/box-aarch64.pvs > "${pvm}/config.pvs"
if grep -nE '@(VM_UUID|VM_NAME|CREATION_DATE|TOOLS_VERSION|HDD_UUID|DISK_SIZE_MB|DISK_SIZE_ON_DISK_MB|NUMVCPUS|MEMSIZE|MAC|HOST_MAC)@' "${pvm}/config.pvs"; then
  echo "[Error] unrendered placeholders in config.pvs" >&2
  exit 1
fi

touch "${source_name}/Vagrantfile"
echo "{\"architecture\":\"${architecture}\",\"provider\":\"parallels\"}" > "${source_name}/metadata.json"
ls -laR "${source_name}"
cd "${source_name}" || exit 1
tar --use-compress-program='gzip -9' -cvf "../${box_name}.box" .
cd - > /dev/null 2>&1 || exit 1
mv "${raw}" "${box_name}.raw"
rm -rf "${source_name}" "output-${source_name}"
