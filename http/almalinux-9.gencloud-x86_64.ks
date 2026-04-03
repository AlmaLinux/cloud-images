# AlmaLinux OS 9 kickstart file for Cloud-init included and OpenStack compatible Generic Cloud images with unified (BIOS+UEFI) boot on x86_64

url --url https://repo.almalinux.org/almalinux/9/BaseOS/x86_64/os
text
lang en_US.UTF-8
keyboard us
timezone UTC --utc
selinux --enforcing
firewall --disabled
services --enabled=sshd

bootloader --timeout=0 --location=mbr --append="console=tty0 console=ttyS0,115200n8 no_timer_check net.ifnames=0"

%pre --erroronfail
fstype=xfs
for param in $(cat /proc/cmdline); do
  case $param in
    fstype=*) fstype=${param#fstype=} ;;
  esac
done

parted -s -a optimal /dev/sda -- mklabel gpt
parted -s -a optimal /dev/sda -- mkpart biosboot 1MiB 2MiB set 1 bios_grub on
parted -s -a optimal /dev/sda -- mkpart '"EFI System Partition"' fat32 2MiB 202MiB set 2 esp on
parted -s -a optimal /dev/sda -- mkpart boot $fstype 202MiB 1226MiB
parted -s -a optimal /dev/sda -- mkpart root $fstype 1226MiB 100%

cat > /tmp/partitions.ks <<EOF
part biosboot --fstype=biosboot --onpart=sda1
part /boot/efi --fstype=efi --onpart=sda2
part /boot --fstype=$fstype --onpart=sda3
part / --fstype=$fstype --onpart=sda4
EOF
%end

%include /tmp/partitions.ks

rootpw --plaintext almalinux
reboot --eject

%packages --exclude-weakdeps --inst-langs=en
dracut-config-generic
grub2-pc
pciutils
tar
rsyslog-logrotate
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

# permit root login via SSH with password authetication
echo "PermitRootLogin yes" > /etc/ssh/sshd_config.d/01-permitrootlogin.conf

%end
