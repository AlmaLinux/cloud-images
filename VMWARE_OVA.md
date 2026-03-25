# VMware vSphere/ESXi OVA Conversion

## Overview

While the CI/CD pipeline publishes Vagrant `.box` artifacts for VMware Desktop, these are essentially compressed VMware Workstation-style VMs. They can be converted into `.ova` templates compatible with **vSphere/ESXi** using VMware's official `ovftool`.

This document provides a complete, step-by-step guide on how to perform this conversion on an **AlmaLinux 9** or **AlmaLinux 10** system using the [`tools/box2ova.sh`](tools/box2ova.sh) script.

## Prerequisites

| Tool | Description |
|------|-------------|
| `ovftool` | VMware OVF Tool (the script can install it automatically from a `.zip`) |
| `qemu-img` | QEMU disk image utility (from `qemu-img` package) |
| `libguestfs` / `virt-customize` | Tools for modifying virtual disk images |
| `tar`, `unzip` | Standard archive utilities |

## Step 1: Download `ovftool`

Download the Linux `.zip` version of the OVF Tool from the Broadcom Developer Portal:

https://developer.broadcom.com/tools/open-virtualization-format-ovf-tool/latest

Place the downloaded `.zip` file in your working directory. The conversion script will detect and install it automatically if `ovftool` is not already in your `$PATH`.

## Step 2: Download the Vagrant `.box` File

Download the specific Vagrant VMware box version you need from Vagrant Cloud:

https://portal.cloud.hashicorp.com/vagrant/discover/almalinux

> **Note:** Vagrant Cloud may serve box files as raw UUIDs without file extensions when downloaded via API or direct links (e.g., `f5952274-22f3-11f1-9947-be8f8dec9788`). This is normal — the file is still a valid `.box` (gzip-compressed tar archive).

## Step 3: Run the Conversion

The conversion script is located at [`tools/box2ova.sh`](tools/box2ova.sh). Run it against the downloaded box file:

```bash
./tools/box2ova.sh f5952274-22f3-11f1-9947-be8f8dec9788
```

or if you renamed the file:

```bash
./tools/box2ova.sh AlmaLinux-9-Vagrant-vmware-9.6-20250522.0.x86_64.box
```

The script will:

1. **Install dependencies** — `libguestfs`, `qemu-img`, and `unzip` via `dnf` (adds `libxcrypt-compat` on EL10)
2. **Auto-install `ovftool`** — if not in `$PATH`, looks for a `VMware-ovftool-*-lin.x86_64.zip` in the current directory
3. **Extract the `.box`** archive into a temporary directory
4. **Derive the OVA name** from the VMX `displayname`, stripping "Vagrant" suffixes
5. **Re-enable cloud-init networking** — removes `network: {config: disabled}` from `99_vagrant.cfg` inside the disk image (see [Cloud-init Note](#cloud-init-note) below)
6. **Convert to OVA** — using `ovftool` with the specified hardware version

The resulting `.ova` file is written to the current directory.

### Cloud-init Note

AlmaLinux Vagrant boxes ship with `network: {config: disabled}` in `/etc/cloud/cloud.cfg.d/99_vagrant.cfg` to prevent cloud-init from managing network interfaces in Vagrant environments (VirtualBox, VMware Workstation, libvirt) where networking is handled by the hypervisor and Vagrant itself.

When deploying to **vSphere/ESXi**, cloud-init networking should be **re-enabled** so that the VM can obtain its network configuration from the vSphere datasource (via VMware Tools). The script handles this automatically by removing the `network: {config: disabled}` line from the disk image.

### Hardware Version

The script defaults to hardware version **20** (`vmx-20`), which corresponds to **ESXi 8.0 Update 1**. You can override this via the `HW_VERSION` environment variable:

```bash
HW_VERSION=19 ./tools/box2ova.sh my-box-file.box
```

| HW Version | ESXi Compatibility |
|:----------:|:-------------------|
| 19 | ESXi 7.0 U2+ |
| 20 | ESXi 8.0 U1+ |
| 21 | ESXi 8.0 U2+ |

## Step 4: Deploy to vSphere/vCloud

Once the `.ova` is generated, deploy it to your cluster:

1. Log into your **vSphere Client** or **vCloud** Web GUI
2. Right-click your target Host or Cluster and select _Deploy OVF Template..._
3. Select **Local file**, upload your new `.ova`, and follow the prompts to configure networking and storage

## Support

- Broadcom OVF Tool: https://developer.broadcom.com/tools/open-virtualization-format-ovf-tool/latest
- AlmaLinux Cloud SIG Chat: https://chat.almalinux.org/almalinux/channels/sigcloud
- AlmaLinux Vagrant boxes: https://portal.cloud.hashicorp.com/vagrant/discover/almalinux
