# AlmaLinux OS Cloud Images

AlmaLinux OS Cloud Images is a project that contains
[Packer](https://www.packer.io/) templates and other tools for building
AlmaLinux OS images for various cloud platforms.


## Download official images

|            Name            |                             Download URL                            |
| -------------------------- | ------------------------------------------------------------------- |
| AWS Marketplace AMI        | https://aws.amazon.com/marketplace/pp/B094C8ZZ8J                    |
| AWS community AMIs         | https://wiki.almalinux.org/cloud/AWS.html                           |
| Docker Hub                 | https://hub.docker.com/_/almalinux                                  |
| Generic Cloud (cloud-init) | https://repo.almalinux.org/almalinux/8/cloud/x86_64/images/         |
| Google Cloud               | https://cloud.google.com/compute/docs/images#almalinux              |
| LXC/LXD                    | https://images.linuxcontainers.org                                  |
| Quay.io                    | https://quay.io/repository/almalinux/almalinux                      |
| Vagrant boxes              | [app.vagrantup.com/almalinux](https://app.vagrantup.com/almalinux/) |


## Roadmap

* [ ] Add aarch64 architecture support
* [x] Vagrant + VirtualBox support
* [x] Vagrant + VMWare support
* [ ] Vagrant + Parallels support (#3)
* [x] Vagrant + Microsoft Hyper-V support (#4)
* [x] Vagrant + Libvirt support
* [x] AWS support (using the VMWare builder only, it would be nice to support VirtualBox or Qemu as well)
* [x] Google Cloud support
* [ ] Microsoft Azure support (#14)
* [x] DigitalOcean support
* [x] Generic Cloud / OpenStack support (#12)
* [x] LXC/LXD support (#8)


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

Build a Hyper-V box:

```powershell
> packer build -only="hyperv-iso.almalinux-8" .
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


### Build a DigitalOcean image

As with the Amazon AMI, you need to install and configure DigitalOcean credentials for `doctl`; as described in the relevant
[documentation](https://docs.digitalocean.com/reference/doctl/how-to/install/).

Now, you can use the provided script to pull the latest Generic Cloud image to DigitalOcean:

```sh
$ bin/digitalocean-import_latest_image.bash
```

This process takes around 5 minutes. Be sure to check with `doctl compute image list` and make sure your image is listed before
proceeding.

The script will write `.env.digitalocean` which, when sourced, will provide one of the required environment variables for this
procedure: `DIGITALOCEAN_IMAGE`.

```sh
$ source .env.digitalocean
```

You can set this one manually as well:

```sh
$ export DIGITALOCEAN_IMAGE='YOUR_IMAGE_ID_GOES_HERE'
```

Now, you need to setup a key for packer to use. This is done by going to DigitalOcean's [cloud
console](https://cloud.digitalocean.com/account/api/tokens).

Make it available through an environment variable:

```sh
$ export DIGITALOCEAN_TOKEN="ENTER_YOUR_ACCESS_TOKEN_HERE"
```

Now, you're all setup. You can try building the image with:

```sh
$ packer build -only do.almalinux-8-digitalocean-x86_64 .
```

For simplicity, the whole procedure looks like:

```sh
# get the image
$ bin/digitalocean-import_latest_image.bash

# set the image ID
$ source .env.digitalocean

# verify the new Generic Cloud image is in place
$ doctl compute image list

# set your packer token
$ export DIGITALOCEAN_API_TOKEN="ENTER_YOUR_ACCESS_TOKEN_HERE"

# build image
$ packer build -only digitalocean.almalinux-8-digitalocean-x86_64 .
```


### Build a Generic Cloud (OpenStack compatible) image

```sh
$ packer build -only qemu.almalinux-8-gencloud-x86_64 .
```


## Requirements

* [Packer](https://www.packer.io/)
* [Ansible](https://www.ansible.com/)
* [VirtualBox](https://www.virtualbox.org/) (for VirtualBox images only)
* [VMWare Workstation](https://www.vmware.com/products/workstation-pro.html) (for VMWare images and Amazon AMI's only)
* [QEMU](https://www.qemu.org/) (for Generic Cloud and Libvirt images only)


## References

* AWS
  * [EC2 documentation: Guidelines for shared Linux AMIs](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/building-shared-amis.html)
  * [EC2 documentation: VM Import/Export](https://aws.amazon.com/ec2/vm-import/)
  * [Marketplace documentation: Submitting your product for publication](https://docs.aws.amazon.com/marketplace/latest/userguide/product-submission.html)
* [RHEL® 8 documentation: Kickstart installation basics](https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/8/html/performing_an_advanced_rhel_installation/kickstart-installation-basics_installing-rhel-as-an-experienced-user)
* [CentOS kickstart files](https://git.centos.org/centos/kickstarts)


## License

Licensed under the MIT license, see the [LICENSE](LICENSE) file for details.
