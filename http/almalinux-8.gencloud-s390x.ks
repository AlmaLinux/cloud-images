# AlmaLinux OS 8 kickstart file for Cloud-init included and OpenStack compatible Generic Cloud images on s390x

# Based on:
# - https://gitlab.com/redhat/centos-stream/release-engineering/kickstarts
# - https://kojihub.stream.centos.org/koji/packageinfo?packageID=3438


url --url https://repo.almalinux.org/almalinux/8/BaseOS/s390x/kickstart/
repo --name=BaseOS --baseurl=https://repo.almalinux.org/almalinux/8/BaseOS/s390x/os/
repo --name=AppStream --baseurl=https://repo.almalinux.org/almalinux/8/AppStream/s390x/os/

text
skipx
eula --agreed
firstboot --disabled

lang C.UTF-8
keyboard us
timezone UTC --utc

# add console and reorder in %post
bootloader --timeout=0 --location=mbr --append="console=tty0 console=ttyS0,115200n8 no_timer_check biosdevname=0 net.ifnames=0"

auth --enableshadow --passalgo=sha512
#authselect select sssd
selinux --enforcing
firewall --disabled
network --bootproto=dhcp --device=link --activate --onboot=on
#services --enabled=sshd,ovirt-guest-agent --disabled kdump,rhsmcertd
services --enabled=sshd,NetworkManager,cloud-init,cloud-init-local,cloud-config,cloud-final --disabled kdump,rhsmcertd
rootpw --iscrypted nope

zerombr
clearpart --all --initlabel
reqpart
part /boot --fstype=xfs --size=1024
part / --fstype=xfs --grow

reboot --eject


# Packages
%packages
@core
dnf
kernel
yum
nfs-utils
dnf-utils
hostname

# pull firmware packages out
-aic94xx-firmware
-alsa-firmware
-alsa-lib
-alsa-tools-firmware
-ivtv-firmware
-iwl1000-firmware
-iwl100-firmware
-iwl105-firmware
-iwl135-firmware
-iwl2000-firmware
-iwl2030-firmware
-iwl3160-firmware
-iwl3945-firmware
-iwl4965-firmware
-iwl5000-firmware
-iwl5150-firmware
-iwl6000-firmware
-iwl6000g2a-firmware
-iwl6000g2b-firmware
-iwl6050-firmware
-iwl7260-firmware
-libertas-sd8686-firmware
-libertas-sd8787-firmware
-libertas-usb8388-firmware

# cloud-init does magical things with EC2 metadata, including provisioning
# a user account with ssh keys.
cloud-init
## Adding a dependency for cloud-init as recommended by tdawson
python3-jsonschema

# rhevm guest-agent (Not available in CentOS-Stream-9 yet)
#rhevm-guest-agent-common

# allows the host machine to issue commands to the guest operating system
qemu-guest-agent

# need this for growpart, because parted doesn't yet support resizepart
# https://bugzilla.redhat.com/show_bug.cgi?id=966993
#cloud-utils

#heat-cfntools  # Not available in CentOS-Stream-9 (yet?)

cloud-utils-growpart
# We need this image to be portable; also, rescue mode isn't useful here.
dracut-config-generic

# Don't include dracut-config-rescue. It will have dracut generate a
# "rescue" entry in the grub menu, but that also means there is a
# rescue kernel and initramfs that get created, which (currently) add
# about another 40MiB to the /boot/ partition. Also the "rescue" mode
# is generally not useful in the cloud.
-dracut-config-rescue

# Needed initially, but removed below.
firewalld

# cherry-pick a few things from @base
tar
tcpdump
rsync

# Some things from @core we can do without in a minimal install
-biosdevname
-plymouth
-iprutils

# Minimal Cockpit web console
cockpit-ws
cockpit-system
#subscription-manager-cockpit

# rh-amazon-rhui-client

# Exclude all langpacks for now
# TODO: Do not exclude langpacks because of:
# fontconfig-2.13.92-12.el9.s390x requires font(:lang=en)
-langpacks-*

# The langpacks-en package is pulled in by Anaconda and it seems filtering
# it out using langpacks-* is not sufficient. It needs to be filtered
# directly.
-langpacks-en

%end


# disable kdump service
%addon com_redhat_kdump --disable
%end

#
# Add custom post scripts after the base post.
#
%post --erroronfail

