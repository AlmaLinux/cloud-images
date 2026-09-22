# AlmaLinux OS 8 kickstart file for Cloud-init included and OpenStack compatible Generic Cloud images on ppc64le

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
reqpart
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

%post --erroronfail

# The GitHub TCG build types console=hvc0 into the installer's GRUB command
# line (so anaconda's output goes to the captured serial console), and
# anaconda copies the installer's console= arguments into the installed
# boot loader configuration. Take it out again so the image's kernel
# command line is the same as from a build on a POWER host, where nothing
# is added and these two lines are no-ops.
sed -i 's/ console=hvc0//' /etc/default/grub
grubby --update-kernel=ALL --remove-args="console=hvc0"

%end
