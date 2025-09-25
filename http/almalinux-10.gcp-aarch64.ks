# AlmaLinux OS 10 kickstart file for GCP VM images on x86_64

url --url https://repo.almalinux.org/almalinux/10/BaseOS/aarch64/os
text
lang en_US.UTF-8
keyboard us
timezone UTC --utc
selinux --enforcing
firewall --disabled
services --enabled=sshd

bootloader --timeout=0 --append="biosdevname=0"

zerombr
clearpart --all --initlabel
part /boot/efi --fstype=efi --size=200
part / --fstype=xfs --label=root --grow

rootpw --plaintext almalinux
reboot --eject

%packages --exclude-weakdeps --inst-langs=en
dracut-config-generic
tar
dnf-automatic
-*firmware
-dracut-config-rescue
-firewalld
-qemu-guest-agent
%end

# disable kdump service
%addon com_redhat_kdump --disable
%end

%post
tee -a /etc/yum.repos.d/google-cloud.repo << EOM
[google-compute-engine]
name=Google Compute Engine
baseurl=https://packages.cloud.google.com/yum/repos/google-compute-engine-el10-aarch64-stable
enabled=1
gpgcheck=1
repo_gpgcheck=0
gpgkey=https://packages.cloud.google.com/yum/doc/rpm-package-key-v10.gpg
EOM
tee -a /etc/yum.repos.d/google-cloud.repo << EOM
[google-cloud-sdk]
name=Google Cloud SDK
baseurl=https://packages.cloud.google.com/yum/repos/cloud-sdk-el10-aarch64
enabled=1
gpgcheck=1
repo_gpgcheck=0
gpgkey=https://packages.cloud.google.com/yum/doc/rpm-package-key-v10.gpg
EOM
%end

%post --erroronfail

# permit root login via SSH with password authetication
echo "PermitRootLogin yes" > /etc/ssh/sshd_config.d/01-permitrootlogin.conf

# Import all RPM GPG keys.
curl -o /etc/pki/rpm-gpg/rpm-package-key-v10.gpg https://packages.cloud.google.com/yum/doc/rpm-package-key-v10.gpg
rpm --import /etc/pki/rpm-gpg/rpm-package-key-v10.gpg

# Set google-compute-engine config for EL10.
cat >>/etc/default/instance_configs.cfg.distro << EOL
# Disable boto plugin setup.
[InstanceSetup]
set_boto_config = false
EOL

# Make changes to dnf automatic.conf
# Apply updates for security (RHEL) by default. NOTE this will not work in CentOS.
sed -i'' 's/upgrade_type =.*/upgrade_type = security/' /etc/dnf/automatic.conf
sed -i'' 's/apply_updates =.*/apply_updates = yes/' /etc/dnf/automatic.conf
# Enable the DNF automatic timer service.
systemctl enable dnf-automatic.timer

# Blacklist the floppy module.
echo "blacklist floppy" > /etc/modprobe.d/blacklist-floppy.conf
restorecon /etc/modprobe.d/blacklist-floppy.conf

%end
