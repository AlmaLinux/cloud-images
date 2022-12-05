# AlmaLinux 8 kickstart file with Vagrant support

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
services --enabled=sshd
selinux --enforcing

bootloader --location=mbr
zerombr
clearpart --all --initlabel
autopart --type=plain --nohome --noboot --noswap

rootpw vagrant
user --name=vagrant --plaintext --password vagrant

reboot --eject


%packages --ignoremissing --excludedocs --instLangs=en_US.UTF-8
bzip2
tar
-microcode_ctl
-iwl*-firmware
%end


# disable kdump service
%addon com_redhat_kdump --disable
%end


%post
# allow vagrant user to run everything without a password
echo "vagrant     ALL=(ALL)     NOPASSWD: ALL" >> /etc/sudoers.d/vagrant

# see Vagrant documentation (https://docs.vagrantup.com/v2/boxes/base.html)
# for details about the requiretty.
sed -i "s/^.*requiretty/# Defaults requiretty/" /etc/sudoers
yum clean all
%end
