# AlmaLinux OS Cloud Images


AlmaLinux OS Cloud Images is a project that contains
[Packer](https://www.packer.io) templates and other tools for building
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

Make sure the required Packer plugins are installed and the latest:

```sh
packer init -upgrade .
```


### Generic Cloud (OpenStack compatible) images


#### AlmaLinux OS 8

`x86_64` Unified Boot (BIOS and UEFI):

See: [How to build UEFI and Secure Boot supported Images](https://github.com/AlmaLinux/cloud-images#how-to-build-uefi-and-secure-boot-supported-images)

```sh
packer build -only=qemu.almalinux-8-gencloud-x86_64 .
```

`AArch64`:

```sh
packer build -only=qemu.almalinux-8-gencloud-aarch64 .
```

`ppc64le`:

```sh
packer build -only=qemu.almalinux-8-gencloud-ppc64le .
```

`s390x`:

If you are building on AlmaLinux OS or other EL distro, the latest version of [Oz](https://github.com/clalancette/oz.git) is available on [Synergy](https://wiki.almalinux.org/repos/Synergy.html).

Consult the [reference configuration](https://github.com/clalancette/oz/blob/master/oz.cfg) to configure `almalinux_oz.cfg`.

Generate a Oz TDL file with a timestamp in UTC and minor version of AlmaLinux OS 8.

```sh
export IMAGE_TIMESTAMP=$(date -u '+%Y%m%d')
# For AlmaLinux OS 8.10, It is 10.
export IMAGE_MINOR_VERSION='10'

sed -E "s/TIMESTAMP/"${IMAGE_TIMESTAMP}"/g" almalinux_8_gencloud_s390x.xml.tmpl > almalinux_8_gencloud_s390x.xml
sed -Ei "s/MINOR_VERSION/"${IMAGE_MINOR_VERSION}"/g" almalinux_8_gencloud_s390x.xml
```

Build.

Use `-t` to increase timeout in seconds if the builder machine is slow.

```sh
sudo oz-install \
    -a http/almalinux-8.gencloud-s390x.ks \
    -c almalinux_oz.cfg \
    -d 2 \
    -f \
    -p \
    almalinux_8_gencloud_s390x.xml
```

Optional: Compress QCOW2 image file and upgrade its version from QCOW2 v2 (`0.10`) to QCOW2 v3 (`1.1`).

```sh
qemu-img convert \
    -c \
    -f qcow2 \
    -O qcow2 \
    /var/lib/libvirt/images/AlmaLinux-8-GenericCloud-8."${IMAGE_MINOR_VERSION}"-"${IMAGE_TIMESTAMP}".s390x.qcow2 \
    AlmaLinux-8-GenericCloud-8."${IMAGE_MINOR_VERSION}"-"${IMAGE_TIMESTAMP}".s390x.qcow2
```

#### AlmaLinux OS 9

`x86_64` Unified Boot (BIOS and UEFI):

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

`s390x`:

If you are building on AlmaLinux OS or other EL distro, the latest version of [Oz](https://github.com/clalancette/oz.git) is available on [Synergy](https://wiki.almalinux.org/repos/Synergy.html).

Consult the [reference configuration](https://github.com/clalancette/oz/blob/master/oz.cfg) to configure `almalinux_oz.cfg`.

Generate a Oz TDL file with a timestamp in UTC and minor version of AlmaLinux OS 9.

```sh
export IMAGE_TIMESTAMP=$(date -u '+%Y%m%d')
# For AlmaLinux OS 9.4, It is 4.
export IMAGE_MINOR_VERSION='4'

sed -E "s/TIMESTAMP/"${IMAGE_TIMESTAMP}"/g" almalinux_9_gencloud_s390x.xml.tmpl > almalinux_9_gencloud_s390x.xml
sed -Ei "s/MINOR_VERSION/"${IMAGE_MINOR_VERSION}"/g" almalinux_9_gencloud_s390x.xml
```

Build.

Use `-t` to increase timeout in seconds if the builder machine is slow.

```sh
sudo oz-install \
    -a http/almalinux-9.gencloud-s390x.ks \
    -c almalinux_oz.cfg \
    -d 2 \
    -f \
    -p \
    almalinux_9_gencloud_s390x.xml
```

Optional: Compress QCOW2 image file and upgrade its version from QCOW2 v2 (`0.10`) to QCOW2 v3 (`1.1`).

```sh
qemu-img convert \
    -c \
    -f qcow2 \
    -O qcow2 \
    /var/lib/libvirt/images/AlmaLinux-9-GenericCloud-9."${IMAGE_MINOR_VERSION}"-"${IMAGE_TIMESTAMP}".s390x.qcow2 \
    AlmaLinux-9-GenericCloud-9."${IMAGE_MINOR_VERSION}"-"${IMAGE_TIMESTAMP}".s390x.qcow2
```

### Azure VM Images

Both AlmaLinux OS 8 and 9 cloud images supports Generation 1 and Generation 2 VMs.


#### AlmaLinux OS 8

See: [How to build UEFI and Secure Boot supported Images](https://github.com/AlmaLinux/cloud-images#how-to-build-uefi-and-secure-boot-supported-images)

`x86_64` Unified Boot (BIOS and UEFI):

```sh
packer build -only=qemu.almalinux-8-azure-x86_64 .
```

`AArch64`:

```sh
packer build -only=qemu.almalinux-8-azure-aarch64 .
```
#### AlmaLinux OS 9

`x86_64` Unified Boot (BIOS and UEFI):

See: [How to build UEFI and Secure Boot supported Images](https://github.com/AlmaLinux/cloud-images#how-to-build-uefi-and-secure-boot-supported-images)

```sh
packer build -only=qemu.almalinux-9-azure-x86_64 .
```

`AArch64`:

```sh
packer build -only=qemu.almalinux-9-azure-aarch64 .
```

`AArch64` with with 64k page size kernel:

```sh
packer build -only=qemu.almalinux_9_azure_aarch64_64k .
```

#### AlmaLinux OS Kitten 10

`x86_64` Unified Boot (BIOS and UEFI):

See: [How to build UEFI and Secure Boot supported Images](https://github.com/AlmaLinux/cloud-images#how-to-build-uefi-and-secure-boot-supported-images)

```sh
packer build -only=qemu.almalinux_kitten_10_azure_x86_64 .
```

`AArch64`:

```sh
packer build -only=qemu.almalinux_kitten_10_azure_aarch64 .
```

`AArch64` with with 64k page size kernel:

```sh
packer build -only=qemu.almalinux_kitten_10_azure_aarch64_64k .
```

### Amazon Machine Images (AMI)

#### Requirements

1. Use one of these methods to set up your AWS credentials:

- Static credentials
- Environment variables
- Shared credentials file
- EC2 Role

See https://www.packer.io/plugins/builders/amazon#authentication for instructions.

**Note:** Use `aws_profile` Packer input variable if you configured multiple profiles on the shared credentials file.

2. Configure your region if it is different than `us-east-1`.

The `us-east-1` is set as a default region of:
- Source AMI ID: `aws_source_ami_9_x86_64`, `aws_source_ami_9_aarch64`, `aws_source_ami_8_x86_64`, `aws_source_ami_8_aarch64`.
- Region of EC2 Instance to be used as a builder: `aws_ami_region`
- The list of regions to copy the AMI to: `aws_ami_regions`

You can get the ID of source AMI using one of these methods:

AlmaLinux Wiki:

Latest AMIs are published on: https://wiki.almalinux.org/cloud/AWS.html#community-amis

AWS Console:

On the page of EC2 service, click on AMIs on the left panel. Select filter as "Public Images" and paste this `Owner = 764336703387`.

AWS CLI:

Replace the `$REGION` with yours. e.g. `us-west-1`:

AlmaLinux OS 8:

```sh
aws ec2 describe-images --owners 764336703387 --query 'sort_by(Images, &CreationDate)[*].[CreationDate,Name,ImageId]' --filters "Name=name,Values=AlmaLinux OS 8*" --region $REGION --output table
```

AlmaLinux OS 9:

```sh
aws ec2 describe-images --owners 764336703387 --query 'sort_by(Images, &CreationDate)[*].[CreationDate,Name,ImageId]' --filters "Name=name,Values=AlmaLinux OS 9*" --region $REGION --output table
```

Use the one of the methods listed below to set input variables:

- Command-line option
- Variable definition file
- Environment variable

**Command line option**

```sh
packer build \
    -var='aws_source_ami_9_x86_64=ami-1234567890abcdef0' \
    -var='aws_ami_region=us-west-1' \
    -var='aws_ami_regions=["us-west-1"]' \
    -only=amazon-ebssurrogate.almalinux_9_ami_x86_64 .
```

**Variable definition file**

Auto-loaded with `.auto.pkrvars.hcl` file extension:

`foo.auto.pkrvars.hcl`
```hcl
aws_source_ami_9_x86_64 = "ami-1234567890abcdef0"
aws_ami_region          = "us-west-1"
aws_ami_regions         = ["us-west-1"]
```

Standard definition with `.pkrvars.hcl` ending:
```sh
packer build -var-file="foo.pkrvars.hcl" -only=amazon-ebssurrogate.almalinux_9_ami_x86_64 .
```

**Environment Variables**

```sh
export PKR_VAR_aws_source_ami_9_x86_64='ami-1234567890abcdef0'
export PKR_VAR_aws_ami_region='us-west-1'
export PKR_VAR_aws_ami_regions='["us-west-1"]'

packer build -only=amazon-ebssurrogate.almalinux_9_ami_x86_64 .
```

or

```sh
PKR_VAR_aws_source_ami_9_x86_64='ami-1234567890abcdef0' PKR_VAR_aws_ami_region='us-west-1' PKR_VAR_aws_ami_regions='["us-west-1"]' packer build -only=amazon-ebssurrogate.almalinux_9_ami_x86_64 .
```

#### Build

##### AlmaLinux OS 8

`x86_64` Unified Boot (BIOS and UEFI):

```sh
packer build -only=amazon-ebssurrogate.almalinux_8_ami_x86_64 .
```

`AArch64`:

```sh
packer build -only=amazon-ebssurrogate.almalinux_8_ami_aarch64 .
```

##### AlmaLinux OS 9

`x86_64` Unified Boot (BIOS and UEFI):

```sh
packer build -only=amazon-ebssurrogate.almalinux_9_ami_x86_64 .
```

`AArch64`:


```sh
packer build -only=amazon-ebssurrogate.almalinux_9_ami_aarch64 .
```

#### Customization

These input variables can be used for the cutomization of AMIs:
- Volume type of AMI (default: gp3): `aws_volume_type`
- Volume size of AMI (default: 4 GiB): `aws_volume_size`

You can also speed-up the build time with upgrading the instance type for builder EC2 Instances:
- Instance type of x86_64 builder EC2 Instance (default: `t3.small`): `aws_instance_type_x86_64`
- Instance type of AArch64 builder EC2 Instance (default: `t4g.small`): `aws_instance_type_aarch64`

**Note:** Only Nitro based EC2 instances are supported as a builder.

For any customization inside the AMI, import your custom ansible playbook after the "Install AWS Guest Tools" task on `ansible/roles/ami_[8-9]_(x86_64|aarch64)/tasks/main.yaml`.


### Vagrant Boxes

#### AlmaLinux OS 8

Libvirt `x86_64` Unified Boot (BIOS and UEFI):

See:

* [How to build UEFI and Secure Boot supported Images](https://github.com/AlmaLinux/cloud-images#how-to-build-uefi-and-secure-boot-supported-images)

* [How to use UEFI supported Vagrant boxes](https://github.com/AlmaLinux/cloud-images#how-to-use-uefi-supported-vagrant-boxes)

```sh
packer build -only=qemu.almalinux-8 .
```

VirtualBox `x86_64` Unified Boot (BIOS and UEFI)::

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


Libvirt `x86_64` Unified Boot (BIOS and UEFI):

See:

* [How to build UEFI and Secure Boot supported Images](https://github.com/AlmaLinux/cloud-images#how-to-build-uefi-and-secure-boot-supported-images)

* [How to use UEFI supported Vagrant boxes](https://github.com/AlmaLinux/cloud-images#how-to-use-uefi-supported-vagrant-boxes)


```sh
packer build -only=qemu.almalinux-9 .
```

VirtualBox `x86_64` Unified Boot (BIOS and UEFI)::

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

Note: At this time, VMWare Fusion desktop, Apple M1 processor expects additional config settings to `run` vagrant box built for aarch64. It's behavior of VMWare Fusion, not an issue of AlmaLinux OS.

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


Hyper-V `x86_64` Unified Boot (BIOS and UEFI):

```powershell
packer build -only="hyperv-iso.almalinux-9" .
```

With custom Virtual Switch:

```sh
packer build -var hyperv_switch_name="HyperV-vSwitch" -only="hyperv-iso.almalinux-9" .
```

### OpenNebula images


#### AlmaLinux OS 8

`x86_64` Unified Boot (BIOS and UEFI):

```sh
packer build -only=qemu.almalinux-8-opennebula-x86_64 .
```

`AArch64`:

```sh
packer build -only=qemu.almalinux-8-opennebula-aarch64 .
```

#### AlmaLinux OS 9

`x86_64` Unified Boot (BIOS and UEFI):

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

`x86_64` Unified Boot (BIOS and UEFI):

```sh
packer build -only=qemu.almalinux-8-oci-x86_64 .
```

`AArch64`:

```sh
packer build -only=qemu.almalinux-8-oci-aarch64 .
```

#### AlmaLinux OS 9

`x86_64` Unified Boot (BIOS and UEFI):
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

`x86_64` Unified Boot (BIOS and UEFI):

```sh
packer build -only qemu.almalinux-8-digitalocean-x86_64 .
```

#### AlmaLinux OS 9

`x86_64` Unified Boot (BIOS and UEFI):

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

on EL, it's `/usr/libexec/qemu-kvm`:

```sh
packer build -var qemu_binary="/usr/libexec/qemu-kvm" -only=qemu.almalinux-8-gencloud-x86_64 .
```

or set the `qemu_binary` Packer variable in `.auto.pkrvars.hcl` file:

`qemu_on_el.auto.pkrvars.hcl`

```hcl
qemu_binary = "/usr/libexec/qemu-kvm"
```

### File transfer fails with OpenSSH < 9.0/9.0p1

On AlmaLinux OS 8, Debian 11 (bullseye) and Ubuntu 20.04 LTS (Focal Fossa), comment `"ANSIBLE_SCP_EXTRA_ARGS=-O"` Ansible variable:

```sh
sed -i 's/.*\("ANSIBLE_SCP_EXTRA_ARGS=-O"\).*/# \1/g' almalinux*.pkr.hcl
```

Error output:

```sh
fatal: [default]: FAILED! => {"msg": "failed to transfer file to /home/vagrant/.ansible/tmp/ansible-local-3759yjc1ghcz/tmpzo9a3_vb/grub.conf.j2 /tmp/ansible-tmp-1715955434.1781824-3861-34379722779259/source:\n\nunknown option -- O\r\nusage: scp [-346BCpqrTv] [-c cipher] [-F ssh_config] [-i identity_file]\n            [-J destination] [-l limit] [-o ssh_option] [-P port]\n            [-S program] source ... target\n"}
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
