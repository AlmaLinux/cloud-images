# AlmaLinux OS 8 kickstart file for Oracle Cloud Infrastructure (OCI) images on AArch64

url --url https://repo.almalinux.org/almalinux/8/BaseOS/aarch64/os

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

bootloader --timeout=0 --location=mbr --append="console=ttyAMA0 console=ttyAMA0,115200n8 no_timer_check net.ifnames=0 netroot=iscsi:169.254.0.2:::1:iqn.2015-02.oracle.boot:uefi rd.iscsi.param=node.session.timeo.replacement_timeout=6000 libiscsi.debug_libiscsi_eh=1 nvme_core.shutdown_timeout=10"

zerombr
clearpart --all --initlabel
part /boot/efi --fstype=efi --size=200
part /boot --fstype=xfs --size=1024
part / --fstype=xfs --grow

rootpw --plaintext almalinux
reboot --eject

%packages
@core
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
