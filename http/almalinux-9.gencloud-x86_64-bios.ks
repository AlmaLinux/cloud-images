# AlmaLinux OS 9 kickstart file for OpenStack compatible Generic Cloud (Cloud-init) images with BIOS-only boot on x86_64

url --url https://repo.almalinux.org/almalinux/9/BaseOS/x86_64/kickstart/
repo --name=BaseOS --baseurl=https://repo.almalinux.org/almalinux/9/BaseOS/x86_64/os/
repo --name=AppStream --baseurl=https://repo.almalinux.org/almalinux/9/AppStream/x86_64/os/

text
skipx
eula --agreed
firstboot --disabled
lang C.UTF-8
keyboard us
timezone UTC --utc
network --bootproto=dhcp
firewall --disabled
services --disabled="kdump" --enabled="chronyd,rsyslog,sshd"
selinux --enforcing

bootloader --timeout=0 --location=mbr --append="console=tty0 console=ttyS0,115200n8 no_timer_check net.ifnames=0"

zerombr
clearpart --all --initlabel
reqpart
part / --fstype="xfs" --size=8000

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
