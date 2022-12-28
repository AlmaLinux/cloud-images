# AlmaLinux 8 kickstart file for Azure x86-64 image
# Special thanks to CentOS Cloud SIG for the partitioning example:
#   https://github.com/CentOS/sig-cloud-instance-build/blob/master/cloudimg/CentOS-8-x86_64-Azure.ks

url --url https://repo.almalinux.org/almalinux/8/BaseOS/x86_64/kickstart/
repo --name=BaseOS --baseurl=https://repo.almalinux.org/almalinux/8/BaseOS/x86_64/os/
repo --name=AppStream --baseurl=https://repo.almalinux.org/almalinux/8/AppStream/x86_64/os/

text
skipx
eula --agreed
firstboot --disabled

lang en_US.UTF-8
keyboard us
timezone UTC

network --bootproto=dhcp
firewall --disabled
services --disabled="kdump" --enabled="chronyd,rsyslog,sshd"
selinux --enforcing

bootloader --append="console=tty1 console=ttyS0,115200n8 earlyprintk=ttyS0,115200 rootdelay=300 net.ifnames=0" --location=mbr --timeout=1
zerombr
bootloader --location=mbr --timeout=1
part /boot/efi --onpart=sda15 --fstype=vfat
part /boot --fstype="xfs" --size=1000
part / --fstype="xfs" --size=1 --grow --asprimary

#clearpart --all --initlabel --disklabel=gpt
#autopart --type=plain --noboot --nohome --noswap --fstype=xfs

rootpw --plaintext almalinux

reboot --eject


%packages
@core
@standard
grub2-pc

-biosdevname
-open-vm-tools
-plymouth
-dnf-plugin-spacewalk
-rhn*
-iprutils
-iwl*-firmware
%end


%pre --log=/var/log/anaconda/pre-install.log --erroronfail
#!/bin/bash

# Pre-create the biosboot and EFI partitions
#  - Ensure that efi and biosboot are created at the start of the disk to
#    allow resizing of the OS disk.
#  - Label biosboot and efi as sda14/sda15 for better compat - some tools
#    may assume that sda1/sda2 are '/boot' and '/' respectively.
sgdisk --clear /dev/sda
sgdisk --new=14:2048:10239 /dev/sda
sgdisk --new=15:10240:500M /dev/sda
sgdisk --typecode=14:EF02 /dev/sda
sgdisk --typecode=15:EF00 /dev/sda

%end


# disable kdump service
%addon com_redhat_kdump --disable
%end


%post --log=/var/log/anaconda/post-install.log --erroronfail
echo 'GRUB_TERMINAL="serial console"' >> /etc/default/grub
echo 'GRUB_SERIAL_COMMAND="serial --speed=115200 --unit=0 --word=8 --parity=no --stop=1"' >> /etc/default/grub

# Enable BIOS bootloader
grub2-mkconfig --output /etc/grub2-efi.cfg
grub2-install --target=i386-pc --directory=/usr/lib/grub/i386-pc/ /dev/sda
grub2-mkconfig --output=/boot/grub2/grub.cfg
ln -sf /boot/grub2/grub.cfg /etc/grub2.cfg

 # Fix grub.cfg to remove EFI entries, otherwise "boot=" is not set correctly and blscfg fails
 EFI_ID=$(blkid --match-tag UUID --output value /dev/sda15)
 BOOT_ID=$(blkid --match-tag UUID --output value /dev/sda1)
 sed -i 's/gpt15/gpt1/' /boot/grub2/grub.cfg
 sed -i "s/${EFI_ID}/${BOOT_ID}/" /boot/grub2/grub.cfg
 sed -i 's|${config_directory}/grubenv|(hd0,gpt15)/efi/almalinux/grubenv|' /boot/grub2/grub.cfg
 sed -i '/^### BEGIN \/etc\/grub.d\/30_uefi/,/^### END \/etc\/grub.d\/30_uefi/{/^### BEGIN \/etc\/grub.d\/30_uefi/!{/^### END \/etc\/grub.d\/30_uefi/!d}}' /boot/grub2/grub.cfg
%end
