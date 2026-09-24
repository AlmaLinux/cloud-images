# AlmaLinux OS 8 kickstart file for Cloud-init included and OpenStack compatible Generic Cloud images on AArch64

url --url https://repo.almalinux.org/almalinux/8/BaseOS/aarch64/kickstart/
repo --name=BaseOS --baseurl=https://repo.almalinux.org/almalinux/8/BaseOS/aarch64/os/
repo --name=AppStream --baseurl=https://repo.almalinux.org/almalinux/8/AppStream/aarch64/os/

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
part /boot/efi --fstype=efi --size=200
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

# The TCG build on a GitHub-hosted x86_64 runner types console=ttyAMA0 into
# the installer's GRUB command line (so anaconda's output goes to the
# captured serial console), and anaconda copies the installer's console=
# arguments into the installed boot loader configuration. Take it out again
# so the image's kernel command line is the same as from an arm64 host, where
# nothing is added and these two lines are no-ops.
sed -i 's/ console=ttyAMA0//' /etc/default/grub
grubby --update-kernel=ALL --remove-args="console=ttyAMA0"
# The serial console= argument also makes anaconda switch GRUB to a serial
# terminal in /etc/default/grub (GRUB_TERMINAL="serial console" plus
# GRUB_SERIAL_COMMAND); put back the default an arm64-host build gets, so a
# later grub2-mkconfig does not pick it up. No-op on the arm64 host.
if grep -q '^GRUB_SERIAL_COMMAND=' /etc/default/grub; then
  sed -i -e '/^GRUB_SERIAL_COMMAND=/d' \
    -e 's/^GRUB_TERMINAL="serial console"$/GRUB_TERMINAL_OUTPUT="console"/' /etc/default/grub
fi
# anaconda generated grub.cfg before this ran, with the serial terminal and
# console=ttyAMA0 in its fallback kernelopts: regenerate it from the cleaned
# defaults. (EL9+ keeps the real file in /boot/grub2, the one on the ESP is a
# stub that loads it; EL8 keeps the real one on the ESP.)
cfg=/boot/grub2/grub.cfg
efi_cfg=/boot/efi/EFI/almalinux/grub.cfg
[ -f "${efi_cfg}" ] && ! grep -q configfile "${efi_cfg}" && cfg=${efi_cfg}
if grep -qE ' console=ttyAMA0|terminal_output serial' "${cfg}" 2>/dev/null; then
  grub2-mkconfig -o "${cfg}"
fi

%end
