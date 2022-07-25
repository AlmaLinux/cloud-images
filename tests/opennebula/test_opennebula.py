import pytest


def test_almalinux_user_group(host):
    """Check if the almalinux user created in the almalinux group and its UID and GUID values are 1000"""
    assert host.user("almalinux").exists
    assert host.group("almalinux").exists
    assert host.user("almalinux").uid == 1000
    assert host.user("almalinux").gid == 1000


def test_almalinux_sudoers_file(host):
    """Check if almalinux user's sudoers file is present and correct"""
    with host.sudo():
        sudoers_file = host.file("/etc/sudoers.d/one-context")
        sudoers_file.contains("almalinux ALL=(ALL) NOPASSWD:ALL")


# @pytest.mark.parametrize('package', [])
def test_qemu_agent_installed(host):
    """Check if QEMU Guest Agent is installed, its services running and enabled"""
    assert host.package("qemu-guest-agent").is_installed
    assert host.service("qemu-guest-agent.service").is_enabled


def test_one_context_installed(host):
    """"Check if OpenNebula Linux VM Contextualization installed"""
    assert host.package("one-context").is_installed


def test_one_context_service(host):
    """"Check if OpenNebula Linux VM Contextualization service running and enabled"""
    assert host.service("one-context").is_running
    assert host.service("one-context").is_enabled


def test_network_service(host):
    """Check if network.service running and enabled"""
    assert host.service("network.service").is_running
    assert host.service("network.service").is_enabled


def test_authorized_keys_file(host):
    """Check if one authorized_keys file present for almalinux user"""
    with host.sudo():
        assert host.check_output("find / -iname authorized_keys") == "/home/almalinux/.ssh/authorized_keys"


def test_instance_ssh_pub_key(host):
    """Only key pair's public key should be present"""
    authorized_keys = host.file(".ssh/authorized_keys").content_string
    assert len(authorized_keys.splitlines()) == 1


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
    #assert almalinux.port(443).is_reachable


@pytest.mark.dependency()
def test_get_machine_ids(host):
    """Get machine-id of the each machine and write to a file"""
    machine_id = host.file('/etc/machine-id').content_string
    open('hostnames.txt', 'a').write(f'{machine_id}')


@pytest.mark.dependency(depends=["test_get_machine_ids"])
def test_uniqueness_of_machineid():
    """Check if machine-id is unique for each machine"""
    machine_id_a, machine_id_b = open('hostnames.txt', 'r').read().splitlines()[:2]
    assert machine_id_a != machine_id_b


@pytest.mark.dependency()
def test_get_ssh_hostkeys(host):
    """Get checksum of SSH host keys from each machine and write to file"""
    with host.sudo():
        host_key = host.check_output("sha256sum /etc/ssh/ssh_host_*")
    open('sshhostkeys.txt', 'a').write(f'{host_key}\n')


@pytest.mark.dependency(depends=["test_get_ssh_hostkeys"])
def test_uniqueness_of_sshhostkeys():
    """Check if SSH host keys are unique for each machine"""
    content = open('sshhostkeys.txt', 'r').read()
    ssh_host_keys_a, ssh_host_keys_b = '\n'.join(content.splitlines()[:6]), '\n'.join(content.splitlines()[6:])
    assert ssh_host_keys_a != ssh_host_keys_b
