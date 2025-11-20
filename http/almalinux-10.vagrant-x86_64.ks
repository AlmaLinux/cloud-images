# AlmaLinux OS 10 kickstart file for Vagrant boxes with unified (BIOS+UEFI) boot on x86_64

url --url https://repo.almalinux.org/almalinux/10/BaseOS/x86_64/os
text
lang en_US.UTF-8
keyboard us
timezone UTC --utc
selinux --enforcing
firewall --disabled
services --enabled=sshd

bootloader --timeout=0 --location=mbr --append="console=tty0 no_timer_check net.ifnames=0"

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

rootpw vagrant
user --name=vagrant --plaintext --password vagrant
reboot --eject

%packages --exclude-weakdeps --inst-langs=en
dracut-config-generic
grub2-pc
tar
-*firmware
-dracut-config-rescue
-firewalld
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

# allow vagrant user to run everything without a password
echo "vagrant     ALL=(ALL)     NOPASSWD: ALL" >> /etc/sudoers.d/vagrant

# see Vagrant documentation (https://docs.vagrantup.com/v2/boxes/base.html)
# for details about the requiretty.
sed -i "s/^.*requiretty/# Defaults requiretty/" /etc/sudoers

# permit root login via SSH with password authetication
echo "PermitRootLogin yes" > /etc/ssh/sshd_config.d/01-permitrootlogin.conf

%end
