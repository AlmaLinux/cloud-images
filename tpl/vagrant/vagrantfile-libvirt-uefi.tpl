# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|
  config.vm.synced_folder ".", "/vagrant", type: "rsync"
  config.vm.provider :libvirt do |libvirt|
    libvirt.driver = "kvm"
    libvirt.connect_via_ssh = false
    libvirt.username = "root"
    libvirt.storage_pool_name = "default"
    libvirt.loader = "/usr/share/OVMF/OVMF_CODE.fd"
    libvirt.machine_type = "q35"
  end
end
