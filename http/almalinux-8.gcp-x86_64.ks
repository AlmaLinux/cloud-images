# AlmaLinux OS 8 kickstart file for GCP VM images on x86_64
text --non-interactive
url --url https://repo.almalinux.org/almalinux/8/BaseOS/x86_64/kickstart/
repo --name=BaseOS --baseurl=https://repo.almalinux.org/almalinux/8/BaseOS/x86_64/os/
repo --name=AppStream --baseurl=https://repo.almalinux.org/almalinux/8/AppStream/x86_64/os/

# From https://github.com/GoogleCloudPlatform/compute-image-tools/blob/master/daisy_workflows/image_build/enterprise_linux/kickstart/almalinux_8.cfg
# We need the images to match what we took over
firewall --enabled
services --disabled="kdump,sshd-keygen@" --enabled="chronyd,rsyslog,sshd"
skipx
timezone --utc UTC --ntpservers=metadata.google.internal
# we clean this up with ansible
rootpw --plaintext almalinux
firstboot --disabled
selinux --enforcing

# Network configuration
network --bootproto=dhcp --device=link

bootloader --timeout=0 --location=mbr --append="net.ifnames=0 biosdevname=0 scsi_mod.use_blk_mq=Y crashkernel=auto console=ttyS0,115200"

zerombr
clearpart --all --initlabel
part /boot/efi --fstype=efi --size=200
part / --fstype=xfs --label=root --grow

rootpw --plaintext almalinux
reboot --eject

# From https://github.com/GoogleCloudPlatform/compute-image-tools/blob/master/daisy_workflows/image_build/enterprise_linux/kickstart/almalinux_8.cfg
# We need the images to match what we took over
# packages.cfg
# Contains a list of packages to be installed, or not, on all flavors.
# The %package command begins the package selection section of kickstart.
# Packages can be specified by group, or package name. @Base and @Core are
# always selected by default so they do not need to be specified.
%packages
acpid
dhcp-client
dnf-automatic
grub2-tools-efi
net-tools
openssh-server
python3
rng-tools
tar
vim
-subscription-manager
-alsa-utils
-b43-fwcutter
-dmraid
-eject
-gpm
-irqbalance
-microcode_ctl
-smartmontools
-aic94xx-firmware
-atmel-firmware
-b43-openfwwf
-bfa-firmware
-ipw2100-firmware
-ipw2200-firmware
-ivtv-firmware
-iwl*-firmware
-kernel-firmware
-libertas-usb8388-firmware
-ql2100-firmware
-ql2200-firmware
-ql23xx-firmware
-ql2400-firmware
-ql2500-firmware
-rt61pci-firmware
-rt73usb-firmware
-xorg-x11-drv-ati-firmware
-zd1211-firmware
%end

# disable kdump service
%addon com_redhat_kdump --disable
%end

%post
tee -a /etc/yum.repos.d/google-cloud.repo << EOM
[google-compute-engine]
name=Google Compute Engine
baseurl=https://packages.cloud.google.com/yum/repos/google-compute-engine-el8-x86_64-stable
enabled=1
gpgcheck=1
repo_gpgcheck=0
gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg
       https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
EOM
tee -a /etc/yum.repos.d/google-cloud.repo << EOM
[google-cloud-sdk]
name=Google Cloud SDK
baseurl=https://packages.cloud.google.com/yum/repos/cloud-sdk-el8-x86_64
enabled=1
gpgcheck=1
repo_gpgcheck=0
gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg
       https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
EOM
%end

%onerror
echo "Build Failed!" > /dev/ttyS0
shutdown -h now
%end

%post --erroronfail
set -x
exec &> /dev/ttyS0

# Import all RPM GPG keys.
curl -o /etc/pki/rpm-gpg/google-rpm-package-key.gpg https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
curl -o /etc/pki/rpm-gpg/google-key.gpg https://packages.cloud.google.com/yum/doc/yum-key.gpg
rpm --import /etc/pki/rpm-gpg/*

# Configure the network for GCE.
# Given that GCE users typically control the firewall at the network API level,
# we want to leave the standard Linux firewall setup enabled but all-open.
firewall-offline-cmd --set-default-zone=trusted

cat >>/etc/dhcp/dhclient.conf <<EOL
# Set the dhclient retry interval to 10 seconds instead of 5 minutes.
retry 10;
EOL

# Set google-compute-engine config for EL8.
cat >>/etc/default/instance_configs.cfg.distro << EOL
# Disable boto plugin setup.
[InstanceSetup]
set_boto_config = false
EOL

# Install the Cloud SDK package.
dnf install -y google-cloud-cli

# Remove files which shouldn't make it into the image. Its possible these files
# will not exist.
rm -f /etc/boto.cfg /etc/udev/rules.d/70-persistent-net.rules

# Remove eth0 config from installer.
rm -f /etc/sysconfig/network-scripts/ifcfg-eth0

# Set ServerAliveInterval and ClientAliveInterval to prevent SSH
# disconnections. The pattern match is tuned to each source config file.
# The $'...' quoting syntax tells the shell to expand escape characters.
sed -i -e $'/^\tServerAliveInterval/d' /etc/ssh/ssh_config
sed -i -e $'/^Host \\*$/a \\\tServerAliveInterval 420' /etc/ssh/ssh_config
sed -i -e '/ClientAliveInterval/s/^.*/ClientAliveInterval 420/' /etc/ssh/sshd_config

# Make changes to dnf automatic.conf
# Apply updates for security (RHEL) by default. NOTE this will not work in CentOS.
sed -i 's/upgrade_type =.*/upgrade_type = security/' /etc/dnf/automatic.conf
sed -i 's/apply_updates =.*/apply_updates = yes/' /etc/dnf/automatic.conf
# Enable the DNF automatic timer service.
systemctl enable dnf-automatic.timer

# Cleanup this repo- we don't want to continue updating with it.
# Depending which repos are used in build, one or more of these files will not
# exist.
rm -f /etc/yum.repos.d/google-cloud-unstable.repo \
  /etc/yum.repos.d/google-cloud-staging.repo

# Blacklist unnecessary modules
cat <<EOF > /etc/modprobe.d/blacklist.conf
blacklist floppy
blacklist nouveau
blacklist lbm-nouveau
EOF
restorecon /etc/modprobe.d/blacklist.conf

# Generate initramfs from latest kernel instead of the running kernel.
kver="$(ls -t /lib/modules | head -n1)"
dracut -f --kver="${kver}"

# Fix selinux contexts on /etc/resolv.conf.
restorecon /etc/resolv.conf
%end

# Cleanup.
%post --nochroot --log=/dev/ttyS0
set -x
rm -Rf /mnt/sysimage/tmp/*
%end
