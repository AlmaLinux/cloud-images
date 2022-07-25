# Tests for AlmaLinux OpenNebula Images

This [Testinfra](https://testinfra.readthedocs.io/) test checks the facts below:

- [x] `almalinux` user created in a `almalinux` group and its `UID` and `GUID` values is `1000`.
- [x] `almalinux` user's `/etc/sudoers.d/one-context` file is present and it's content is `almalinux ALL=(ALL) NOPASSWD:ALL`.
- [x] QEMU Guest Agent is installed, its services running and enabled.
- [x] OpenNebula Linux VM Contextualization installed.
- [x] The `network.service` running and enabled.
- [x] Only one `authorized_keys` file present on the system and it only includes the `almalinux` user's ssh public key.
- [x] Installer logs and kickstart files removed after the installation.
- [x] Networking works properly.
- [x] [machine-id](https://www.freedesktop.org/software/systemd/man/machine-id.html) is unique on each machine created from the boxes.
- [x] SSH host keys are unique on each machine created from the boxes.


## How to run
Use one of methods to Assign the needed Terraform variables:

See: https://www.terraform.io/language/values/variables#assigning-values-to-root-module-variables


One of the methods is Variable Definitions (.tfvars) Files:

`tests/opennebula/create_test_vms/amd64/terraform.tfvars`

`tests/opennebula/create_test_vms/aarch64/terraform.tfvars`
```hcl
one_endpoint = "https://HOSTNAME:2633/RPC2"
one_username = "exampleuser"
one_password = "passwordofexampleuser"
datastore_id = "1234"
network_id   = "1234"
group        = "groupname"
ssh_pub_key  = "ssh-rsa ..." 
```
Create two virtual machines with Terraform:

`x86_64`

```sh
cd tests/opennebula/create_test_vms/amd64
terraform apply -auto-approve
```

`aarch64`

```sh
cd tests/opennebula/create_test_vms/aarch64
terraform apply -auto-approve
```

Run tests with the generated `ssh-config` file.

`x86_64`

```sh
py.test -v --hosts=almalinux-test-1,almalinux-test-2 --ssh-config=tests/opennebula/create_test_vms/amd64/ssh-config test_opennebula.py
```

`aarch64`

```sh
py.test -v --hosts=almalinux-test-1,almalinux-test-2 --ssh-config=tests/opennebula/create_test_vms/aarch64/ssh-config test_opennebula.py
```
