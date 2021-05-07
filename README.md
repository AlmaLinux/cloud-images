# AlmaLinux OS Cloud Images

AlmaLinux OS Cloud Images is a project that contains
[Packer](https://www.packer.io/) templates and other tools for building
AlmaLinux OS images for various cloud platforms.


## Download official images

Vagrant boxes are distributed through Vagrant Cloud:
[app.vagrantup.com/almalinux](https://app.vagrantup.com/almalinux/).

Amazon AMI is provided by [AlmaLinux OS Foundation](https://aws.amazon.com/marketplace/seller-profile?id=529d1014-352c-4bed-8b63-6120e4bd3342):
https://aws.amazon.com/marketplace/pp/B094C8ZZ8J.


## Roadmap

* [x] Vagrant + VirtualBox support
* [x] Vagrant + VMWare support
* [ ] Vagrant + Parallels support (#3)
* [ ] Vagrant + Microsoft Hyper-V support (#4)
* [x] Vagrant + Libvirt support
* [x] AWS support (using the VMWare builder only, it would be nice to support VirtualBox or Qemu as well)
* [ ] Google Cloud support
* [ ] Microsoft Azure support (#14)
* [ ] DigitalOcean support
* [ ] OpenStack support (#12)
* [ ] LXC/LXD support (#8)


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

Build a Libvirt box:

```sh
$ packer build -only=qemu.almalinux-8 .
```


### Build an Amazon AMI

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

```sh
$ packer build -var aws_s3_bucket_name="YOUR_S3_BUCKET_NAME" -only=vmware-iso.almalinux-8-aws .
```

If you are using a non-standard [role name](https://www.packer.io/docs/post-processors/amazon#role_name),
it's possible to define it as a variable:

```sh
$ packer build -var aws_s3_bucket_name="YOUR_S3_BUCKET_NAME" \
               -var aws_role_name="YOUR_IAM_ROLE_NAME" -only=vmware-iso.almalinux-8-aws .
```


## Requirements

* [Packer](https://www.packer.io/)
* [Ansible](https://www.ansible.com/)
* [VirtualBox](https://www.virtualbox.org/) (for VirtualBox images only)
* [VMWare Workstation](https://www.vmware.com/products/workstation-pro.html) (for VMWare images and Amazon AMI's only)
* [QEMU](https://www.qemu.org/) (for Libvirt images only)


## References

* AWS
  * [EC2 documentation: Guidelines for shared Linux AMIs](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/building-shared-amis.html)
  * [EC2 documentation: VM Import/Export](https://aws.amazon.com/ec2/vm-import/)
  * [Marketplace documentation: Submitting your product for publication](https://docs.aws.amazon.com/marketplace/latest/userguide/product-submission.html)
* [RHEL® 8 documentation: Kickstart installation basics](https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/8/html/performing_an_advanced_rhel_installation/kickstart-installation-basics_installing-rhel-as-an-experienced-user)
* [CentOS kickstart files](https://git.centos.org/centos/kickstarts)


## License

Licensed under the MIT license, see the [LICENSE](LICENSE) file for details.
