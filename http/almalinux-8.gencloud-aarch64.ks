# AlmaLinux OS 8 kickstart file for Cloud-init included and OpenStack compatible Generic Cloud images on AArch64

url --url https://repo.almalinux.org/almalinux/8/BaseOS/aarch64/kickstart/
repo --name=BaseOS --baseurl=https://repo.almalinux.org/almalinux/8/BaseOS/aarch64/os/
repo --name=AppStream --baseurl=https://repo.almalinux.org/almalinux/8/AppStream/aarch64/os/

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

bootloader --timeout=0 --location=mbr --append="console=tty0 console=ttyS0,115200n8 no_timer_check net.ifnames=0"

%pre --erroronfail
fstype=xfs
for param in $(cat /proc/cmdline); do
  case $param in
    fstype=*) fstype=${param#fstype=} ;;
  esac
done

cat > /tmp/partitions.ks <<EOF
zerombr
clearpart --all --initlabel
part /boot/efi --fstype=efi --size=200
part /boot --fstype=$fstype --size=1024
part / --fstype=$fstype --grow
EOF
%end

%include /tmp/partitions.ks

rootpw --plaintext almalinux
reboot --eject

%packages
@core
pciutils
tar
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
