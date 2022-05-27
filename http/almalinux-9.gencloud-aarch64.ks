# AlmaLinux 9 kickstart file for Generic Cloud (OpenStack) aarch64 image

url --url https://repo.almalinux.org/almalinux/9/BaseOS/aarch64/kickstart/
repo --name=BaseOS --baseurl=https://repo.almalinux.org/almalinux/9/BaseOS/aarch64/os/
repo --name=AppStream --baseurl=https://repo.almalinux.org/almalinux/9/AppStream/aarch64/os/

text
skipx
eula --agreed
firstboot --disabled

lang C.UTF-8
keyboard us
timezone UTC --utc

network --bootproto=dhcp
firewall --enabled --service=ssh
services --disabled="kdump" --enabled="chronyd,rsyslog,sshd"
selinux --enforcing

bootloader --timeout=1 --location=mbr --append="console=tty0 console=ttyS0,115200n8 no_timer_check crashkernel=auto net.ifnames=0"

zerombr
clearpart --all --initlabel
part /boot/efi --size=200 --fstype=efi
part /boot --size=500 --fstype=xfs
part / --size=8000 --fstype=xfs

rootpw --plaintext almalinux

reboot --eject


%packages --inst-langs=en
@core
dracut-config-generic
usermode
-biosdevname
-dnf-plugin-spacewalk
-dracut-config-rescue
-iprutils
-iwl*-firmware
-langpacks-*
-mdadm
-open-vm-tools
-plymouth
-rhn*
%end


# disable kdump service
%addon com_redhat_kdump --disable
%end

%post --erroronfail

# permit root login via SSH with password authetication
echo "PermitRootLogin yes" > /etc/ssh/sshd_config.d/01-permitrootlogin.conf

%end
