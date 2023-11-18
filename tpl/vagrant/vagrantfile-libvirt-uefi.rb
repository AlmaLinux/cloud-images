Vagrant.configure('2') do |config|
  config.vm.synced_folder '.', '/vagrant', type: 'rsync'
  config.vm.provider :libvirt do |libvirt|
    libvirt.loader = '/usr/share/OVMF/OVMF_CODE.fd'
    libvirt.machine_type = 'q35'
  end
end