# workaround anaconda requirements
passwd -d root
passwd -l root

# setup systemd to boot to the right runlevel
echo -n "Setting default runlevel to multiuser text mode"
rm -f /etc/systemd/system/default.target
ln -s /lib/systemd/system/multi-user.target /etc/systemd/system/default.target
echo .

# this is installed by default but we don't need it in virt
echo "Removing linux-firmware package."
dnf -C -y remove linux-firmware

# Remove firewalld; it is required to be present for install/image building.
echo "Removing firewalld."
dnf -C -y remove firewalld --setopt="clean_requirements_on_remove=1"

echo -n "Getty fixes"
# although we want console output going to the serial console, we don't
# actually have the opportunity to login there. FIX.
# we don't really need to auto-spawn _any_ gettys.
sed -i '/^#NAutoVTs=.*/ a\
NAutoVTs=0' /etc/systemd/logind.conf

echo -n "Network fixes"
# initscripts don't like this file to be missing.
cat > /etc/sysconfig/network << EOF
NETWORKING=yes
NOZEROCONF=yes
EOF

# For cloud images, 'eth0' _is_ the predictable device name, since
# we don't want to be tied to specific virtual (!) hardware
rm -f /etc/udev/rules.d/70*
ln -s /dev/null /etc/udev/rules.d/80-net-name-slot.rules
rm -f /etc/sysconfig/network-scripts/ifcfg-*
# simple eth0 config, again not hard-coded to the build hardware
cat > /etc/sysconfig/network-scripts/ifcfg-eth0 << EOF
DEVICE="eth0"
BOOTPROTO="dhcp"
BOOTPROTOv6="dhcp"
ONBOOT="yes"
TYPE="Ethernet"
USERCTL="yes"
PEERDNS="yes"
IPV6INIT="yes"
PERSISTENT_DHCLIENT="1"
EOF

# set virtual-guest as default profile for tuned
echo "virtual-guest" > /etc/tuned/active_profile

# generic localhost names
cat > /etc/hosts << EOF
127.0.0.1   localhost localhost.localdomain localhost4 localhost4.localdomain4
::1         localhost localhost.localdomain localhost6 localhost6.localdomain6

EOF
echo .

cat <<EOL > /etc/sysconfig/kernel
# UPDATEDEFAULT specifies if new-kernel-pkg should make
# new kernels the default
UPDATEDEFAULT=yes

# DEFAULTKERNEL specifies the default kernel package type
DEFAULTKERNEL=kernel
EOL

# make sure firstboot doesn't start
echo "RUN_FIRSTBOOT=NO" > /etc/sysconfig/firstboot

# workaround https://bugzilla.redhat.com/show_bug.cgi?id=966888
if ! grep -q growpart /etc/cloud/cloud.cfg; then
  sed -i 's/ - resizefs/ - growpart\n - resizefs/' /etc/cloud/cloud.cfg
fi

# Set almalinux as Cloud-init Cloud User
sed -Ei 's/(\s+name:).*/\1 almalinux/' /etc/cloud/cloud.cfg

# Disable subscription-manager yum plugins
sed -i 's|^enabled=1|enabled=0|' /etc/yum/pluginconf.d/product-id.conf
sed -i 's|^enabled=1|enabled=0|' /etc/yum/pluginconf.d/subscription-manager.conf

echo "Cleaning old yum repodata."
dnf clean all

# clean up installation logs"
rm -rf /var/log/yum.log
rm -rf /var/lib/yum/*
rm -rf /var/lib/dnf/history*
rm -rf /root/install.log
rm -rf /root/install.log.syslog
rm -rf /root/anaconda-ks.cfg
rm -rf /root/original-ks.cfg
rm -rf /var/log/anaconda*

echo "Fixing SELinux contexts."
touch /var/log/cron
touch /var/log/boot.log
mkdir -p /var/cache/yum
/usr/sbin/fixfiles -R -a restore

# remove random-seed so it's not the same every time
rm -f /var/lib/systemd/random-seed

# remove /etc/machine-info
rm -f /etc/machine-info

# remove credential.secret
rm -f /var/lib/systemd/credential.secret

# Remove machine-id on the pre generated images
cat /dev/null > /etc/machine-id

# Anaconda is writing to /etc/resolv.conf from the generating environment.
# The system should start out with an empty file.
truncate -s 0 /etc/resolv.conf

%end
