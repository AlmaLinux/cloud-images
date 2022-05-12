# AlmaLinux 8 kickstart file for Generic Cloud (OpenStack) ppc64le image

url --url https://repo.almalinux.org/almalinux/8/BaseOS/ppc64le/kickstart/
repo --name=BaseOS --baseurl=https://repo.almalinux.org/almalinux/8/BaseOS/ppc64le/os/
repo --name=AppStream --baseurl=https://repo.almalinux.org/almalinux/8/AppStream/ppc64le/os/

text
skipx
eula --agreed
firstboot --disabled

lang en_US.UTF-8
keyboard us
timezone UTC --isUtc

network --bootproto=dhcp
firewall --enabled --service=ssh
services --disabled="kdump" --enabled="chronyd,rsyslog,sshd"
selinux --enforcing

# TODO: remove "console=tty0" from here
bootloader --append="console=ttyS0,115200n8 console=tty0 crashkernel=auto net.ifnames=0 no_timer_check" --location=mbr --timeout=1
zerombr
clearpart --all --initlabel
reqpart
part / --fstype="xfs" --size=8000

rootpw --plaintext almalinux

reboot --eject


%packages
@core
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


%post
%end
