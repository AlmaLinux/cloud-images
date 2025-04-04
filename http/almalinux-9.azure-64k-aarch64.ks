# AlmaLinux OS 9 kickstart file for Azure VM images with 64k page size kernel on AArch64

url --url https://repo.almalinux.org/almalinux/9/BaseOS/aarch64/os
text
lang en_US.UTF-8
keyboard us
timezone UTC --utc
selinux --enforcing
firewall --disabled
services --enabled=sshd

bootloader --timeout=0 --location=mbr --append="loglevel=3 console=tty1 console=ttyAMA0 earlycon=pl011,0xeffec000 initcall_blacklist=arm_pmu_acpi_init rootdelay=300 no_timer_check net.ifnames=0 nvme_core.io_timeout=240"

zerombr
clearpart --all --initlabel
part /boot/efi --fstype=efi --size=200
part /boot --fstype=xfs --size=1024
part / --fstype=xfs --grow

rootpw --plaintext almalinux
reboot --eject

%packages --exclude-weakdeps --inst-langs=en
kernel-64k
dracut-config-generic
tar
-kmod-kvdo
-vdo
-kernel
-*firmware
-dracut-config-rescue
-firewalld
-qemu-guest-agent
%end

# disable kdump service
%addon com_redhat_kdump --disable
%end

%post --erroronfail

# permit root login via SSH with password authetication
echo "PermitRootLogin yes" > /etc/ssh/sshd_config.d/01-permitrootlogin.conf

%end
