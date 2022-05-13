# AlmaLinux 8 kickstart file for AWS EC2

url --url https://repo.almalinux.org/almalinux/8/BaseOS/x86_64/kickstart/
repo --name=BaseOS --baseurl=https://repo.almalinux.org/almalinux/8/BaseOS/x86_64/os/
repo --name=AppStream --baseurl=https://repo.almalinux.org/almalinux/8/AppStream/x86_64/os/

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

bootloader --append="console=ttyS0,115200n8 console=tty0 crashkernel=auto net.ifnames=0 no_timer_check nvme_core.io_timeout=4294967295 nvme_core.max_retries=10" --location=mbr --timeout=1
zerombr
clearpart --all --initlabel --disklabel=gpt
autopart --type=plain --noboot --nohome --noswap --fstype=xfs

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
# allow ec2-user to run everything without a password
echo -e 'ec2-user\tALL=(ALL)\tNOPASSWD: ALL' >> /etc/sudoers

%end
