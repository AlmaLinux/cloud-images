# Tests for AlmaLinux Amazon Machine Images (AMI)

This [Testinfra](https://testinfra.readthedocs.io/) test checks the facts below:

- [x] `ec2-user` user created in a `ec2-user` group and its `UID` and `GUID` values is `1000`.
- [x] `ec2-user` user's `/etc/sudoers.d/90-cloud-init-users` file is present and it's content is `ec2-user ALL=(ALL) NOPASSWD:ALL`.
- [x] Amazon SSM Agent is installed, its services running and enabled.
- [x] Only key-pair's public key present in `/home/ec2-user/.ssh/authorized_keys`.
- [x] Installer logs and kickstart files removed after the installation.
- [x] Networking works properly.
- [x] [machine-id](https://www.freedesktop.org/software/systemd/man/machine-id.html) is unique on each instance created from the AMI.
- [x] SSH host keys are unique on each instance created from the AMI.


## How to run

Create two instances with Terraform:

`x86_64`

```sh
$ cd tests/ami/launch_test_instances/amd64/
$ terraform apply -auto-approve
```

`aarch64`

```sh
$ cd tests/ami/launch_test_instances/aarch64/
$ terraform apply -auto-approve
```

Run tests with the generated `ssh-config` file.

`x86_64`

```sh
$ py.test -v --hosts=almalinux-test-1,almalinux-test-2 --ssh-config=tests/ami/launch_test_instances/amd64/ssh-config test_ami.py
```

`aarch64`

```sh
$ py.test -v --hosts=almalinux-test-1,almalinux-test-2 --ssh-config=tests/ami/launch_test_instances/aarch64/ssh-config test_ami.py
```
