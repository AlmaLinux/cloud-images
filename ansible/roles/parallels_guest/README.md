# parallels_guest

An Ansible role that installs Parallels Tools on a Vagrant box built with the
Packer `parallels-iso` builder. The builder uploads the Tools ISO to
`/home/vagrant/prl-tools-<flavor>.iso`; this role mounts it, runs the
unattended installer, and cleans up.

Required for working `prl_fs` (shared folders), `prl_eth`, and time sync.
