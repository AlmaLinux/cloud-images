import pytest


def test_vagrant_user_group(host):
    """Check if the vagrant user created in a vagrant group and its UID and GUID values is 1000"""
    assert host.user("vagrant").exists
    assert host.group("vagrant").exists
    assert host.user("vagrant").uid == 1000
    assert host.user("vagrant").gid == 1000


def test_vagrant_sudoers_file(host):
    """Check if vagrant user's sudoers file is present and correct"""
    with host.sudo():
        sudoers_file = host.file("/etc/sudoers.d/vagrant")
        sudoers_file.contains("vagrant     ALL=(ALL)     NOPASSWD: ALL")


def test_guest_tools_installed(host):
    """Check if Hypervisor Guest Additions/Tools/Agents/Kernel modules installed"""
    kvm_tools = ['qemu-guest-agent', 'rsync', 'nfs-utils']
    hyperv_tools = ['cifs-utils', 'hyperv-daemons']
    hypervisor = host.check_output("systemd-detect-virt")
    if hypervisor == "kvm":
        for package in kvm_tools:
            assert host.package(package).is_installed
    elif hypervisor == "oracle":
        vb_guest_cmd = host.run("lsmod | grep vboxguest")
        assert vb_guest_cmd.succeeded == True
        assert host.package("nfs-utils").is_installed
    elif hypervisor == "vmware":
        assert host.package("open-vm-tools").is_installed
        assert host.package("nfs-utils").is_installed
    elif hypervisor == "microsoft":
        for package in hyperv_tools:
            assert host.package(package).is_installed
    else:
        raise NotImplementedError(f'Unsupported Hypervisor: {hypervisor}')


def test_guest_services_are_running(host):
    """Check if guest agents services running and enabled"""
    hyperv_services = ['hypervvssd', 'hypervkvpd', 'hypervfcopyd']
    hypervisor = host.check_output("systemd-detect-virt")
    if hypervisor == "kvm":
        assert host.service("qemu-guest-agent.service").is_running
        assert host.service("qemu-guest-agent.service").is_enabled
    elif hypervisor == "oracle":
        assert host.service("vboxadd-service.service").is_running
        assert host.service("vboxadd-service.service").is_enabled
    elif hypervisor == "vmware":
        assert host.service("vmtoolsd.service").is_running
        assert host.service("vmtoolsd.service").is_enabled
    elif hypervisor == "microsoft":
        for service in hyperv_services:
            assert host.service(service).is_running
            assert host.service(service).is_enabled
    else:
        raise NotImplementedError(f'Unsupported Hypervisor {hypervisor}')


def test_insecure_vagrant_ssh_pub_key(host):
    """Only Vagrant insecure public key should be present"""
    authorized_keys = host.file("/home/vagrant/.ssh/authorized_keys").content_string
    if len(authorized_keys.splitlines()) == 1:
        # SHA256 checksum of "$vagrant_insecure_pub_key vagrant insecure public key"
        assert host.file(
            "/home/vagrant/.ssh/authorized_keys").sha256sum == "9aa9292172c915821e29bcbf5ff42d4940f59d6a148153c76ad638f5f4c6cd8b"
    else:
        raise NotImplementedError(f'Authorized Key file not correct')


def test_shared_folder_is_working(host):
    """Check if the synced folders are working"""
    assert host.mount_point("/vagrant").exists
    assert host.file("/vagrant/Vagrantfile").exists


def test_installer_leftovers(host):
    """Check if installer logs and kickstart files removed after the installation"""
    assert host.file("/root/anaconda-ks.cfg").exists == False
    assert host.file("/root/original-ks.cfg").exists == False
    assert host.file("/var/log/anaconda").exists == False
    assert host.file("/root/install.log").exists == False
    assert host.file("/root/install.log.syslog").exists == False


def test_network_is_working(host):
    """Check if networking works properly"""
    almalinux = host.addr("almalinux.org")
    assert almalinux.is_resolvable
    assert almalinux.port(443).is_reachable


def test_get_machineids(host):
    """Get machine-id of the each machine and write to a file"""
    hostname = host.check_output("hostname")
    machine_id = host.file('/etc/machine-id').content_string
    with open(f'{hostname}.machineid', 'w') as fd:
        fd.write(machine_id)


@pytest.mark.depends(on=['test_get_machineids'])
def test_uniqueness_of_machineids():
    """Check if machine-id is unique for each machine"""
    with open('almalinux-test-1.test.machineid', 'r') as file:
        machine_id_a = file.read()
    with open('almalinux-test-2.test.machineid', 'r') as file:
        machine_id_b = file.read()
    assert machine_id_a != machine_id_b


def test_get_ssh_host_keys(host):
    """Get checksum of SSH host keys from each machine and write to file"""
    hostname = host.check_output("hostname")
    with host.sudo():
        host_key = host.check_output("sha256sum /etc/ssh/ssh_host_*")
    with open(f'{hostname}.sshhostkeys', 'w') as fd:
        fd.write(host_key)


@pytest.mark.depends(on=['test_get_ssh_host_keys'])
def test_uniqueness_of_ssh_host_keys(host):
    """Check if SSH host keys are unique for each machine"""
    hostname = host.check_output("hostname")
    if hostname == "almalinux-test-2.test":
        with open('almalinux-test-1.test.sshhostkeys', 'r') as file:
            ssh_host_keys_a = file.read()
        with open('almalinux-test-2.test.sshhostkeys', 'r') as file:
            ssh_host_keys_b = file.read()
        assert ssh_host_keys_a != ssh_host_keys_b
