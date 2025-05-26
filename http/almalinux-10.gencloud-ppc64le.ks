# AlmaLinux OS 10 kickstart file for Cloud-init included and OpenStack compatible Generic Cloud images on ppc64le

url --url https://repo.almalinux.org/almalinux/10/BaseOS/ppc64le/os
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
reqpart
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

%end
