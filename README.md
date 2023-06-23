# AlmaLinux OS Cloud Images

AlmaLinux OS Cloud Images is a project that contains
[Packer](https://www.packer.io/) templates and other tools for building
AlmaLinux OS images for various cloud platforms.


## Available Official Images

| Name | Architecture | Download URL |
| :---: | :---: | :---: |
| Generic Cloud (OpenStack) | `x86_64` `AArch64` `ppc64le` `s390x` | https://wiki.almalinux.org/cloud/Generic-cloud.html |
| Azure Community Gallery | `x86_64` `AArch64` | https://wiki.almalinux.org/cloud/Azure.html |
| Azure Marketplace | `x86_64` `AArch64` | https://wiki.almalinux.org/cloud/Azure.html |
| AWS Community AMI | `x86_64` `AArch64` | https://wiki.almalinux.org/cloud/AWS.html |
| AWS Marketplace AMI | `x86_64` `AArch64` | https://aws.amazon.com/marketplace/seller-profile?id=529d1014-352c-4bed-8b63-6120e4bd3342 |
| Docker Hub | `x86_64` `AArch64` `ppc64le` `s390x` | https://wiki.almalinux.org/containers/docker-images.html |
| Quay.io | `x86_64` `AArch64` `ppc64le` `s390x` | https://quay.io/organization/almalinuxorg |
| LXC/LXD | `x86_64` `AArch64` `ppc64le` | https://images.linuxcontainers.org |
| Google Cloud | `x86_64` | https://wiki.almalinux.org/cloud/Google.html |
| Oracle Cloud Infrastructure | `x86_64` `AArch64` | https://wiki.almalinux.org/cloud/OCI.html |
| OpenNebula | `x86_64` `AArch64` | https://wiki.almalinux.org/cloud/OpenNebula.html |
| Vagrant | `virtualbox`(`x86_64`), `libvirt`(`x86_64`, `x86_64 UEFI`), `vmware_desktop`(`x86_64`), `hyperv`(`x86_64`), `parallels`(`x86_64, AArch64`) | https://app.vagrantup.com/almalinux |


## Usage

Install or Update installed Packer plugins:

```sh
packer init -upgrade .
```


### Generic Cloud (OpenStack compatible) images


#### AlmaLinux OS 8

`x86_64` BIOS only (Default):

```sh
packer build -only=qemu.almalinux-8-gencloud-x86_64 .
```

`x86_64` UEFI only:

See: [How to build UEFI and Secure Boot supported Images](https://github.com/AlmaLinux/cloud-images#how-to-build-uefi-and-secure-boot-supported-images)

```sh
packer build -only=qemu.almalinux-8-gencloud-uefi-x86_64 .
```

`AArch64`:

```sh
packer build -only=qemu.almalinux-8-gencloud-aarch64 .
```

`ppc64le`:

```sh
packer build -only=qemu.almalinux-8-gencloud-ppc64le .
```


#### AlmaLinux OS 9

`x86_64` BIOS+UEFI (Default):

See: [How to build UEFI and Secure Boot supported Images](https://github.com/AlmaLinux/cloud-images#how-to-build-uefi-and-secure-boot-supported-images)

```sh
packer build -only=qemu.almalinux-9-gencloud-x86_64 .
```

`x86_64` BIOS only:

```sh
packer build -only=qemu.almalinux-9-gencloud-bios-x86_64 .
```

`AArch64`:

```sh
packer build -only=qemu.almalinux-9-gencloud-aarch64 .
```

`ppc64le`:

```sh
packer build -only=qemu.almalinux-9-gencloud-ppc64le .
```


### Azure VM Images

Both AlmaLinux OS 8 and 9 cloud images supports Generation 1 and Generation 2 VMs.


#### AlmaLinux OS 8

See: [How to build UEFI and Secure Boot supported Images](https://github.com/AlmaLinux/cloud-images#how-to-build-uefi-and-secure-boot-supported-images)

`x86_64` BIOS + UEFI:

```sh
packer build -only=qemu.almalinux-8-azure-x86_64 .
```
#### AlmaLinux OS 9

`x86_64` BIOS + UEFI:

See: [How to build UEFI and Secure Boot supported Images](https://github.com/AlmaLinux/cloud-images#how-to-build-uefi-and-secure-boot-supported-images)

```sh
packer build -only=qemu.almalinux-9-azure-x86_64 .
```


### Amazon Machine Images (AMI)


#### AlmaLinux OS 8

`x86_64` BIOS only:

Before building AMI's you need to configure AWS credentials as described in
the Packer [documentation](https://www.packer.io/docs/builders/amazon#environment-variables).
Basically, you need to define the following environment variables:

```sh
export AWS_ACCESS_KEY_ID='ENTER_YOUR_ACCESS_KEY_HERE'
export AWS_SECRET_ACCESS_KEY='ENTER_YOUR_SECRET_KEY_HERE'
export AWS_DEFAULT_REGION='us-east-1'
```

Also, you need to create an S3 bucket that Packer will use for temporary image
storing before importing it into EC2. It's strongly recommended creating the
bucket in the `us-east-1` region if you are going to submit your images to the
Amazon Marketplace. Accordingly to Amazon's [documentation](https://docs.aws.amazon.com/marketplace/latest/userguide/product-submission.html#submitting-amis-to-aws-marketplace),
the self-service AMI scanner supports only that region.

After configuring the AWS credentials and creating the S3 bucket, run the
following command to build an AMI and import it to EC2:

The Build process has two stages:

* Stage 1: Build the first stage's AMI on your system and import it to the AWS.

* Stage 2: Build the second stage's AMI on the EC2 Instance.

The First Stage:

QEMU:

```sh
packer build -var aws_s3_bucket_name="YOUR_S3_BUCKET_NAME" -only=qemu.almalinux-8-aws-stage1 .
```

VMware:

```sh
packer build -var aws_s3_bucket_name="YOUR_S3_BUCKET_NAME" -only=vmware-iso.almalinux-8-aws-stage1 .
```

If you are using a non-standard [role name](https://www.packer.io/docs/post-processors/amazon#role_name),
it's possible to define it as a variable:

QEMU:

```sh
packer build -var aws_s3_bucket_name="YOUR_S3_BUCKET_NAME" \
    -var aws_role_name="YOUR_IAM_ROLE_NAME" -only=qemu.almalinux-8-aws-stage1 .
```
VMware:

```sh
packer build -var aws_s3_bucket_name="YOUR_S3_BUCKET_NAME" \
    -var aws_role_name="YOUR_IAM_ROLE_NAME" -only=vmware-iso.almalinux-8-aws-stage1 .
```
The Second Stage:

To finalize the AMI build process, you need to launch a minimum `t2.micro` EC2 instance from the first stage's AMI.

Launch an instance with the `build-tools-on-ec2-userdata.yml` Cloud-init User Data. It will install all needed packages - `Packer`, `Ansible`, `Git` and `tmux` (if your connection is not stable) and clone the repo automatically.

login as `ec2-user`:

```sh
cd cloud-images
```

Switch to the `root` user:
```sh
sudo su
```

Configure the AWS credentials:

```sh
export AWS_ACCESS_KEY_ID='ENTER_YOUR_ACCESS_KEY_HERE'
export AWS_SECRET_ACCESS_KEY='ENTER_YOUR_SECRET_KEY_HERE'
export AWS_DEFAULT_REGION='us-east-1'
```

Install or Update installed plugins:
```sh
packer.io init -upgrade .
```

Start the Build:
```sh
packer.io build -only=amazon-chroot.almalinux-8-aws-stage2 .
```
You can remove the first stage's AMI after the build complete

`AArch64`

Configure the AWS credentials:

```sh
export AWS_ACCESS_KEY_ID='ENTER_YOUR_ACCESS_KEY_HERE'
export AWS_SECRET_ACCESS_KEY='ENTER_YOUR_SECRET_KEY_HERE'
export AWS_DEFAULT_REGION='us-east-1'
```

Install or Update installed plugins:
```sh
packer init -upgrade .
```

Start the Build:
```sh
packer build -only=amazon-ebssurrogate.almalinux-8-aws-aarch64 .
```

#### AlmaLinux OS 9

Use one of these methods to set up your AWS credentials:

- Static credentials
- Environment variables
- Shared credentials file
- EC2 Role

See https://www.packer.io/plugins/builders/amazon#authentication for instructions.

Install or Update installed plugins:
```sh
packer init -upgrade .
```
Start the Build:

`x86_64` BIOS only:

```sh
packer build -only=amazon-ebssurrogate.almalinux-9-ami-x86_64 .
```

`AArch64`

```sh
packer build -only=amazon-ebssurrogate.almalinux-9-ami-aarch64 .
```


### Vagrant Boxes


#### AlmaLinux OS 8

Libvirt `x86_64` BIOS only:

```sh
packer build -only=qemu.almalinux-8 .
```

Libvirt `x86_64` UEFI only:

See:

* [How to build UEFI and Secure Boot supported Images](https://github.com/AlmaLinux/cloud-images#how-to-build-uefi-and-secure-boot-supported-images)

* [How to use UEFI supported Vagrant boxes](https://github.com/AlmaLinux/cloud-images#how-to-use-uefi-supported-vagrant-boxes)

```sh
packer build -only=qemu.almalinux-8-uefi .
```

VirtualBox `x86_64`:

```sh
packer build -only=virtualbox-iso.almalinux-8 .
```

VMware Desktop `x86_64`:

```sh
packer build -only=vmware-iso.almalinux-8 .
```

Parallels `x86_64`:

```sh
packer build -only=parallels-iso.almalinux-8 .
```

Hyper-V `x86_64`:

```powershell
packer build -only="hyperv-iso.almalinux-8" .
```

With custom Virtual Switch:

```sh
packer build -var hyperv_switch_name="HyperV-vSwitch" -only="hyperv-iso.almalinux-8" .
```

#### AlmaLinux OS 9


Libvirt `x86_64` BIOS + UEFI:

See:

* [How to build UEFI and Secure Boot supported Images](https://github.com/AlmaLinux/cloud-images#how-to-build-uefi-and-secure-boot-supported-images)

* [How to use UEFI supported Vagrant boxes](https://github.com/AlmaLinux/cloud-images#how-to-use-uefi-supported-vagrant-boxes)


```sh
packer build -only=qemu.almalinux-9 .
```

VirtualBox `x86_64`:

```sh
packer build -only=virtualbox-iso.almalinux-9 .
```

VMware Desktop `x86_64`:

```sh
packer build -only=vmware-iso.almalinux-9 .
```

VMware Desktop `aarch64`:

```sh
packer build -only=vmware-iso.almalinux-9-aarch64 .
```

Note: At this time, VMWare Fusion desktop, Apple M1 processer expects additional config settings to `run` vagrant box built for aarch64. It's behaviour of VMWare Fusion, not an issue of AlmaLinux.

```log
Vagrant.configure("2") do |config|
    config.vm.box = "almalinux/9.aarch64"
    config.vm.box_version = "9.1.20230122"
    config.vm.provider "vmware_desktop" do |v|
        v.gui = true
        v.vmx["ethernet0.virtualdev"] = "vmxnet3"
    end
end
```

Parallels `x86_64`:

```sh
packer build -only=parallels-iso.almalinux-9 .
```

Parallels `aarch64`:

```sh
packer build -only=parallels-iso.almalinux-9-aarch64 .
```


Hyper-V `x86_64`:

```powershell
packer build -only="hyperv-iso.almalinux-9" .
```

With custom Virtual Switch:

```sh
packer build -var hyperv_switch_name="HyperV-vSwitch" -only="hyperv-iso.almalinux-9" .
```

### OpenNebula images


#### AlmaLinux OS 8

`x86_64` BIOS only:

```sh
packer build -only=qemu.almalinux-8-opennebula-x86_64 .
```

`AArch64`:

```sh
packer build -only=qemu.almalinux-8-opennebula-aarch64 .
```

#### AlmaLinux OS 9


`x86_64` BIOS + UEFI (Default)

```sh
packer build -only=qemu.almalinux-9-opennebula-x86_64 .
```

`x86_64` BIOS only:

```sh
packer builder -only=qemu.almalinux-9-opennebula-bios-x86_64 .
```

`AArch64`:

```sh
packer build -only=qemu.almalinux-9-opennebula-aarch64 .
```


### Oracle Cloud Infrastructure Images

#### AlmaLinux OS 8

Update the Oracle Cloud Agent RPM link if a newer version is available

`ansible/roles/oci_guest/defaults/main.yml`

`x86_64` UEFI only (Default):

```sh
packer build -only=qemu.almalinux-8-oci-uefi-x86_64 .
```

`x86_64` BIOS only:

```sh
packer build -only=qemu.almalinux-8-oci-x86_64 .
```

`AArch64`:

```sh
packer build -only=qemu.almalinux-8-oci-aarch64 .
```

#### AlmaLinux OS 9


`x86_64` BIOS + UEFI (Default):
```sh
packer build -only=qemu.almalinux-9-oci-x86_64 .
```

`x86_64` BIOS only:

```sh
packer build -only=qemu.almalinux-9-oci-bios-x86_64 .
```

`AArch64`

```sh
packer build -only=qemu.almalinux-9-oci-aarch64 .
```


### DigitalOcean images

You need to setup a key for packer to use. This is done by going to DigitalOcean's [cloud
console](https://cloud.digitalocean.com/account/api/tokens).

Make it available through an environment variable:

```sh
export DIGITALOCEAN_API_TOKEN="ENTER_YOUR_ACCESS_TOKEN_HERE"
```

A space needs to be created in order to import the image through it. Please, read the [relevant
documentation](https://docs.digitalocean.com/products/spaces/how-to/create/). Take note of the access and secret keys in order to
use them later on.

There are a few environment variables you will need to make available.

* The spaces bucket name through `DIGITALOCEAN_SPACE_NAME`.
* The bucket's access key through `DIGITALOCEAN_SPACES_ACCESS_KEY`.
* The bucket's secret key through `DIGITALOCEAN_SPACES_SECRET_KEY`.

You can do this by exporting them as well:

```sh
export DIGITALOCEAN_SPACE_NAME='YOUR_SPACES_BUCKET_NAME'
export DIGITALOCEAN_SPACES_ACCESS_KEY='YOUR_BUCKET_ACCESS_KEY'
export DIGITALOCEAN_SPACES_SECRET_KEY='YOUR_BUCKET_SECRET_KEY'
```

Now, you're all setup. You can try building the image with:


#### AlmaLinux OS 8

`x86_64` BIOS only:

```sh
packer build -only qemu.almalinux-8-digitalocean-x86_64 .
```

#### AlmaLinux OS 9

`x86_64` BIOS only:

```sh
packer build -only qemu.almalinux-9-digitalocean-x86_64 .
```
Import the image to DigitalOcean:

You can upload your image or Import it via URL from the [GitHub release](https://github.com/AlmaLinux/cloud-images/releases) section.

In [Images >> Custom Images](https://cloud.digitalocean.com/images/custom_images) section, click on `Import via URL` and enter the URL of image file :  https://github.com/AlmaLinux/cloud-images/releases/download/digitalocean-20210810/almalinux-8-DigitalOcean-8.4.20210810.x86_64.qcow2

## HOW TOs

#### How to build UEFI and Secure Boot supported Images

You need a `1.0.7` or newer version of the [QEMU packer plugin](https://github.com/hashicorp/packer-plugin-qemu) and [OVMF](https://github.com/tianocore/tianocore.github.io/wiki/OVMF) to build UEFI images.

The `ovmf_code` and `ovmf_vars` Packer variables are set to default OVMF Secure Boot paths for the EL and Fedora. Use the table below for the OVMF package name and the firmware paths for your distro.

| Distro | Package |`ovmf_code` | `ovmf_code` |
| :---:  | :---: | :---: | :--: |
| Arch Linux | `edk2-ovmf` |`/usr/share/OVMF/OVMF_CODE.secboot.fd` | `/usr/share/OVMF/OVMF_VARS.fd` |
| Debian and derivatives | `ovmf` | `/usr/share/OVMF/OVMF_CODE.secboot.fd` | `/usr/share/OVMF/OVMF_VARS.ms.fd` |
| Gentoo | `edk2-ovmf` | `/usr/share/edk2-ovmf/OVMF_CODE.secboot.fd` | `/usr/share/edk2-ovmf/OVMF_VARS.secboot.fd` |
| OpenSUSE | `qemu-ovmf-x86_64` | `/usr/share/qemu/ovmf-x86_64-smm-ms-code.bin` | `/usr/share/qemu/ovmf-x86_64-smm-ms-vars.bin` |

If your distro is not present in the table above or you want to build in different combinations like without Secure Boot, with AMD SEV or Intel TDX, check QEMU firmware metadata files in `/usr/share/qemu/firmware` for the correct paths and combinations.

EL:

```sh
packer build -var qemu_binary="/usr/libexec/qemu-kvm" -only=qemu.almalinux-9-gencloud-x86_64 .
```

Fedora:

```sh
packer build -only=qemu.almalinux-8-azure-x86_64 .
```

Debian and derivatives:

```sh
packer build -var ovmf_code="/usr/share/OVMF/OVMF_CODE.secboot.fd" -var ovmf_vars="/usr/share/OVMF/OVMF_VARS.ms.fd" -only=qemu.almalinux-8-gencloud-uefi-x86_64 .
```

or set the `ovmf_code` and  `ovmf_vars` Packer variables in `.auto.pkrvars.hcl` file:

`uefi.auto.pkrvars.hcl` in OpenSUSE:

```hcl
ovmf_code = "/usr/share/qemu/ovmf-x86_64-smm-ms-code.bin"
ovmf_vars = "/usr/share/qemu/ovmf-x86_64-smm-ms-vars.bin"
```


#### How to use UEFI supported Vagrant boxes

**Libvirt**:

AlmaLinux OS 8 - [almalinux/8.uefi](https://app.vagrantup.com/almalinux/boxes/8.uefi) UEFI only

AlmaLinux OS 9 [almalinux/9](https://app.vagrantup.com/almalinux/boxes/9) BIOS + UEFI

Copy the OVMF NVRAM file:

```sh
cp /usr/share/OVMF/OVMF_VARS.secboot.fd OVMF_VARS.secboot_almalinux-uefi.fd
```

Set these values:

* `libvirt.loader` - Location of OVMF_CODE
* `libvirt.nvram` - Copied OVMF_VARS file
* `libvirt.machine_type = "q35"`

Example Vagrantfile:

```ruby
# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|
    config.vm.box = "almalinux/8.uefi"
    config.vm.hostname = "almalinux8-uefi.test"

    config.vm.provider "libvirt" do |libvirt|
        libvirt.qemu_use_session = false
        libvirt.memory = 2048
        libvirt.loader = "/usr/share/OVMF/OVMF_CODE.secboot.fd"
        libvirt.nvram = "OVMF_VARS.secboot_almalinux-uefi.fd"
        libvirt.machine_type = "q35"
    end
end
```

#### How to build Generic Cloud images on ppc64le

Load the KVM-HV kernel module

```sh
modprobe kvm_hv
```

Verify that the KVM kernel module is loaded

```sh
lsmod | grep kvm
```
If KVM loaded successfully, the output of this command includes `kvm_hv`.

The external packer plugins don't have the `ppc64le` builds yet, So use internal packer plugins.

```sh
mv versions.pkr.hcl versions.pkr.hcl.ignore
```

## Requirements

* [Packer](https://www.packer.io/) `>= 1.7.0`
* [Ansible](https://www.ansible.com/) `>= 2.12`
* [VirtualBox](https://www.virtualbox.org/) (for VirtualBox images only)
* [Parallels](https://www.parallels.com/) (for Parallels images only)
* [VMWare Workstation](https://www.vmware.com/products/workstation-pro.html) (for VMWare images and Amazon AMI's only)
* [QEMU](https://www.qemu.org/) (for Generic Cloud, Vagrant Libvirt, AWS AMI, OpenNebula and DigitalOcean images only)
* [EDK II](https://github.com/tianocore/tianocore.github.io/wiki/OVMF) (for only UEFI supported `x86_64` ones and all `AArch64` images)


## FAQ:


### Nothing happens after invoking the packer command

The [cracklib-dicts's](https://sourceforge.net/projects/cracklib/) `/usr/sbin/packer` takes precedence over Hashicorp's `/usr/bin/packer` in the `$PATH`.
Use `packer.io` instead of the `packer`. See: https://learn.hashicorp.com/tutorials/packer/get-started-install-cli#troubleshooting

```sh
ln -s /usr/bin/packer /usr/bin/packer.io
```

### "qemu-system-x86_64": executable file not found in $PATH

Output:

`Failed creating Qemu driver: exec: "qemu-system-x86_64": executable file not found in $PATH`

By default, Packer looks for QEMU binary as `qemu-system-x86_64`. If it is different in your system, You can set your qemu binary with the `qemu_binary` Packer variable.

on EL - `/usr/libexec/qemu-kvm`

```sh
packer build -var qemu_binary="/usr/libexec/qemu-kvm" -only=qemu.almalinux-8-gencloud-x86_64 .
```

or set the `qemu_binary` Packer variable in `.auto.pkrvars.hcl` file:

`qemu_on_el.auto.pkrvars.hcl`

```hcl
qemu_binary = "/usr/libexec/qemu-kvm"
```

### Failed to connect to the host via scp with OpenSSH >= 9.0/9.0p1 and EL9

OpenSSH `>= 9.0/9.0p1` and EL9 support was added in [scp_90](https://github.com/AlmaLinux/cloud-images/tree/scp_90) branch instead of the `main` for backward compatibility. Please switch to this branch with `git checkout scp_90`

The Ansible's `ansible.builtin.template` module gives error on EL9 and >= OpenSSH 9.0/9.0p1 (2022-04-08) Host OS.

Error output:

```sh
fatal: [default]: UNREACHABLE! => {"changed": false, "msg": "Failed to connect to the host via scp: bash: line 1: /usr/lib/sftp-server: No such file or directory\nConnection closed\r\n", "unreachable": true}
```

EL9 and OpenSSH >=9.0 deprecated the SCP protocol. Use the new `-O` flag until Ansible starts to use SFTP directly.

From [OpenSSH 9.0/9.0p1 \(2022-04-08\) release note:](https://www.openssh.com/txt/release-9.0)

> In case of incompatibility, the `scp(1)` client may be instructed to use
the legacy scp/rcp using the `-O` flag.

See: [OpenSSH SCP deprecation in RHEL 9: What you need to know ](https://www.redhat.com/en/blog/openssh-scp-deprecation-rhel-9-what-you-need-know)

Add `extra_arguments  = [ "--scp-extra-args", "'-O'" ]` to the Packer's Ansible Provisioner Block:

```hcl
  provisioner "ansible" {
    playbook_file    = "./ansible/gencloud.yml"
    galaxy_file      = "./ansible/requirements.yml"
    roles_path       = "./ansible/roles"
    collections_path = "./ansible/collections"
    extra_arguments  = [ "--scp-extra-args", "'-O'" ]
    ansible_env_vars = [
      "ANSIBLE_PIPELINING=True",
      "ANSIBLE_REMOTE_TEMP=/tmp",
      "ANSIBLE_SSH_ARGS='-o ControlMaster=no -o ControlPersist=180s -o ServerAliveInterval=120s -o TCPKeepAlive=yes'"
    ]
  }
```

### Packer's Ansible Plugin can't connect via SSH on SHA1 disabled system

**FIXED:** Starting with the `1.1.0` version, `ECDSA` keypair is generated and used by default instead of `RSA`.

To upgrade the plugin and disable SHA1:

```sh
packer init -upgrade .
update-crypto-policies --set DEFAULT
```

Error output:

```sh
fatal: [default]: UNREACHABLE! => {"changed": false, "msg": "Data could not be sent to remote host \"127.0.0.1\". Make sure this host can be reached over ssh: ssh_dispatch_run_fatal: Connection to 127.0.0.1 port 43729: error in libcrypto\r\n", "unreachable": true}
```

Enable the `SHA1` on the system's default crypto policy until Packer's Ansible Plugin use a stronger key types and signature algorithms(`rsa-sha2-256`,` rsa-sha2-512`, `ecdsa-sha2-nistp256`, `ssh-ed25519`) than `ssh-rsa`.

Fedora and EL:

```sh
update-crypto-policies --set DEFAULT:SHA1
```

### How to build AlmaLinux OS cloud images on EL

**EL8**:

See:
* ["qemu-system-x86_64": executable file not found in $PATH](https://github.com/AlmaLinux/cloud-images#qemu-system-x86_64-executable-file-not-found-in-path)

**EL9**:

See:
* ["qemu-system-x86_64": executable file not found in $PATH](https://github.com/AlmaLinux/cloud-images#qemu-system-x86_64-executable-file-not-found-in-path)
* [Packer's Ansible Plugin can't connect via SSH on SHA1 disabled system](https://github.com/AlmaLinux/cloud-images#packers-ansible-plugin-cant-connect-via-ssh-on-sha1-disabled-system)
* [Failed to connect to the host via scp with OpenSSH >= 9.0/9.0p1 and EL9](https://github.com/AlmaLinux/cloud-images#failed-to-connect-to-the-host-via-scp-with-openssh--9090p1-and-el9)

## References

* AWS
  * [EC2 documentation: Guidelines for shared Linux AMIs](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/building-shared-amis.html)
  * [EC2 documentation: VM Import/Export](https://aws.amazon.com/ec2/vm-import/)
  * [Marketplace documentation: Submitting your product for publication](https://docs.aws.amazon.com/marketplace/latest/userguide/product-submission.html)
* [RHEL® 8 documentation: Kickstart installation basics](https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/8/html/performing_an_advanced_rhel_installation/kickstart-installation-basics_installing-rhel-as-an-experienced-user)
* [CentOS kickstart files](https://git.centos.org/centos/kickstarts)
* [CentOS Stream kickstart files](https://gitlab.com/redhat/centos-stream/release-engineering/kickstarts)


## License

Licensed under the MIT license, see the [LICENSE](LICENSE) file for details.
