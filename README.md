# AlmaLinux OS Cloud Images

AlmaLinux OS Cloud Images is a project that contains
[Packer](https://www.packer.io/) templates and other tools for building
AlmaLinux OS images for various cloud platforms.


## Download official images

|            Name            |                             Download URL                            |
| -------------------------- | ------------------------------------------------------------------- |
| AWS Marketplace AMI        | https://aws.amazon.com/marketplace/pp/B094C8ZZ8J                    |
| AWS community AMIs         | https://wiki.almalinux.org/cloud/AWS.html                           |
| Azure Marketplace          | https://azuremarketplace.microsoft.com/en-us/marketplace/apps/almalinux.almalinux |
| Docker Hub                 | https://hub.docker.com/_/almalinux                                  |
| Generic Cloud (cloud-init) | https://wiki.almalinux.org/cloud/Generic-cloud.html                 |
| Google Cloud               | https://cloud.google.com/compute/docs/images#almalinux              |
| LXC/LXD                    | https://images.linuxcontainers.org                                  |
| Quay.io                    | https://quay.io/repository/almalinux/almalinux                      |
| Vagrant boxes              | [app.vagrantup.com/almalinux](https://app.vagrantup.com/almalinux/) |
| OpenNebula                 | https://wiki.almalinux.org/cloud/OpenNebula.html                    |


## Roadmap

* [ ] Add aarch64 architecture support
* [x] Vagrant + VirtualBox support
* [x] Vagrant + VMWare support
* [x] Vagrant + Parallels support (#3)
* [x] Vagrant + Microsoft Hyper-V support (#4)
* [x] Vagrant + Libvirt support
* [x] AWS AMI `x86_64` and `aarch64` support
* [x] Google Cloud support
* [x] Microsoft Azure support (#14)
* [x] DigitalOcean support
* [x] Generic Cloud / OpenStack `x86_64`, `x86_64 UEFI`, `aarch64` and `ppc64le` support
* [x] LXC/LXD support (#8)
* [x] OpenNebula `x86_64` and `aarch64` support


## Usage

Initialize Packer plugins:

```sh
$ packer init .
```


### Build a Vagrant Box

Build a VirtualBox box:

```sh
$ packer build -only=virtualbox-iso.almalinux-8 .
```

Build a VMWare box:

```sh
$ packer build -only=vmware-iso.almalinux-8 .
```

Build a Parallels box:

```sh
$ packer build -only=parallels-iso.almalinux-8 .
```

Build a Libvirt box:

```sh
$ packer build -only=qemu.almalinux-8 .
```

Build a Hyper-V box:

```powershell
> packer build -only="hyperv-iso.almalinux-8" .
```


### Build an Amazon AMI

`x86_64`

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
$ packer build -var aws_s3_bucket_name="YOUR_S3_BUCKET_NAME" -only=qemu.almalinux-8-aws-stage1 .
```

VMware:

```sh
$ packer build -var aws_s3_bucket_name="YOUR_S3_BUCKET_NAME" -only=vmware-iso.almalinux-8-aws-stage1 .
```

If you are using a non-standard [role name](https://www.packer.io/docs/post-processors/amazon#role_name),
it's possible to define it as a variable:

QEMU:

```sh
$ packer build -var aws_s3_bucket_name="YOUR_S3_BUCKET_NAME" \
               -var aws_role_name="YOUR_IAM_ROLE_NAME" -only=qemu.almalinux-8-aws-stage1 .
```
VMware:

```sh
$ packer build -var aws_s3_bucket_name="YOUR_S3_BUCKET_NAME" \
               -var aws_role_name="YOUR_IAM_ROLE_NAME" -only=vmware-iso.almalinux-8-aws-stage1 .
```
The Second Stage:

To finalize the AMI build process, you need to launch a minimum `t2.micro` EC2 instance from the first stage's AMI.

Launch an instance with the `build-tools-on-ec2-userdata.yml` Cloud-init User Data. It will install all needed packages - `Packer`, `Ansible`, `Git` and `tmux` (if your connection is not stable) and clone the repo automatically.

login as `ec2-user`:

```sh
$ cd cloud-images
```

Switch to the `root` user:
```sh
$ sudo su
```

Confugire the AWS credentials:

```sh
export AWS_ACCESS_KEY_ID='ENTER_YOUR_ACCESS_KEY_HERE'
export AWS_SECRET_ACCESS_KEY='ENTER_YOUR_SECRET_KEY_HERE'
export AWS_DEFAULT_REGION='us-east-1'
```

Install required Packer plugins:
```sh
packer.io init .
```

Start the Build:
```sh
packer.io build -only=amazon-chroot.almalinux-8-aws-stage2 .
```
You can remove the first stage's AMI after the build complete

`aarch64`

Confugire the AWS credentials:

```sh
export AWS_ACCESS_KEY_ID='ENTER_YOUR_ACCESS_KEY_HERE'
export AWS_SECRET_ACCESS_KEY='ENTER_YOUR_SECRET_KEY_HERE'
export AWS_DEFAULT_REGION='us-east-1'
```

Install required Packer plugins:
```sh
packer init .
```

Start the Build:
```sh
packer build -only=amazon-ebssurrogate.almalinux-8-aws-aarch64 .
```


### Build a DigitalOcean image

You need to setup a key for packer to use. This is done by going to DigitalOcean's [cloud
console](https://cloud.digitalocean.com/account/api/tokens).

Make it available through an environment variable:

```sh
$ export DIGITALOCEAN_API_TOKEN="ENTER_YOUR_ACCESS_TOKEN_HERE"
```

A space needs to be created in order to import the image through it. Please, read the [relevant
documentation](https://docs.digitalocean.com/products/spaces/how-to/create/). Take note of the access and secret keys in order to
use them later on.

There are a few environemnt variables you will need to make available.

* The spaces bucket name through `DIGITALOCEAN_SPACE_NAME`.
* The bucket's access key through `DIGITALOCEAN_SPACES_ACCESS_KEY`.
* The bucket's secret key through `DIGITALOCEAN_SPACES_SECRET_KEY`.

You can do this by exporting them as well:

```sh
$ export DIGITALOCEAN_SPACE_NAME='YOUR_SPACES_BUCKET_NAME'
$ export DIGITALOCEAN_SPACES_ACCESS_KEY='YOUR_BUCKET_ACCESS_KEY'
$ export DIGITALOCEAN_SPACES_SECRET_KEY='YOUR_BUCKET_SECRET_KEY'
```

Now, you're all setup. You can try building the image with:

```sh
$ packer build -only qemu.almalinux-8-digitalocean-x86_64 .
```
### Import the image to DigitalOcean

You can upload your image or Import it via URL from the [GitHub release](https://github.com/AlmaLinux/cloud-images/releases) section.

In [Images >> Custom Images](https://cloud.digitalocean.com/images/custom_images) section, click on `Import via URL` and enter the URL of image file :  https://github.com/AlmaLinux/cloud-images/releases/download/digitalocean-20210810/almalinux-8-DigitalOcean-8.4.20210810.x86_64.qcow2

### Build a Generic Cloud (OpenStack compatible) image

`x86_64`
```sh
$ packer build -only=qemu.almalinux-8-gencloud-x86_64 .
```

`UEFI on x86_64`

You need the `1.0.2` version of the [QEMU packer plugin](https://github.com/hashicorp/packer-plugin-qemu) and `edk2-ovmf`(RPM and ArchLinux)/`ovmf`(DEB) packages for the needed OVMF firmware files.

```sh
$ packer build -only=qemu.almalinux-8-gencloud-uefi-x86_64 .
```

`How to build UEFI images on EL8 systems`

By default the `firmware_x86_64` packer variable set to use `/usr/share/OVMF/OVMF_CODE.fd`.
The `OVMF_CODE.fd` is not present on the EL8 systems and the packer qemu plugin's VM doesn't boot with the `OVMF_CODE.secboot.fd`.
Thanks to the Fedora edk2 package maintainer [kraxel](https://www.kraxel.org) for his [Qemu firmware repo](https://www.kraxel.org/repos/),
You can use the latest build of the OVMF from the repo without overwriting the system's package manager provided firmware files.

Add the repository:

```sh
$ dnf config-manager --add-repo=https://www.kraxel.org/repos/firmware.repo
```

Recreate the DNF cache and install UEFI firmware for x64 qemu guests (OVMF):

```sh
$ dnf makecache && dnf -y install edk2.git-ovmf-x64
```

Build UEFI Image on the EL8:

```sh
$ packer build -var qemu_binary="/usr/libexec/qemu-kvm" -var firmware_x86_64="/usr/share/edk2.git/ovmf-x64/OVMF_CODE-pure-efi.fd" -only=qemu.almalinux-8-gencloud-uefi-x86_64 .
```

`aarch64`
```sh
$ packer build -only=qemu.almalinux-8-gencloud-aarch64 .
```

`ppc64le`

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

```sh
$ packer build -only=qemu.almalinux-8-gencloud-ppc64le .
```


### Build a OpenNebula image

`x86_64`
```sh
$ packer build -only=qemu.almalinux-8-opennebula-x86_64 .
```

`aarch64`
```sh
$ packer build -only=qemu.almalinux-8-opennebula-aarch64 .
```


## Requirements

* [Packer](https://www.packer.io/)
* [Ansible](https://www.ansible.com/)
* [VirtualBox](https://www.virtualbox.org/) (for VirtualBox images only)
* [Parallels](https://www.parallels.com/) (for Parallels images only)
* [VMWare Workstation](https://www.vmware.com/products/workstation-pro.html) (for VMWare images and Amazon AMI's only)
* [QEMU](https://www.qemu.org/) (for Generic Cloud, Vagrant Libvirt, AWS AMI, OpenNebula and DigitalOcean images only)
* [EDK II](https://github.com/tianocore/tianocore.github.io/wiki/OVMF) (for only UEFI supported `x86_64` ones and all `aarch64` images)


## References

* AWS
  * [EC2 documentation: Guidelines for shared Linux AMIs](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/building-shared-amis.html)
  * [EC2 documentation: VM Import/Export](https://aws.amazon.com/ec2/vm-import/)
  * [Marketplace documentation: Submitting your product for publication](https://docs.aws.amazon.com/marketplace/latest/userguide/product-submission.html)
* [RHEL® 8 documentation: Kickstart installation basics](https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/8/html/performing_an_advanced_rhel_installation/kickstart-installation-basics_installing-rhel-as-an-experienced-user)
* [CentOS kickstart files](https://git.centos.org/centos/kickstarts)

## FAQ:
**Issue:** build stuck after running the packer command.

**Solution:** Use `packer.io` instead of the `packer`. See: https://learn.hashicorp.com/tutorials/packer/get-started-install-cli#troubleshooting

example:

```sh
ln -s /usr/bin/packer /usr/bin/packer.io
```

**Issue:** `Failed creating Qemu driver: exec: "qemu-system-x86_64": executable file not found in $PATH`

**Solution:** By default, Packer looks for QEMU binary as `qemu-system-x86_64`. If it is different in your system, You can set your qemu binary with the `qemu_binary` variable. i.e. on EL, it's `qemu-kvm`. :

example:

```sh
$ packer build -var qemu_binary="/usr/libexec/qemu-kvm" -only=qemu.almalinux-8-gencloud-x86_64 .
```
## License

Licensed under the MIT license, see the [LICENSE](LICENSE) file for details.
