# Tests for AlmaLinux Vagrant Boxes

This TestInfra test checks the facts below:

- [x] `vagrant` user created in a `vagrant` group and its `UID` and `GUID` values is `1000`.
- [x] `vagrant` user's `/etc/sudoers.d/vagrant` file is present and it's content is `vagrant     ALL=(ALL)     NOPASSWD: ALL`.
- [x] Hypervisor Guest Additions/Tools/Agents/Kernel modules installed based on the provider of the box.
- [x] Guest agents services running and enabled.
- [x] Only [Vagrant insecure public key](https://github.com/hashicorp/vagrant/tree/main/keys) present in `/home/vagrant/.ssh/authorized_keys`.
- [x] Vagrant [synced folders](https://www.vagrantup.com/docs/synced-folders) are working.
- [x] Installer logs and kickstart files removed after the installation.
- [x] Networking works properly.
- [x] [machine-id](https://www.freedesktop.org/software/systemd/man/machine-id.html) is unique on each machine created from the boxes.
- [x] SSH host keys are unique on each machine created from the boxes.


## How to run

Linux:

```sh
$ vagrant up
$ vagrant ssh-config > .vagrant/ssh-config
$ py.test -v --hosts=almalinux-test-1,almalinux-test-2 --ssh-config=.vagrant/ssh-config test_vagrant.py 
```
Windows:

```powershell
# If you don't want to enter username and password on each vagrant up:
PS> $Env:SMB_USERNAME = 'USER'
PS> $Env:SMB_PASSWORD = 'PASSWORD'
PS> vagrant up
PS> vagrant ssh-config | Out-File -Encoding ascii -FilePath .vagrant/ssh-config
PS> py.test -v --hosts=almalinux-test-1,almalinux-test-2 --ssh-config=.vagrant/ssh-config test_vagrant.py 
```
