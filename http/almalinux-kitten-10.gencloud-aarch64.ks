# AlmaLinux OS Kitten 10 kickstart file for Cloud-init included and OpenStack compatible Generic Cloud images on AArch64

url --url https://kitten.repo.almalinux.org/10-kitten/BaseOS/aarch64/os
text
lang en_US.UTF-8
keyboard us
timezone UTC --utc
selinux --enforcing
firewall --disabled
services --enabled=sshd

bootloader --timeout=0 --location=mbr --append="console=tty0 console=ttyS0,115200n8 no_timer_check net.ifnames=0"

zerombr
clearpart --all --initlabel
part /boot/efi --fstype=efi --size=200
part /boot --fstype=xfs --size=1024
part / --fstype=xfs --grow

rootpw --plaintext almalinux
reboot --eject

%packages --exclude-weakdeps --inst-langs=en
dracut-config-generic
tar
-*firmware
-dracut-config-rescue
-firewalld
%end

# disable kdump service
%addon com_redhat_kdump --disable
%end

%post --erroronfail

# permit root login via SSH with password authetication
echo "PermitRootLogin yes" > /etc/ssh/sshd_config.d/01-permitrootlogin.conf

# To fix the OpenSSH version 9.9p1-16.el10 issue:
# ssh: unexpected packet in response to channel open: <nil>
dnf -y reinstall openssh-server

%end
