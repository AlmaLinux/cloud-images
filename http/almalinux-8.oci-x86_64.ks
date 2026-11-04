# AlmaLinux OS 8 kickstart file for Oracle Cloud Infrastructure (OCI) images with unified (BIOS+UEFI) boot on x86_64

url --url https://repo.almalinux.org/almalinux/8/BaseOS/x86_64/os

text
skipx
eula --agreed
firstboot --disabled
lang en_US.UTF-8
keyboard us
timezone UTC --isUtc
network --bootproto=dhcp
firewall --disabled
services --disabled="kdump" --enabled="chronyd,rsyslog,sshd"
selinux --enforcing

bootloader --timeout=0 --location=mbr --append="console=tty0 console=ttyS0,115200n8 no_timer_check net.ifnames=0 netroot=iscsi:169.254.0.2:::1:iqn.2015-02.oracle.boot:uefi rd.iscsi.param=node.session.timeo.replacement_timeout=6000 libiscsi.debug_libiscsi_eh=1 nvme_core.shutdown_timeout=10"

%pre --erroronfail

parted -s -a optimal /dev/sda -- mklabel gpt
parted -s -a optimal /dev/sda -- mkpart biosboot 1MiB 2MiB set 1 bios_grub on
parted -s -a optimal /dev/sda -- mkpart '"EFI System Partition"' fat32 2MiB 202MiB set 2 esp on
parted -s -a optimal /dev/sda -- mkpart boot xfs 202MiB 1226MiB
parted -s -a optimal /dev/sda -- mkpart root xfs 1226MiB 100%

%end

part biosboot --fstype=biosboot --onpart=sda1
part /boot/efi --fstype=efi --onpart=sda2
part /boot --fstype=xfs --onpart=sda3
part / --fstype=xfs --onpart=sda4

rootpw --plaintext almalinux

reboot --eject

%packages
@core
grub2-pc
tar
# Packages the image's Ansible provisioning previously installed with dnf:
# preinstalled here so they always come from the same repositories the
# OS is installed from (and, for 9/10 PUNGI pre-release builds, so
# released-version packages are not mixed into a pre-release system).
dracut-config-generic
cloud-init
cloud-utils-growpart
device-mapper-multipath
iscsi-initiator-utils
iscsi-initiator-utils-iscsiuio
jq
nfs-utils
nvme-cli
qemu-guest-agent
rsync
tcpdump
tuned
-biosdevname
-open-vm-tools
-plymouth
-dnf-plugin-spacewalk
-rhn*
-iprutils
-iwl*-firmware
%end

# disable kdump service
%addon com_redhat_kdump --disable
%end

%post --erroronfail

EX_NOINPUT=66

root_disk=$(grub2-probe --target=disk /boot/grub2)

if [[ "$root_disk" =~ ^"/dev/" ]]; then
    grub2-install --target=i386-pc "$root_disk"
else
    exit "$EX_NOINPUT"
fi

%end

%post
# Import the AlmaLinux GPG keys into the RPM database. dnf used to do this
# on the first package install during the Ansible provisioning; with the
# packages preinstalled from this kickstart no dnf transaction runs anymore,
# and images would otherwise ship without the keys imported (the first
# dnf install on a running instance would then prompt to import them).
rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-AlmaLinux*
%end
