# -*- mode:python; coding:utf-8; -*-
# author: Eugene Zamriy <ezamriy@almalinux.org>
# created: 2022-10-21

"""
AlmaLinux OS default Azure image tests.

Usage:

  1. Create an Azure virtual machine from a built image.
  2. Run tests using the following command (replace 10.0.0.1 with a real IP):
     py.test -v --hosts=ssh://azureuser@10.0.0.1 tests/azure/test_azure.py
"""

import configparser
import re

import pytest
import yaml


AZURE_KMODS = ['hv_vmbus', 'hv_netvsc', 'hv_storvsc', 'nvme', 'pci-hyperv']


@pytest.fixture(scope="module")
def azure_dracut_conf(host):
    return host.file('/etc/dracut.conf.d/azure.conf').content_string


@pytest.fixture(scope="module")
def initrd_content(host):
    with host.sudo():
        return host.run('lsinitrd -k $(uname -r)').stdout


@pytest.fixture(scope="module")
def chrony_conf_content(host):
    return host.file('/etc/chrony.conf').content_string


def test_hyperv_daemons(host):
    """Verifies hyperv-daemons package installation."""
    assert host.package('hyperv-daemons').is_installed
    kvp_service = host.service('hypervkvpd')
    assert kvp_service.is_running
    assert kvp_service.is_enabled


@pytest.mark.parametrize('package', ['tar', 'yum-utils'])
def test_common_utils(host, package):
    """Common packages should be installed"""
    assert host.package(package).is_installed


def test_selinux_enforcing(host):
    """Checks that SELinux policy is enforced."""
    cmd = host.run('getenforce')
    assert cmd.stdout.strip() == 'Enforcing'


def test_kmod_blacklist_permissions(host):
    """Check /etc/modprobe.d/blacklist.conf file permissions"""
    file_path = '/etc/modprobe.d/blacklist.conf'
    blacklist = host.file(file_path)
    assert blacklist.user == 'root'
    assert blacklist.group == 'root'
    assert blacklist.mode == 0o644
    context = host.run(f'ls -Z {file_path} | cut -d " " -f 1').stdout.strip()
    assert context == 'system_u:object_r:modules_conf_t:s0'


@pytest.mark.parametrize('kmod', ['nouveau', 'lbm-nouveau', 'floppy'])
def test_kmod_blacklist(host, kmod):
    """Ensure that unnecessary kernel modules are blacklisted."""
    blacklist = host.file('/etc/modprobe.d/blacklist.conf')
    assert blacklist.contains(f'blacklist {kmod}')
    if kmod == 'nouveau':
        assert blacklist.contains('options nouveau modeset=0')


def test_network_manager_enabled(host):
    """NetworkManager should be running."""
    nm = host.service('NetworkManager')
    assert nm.is_running
    assert nm.is_enabled


def test_network_manager_default_dhcp_timeout(host):
    """NetworkManager default DHCP timeout should be 300 seconds."""
    file_path = '/etc/NetworkManager/conf.d/99-dhcp-timeout.conf'
    dhcp_conf = host.file(file_path)
    assert dhcp_conf.user == 'root'
    assert dhcp_conf.group == 'root'
    assert dhcp_conf.mode == 0o644
    context = host.run(f'ls -Z {file_path} | cut -d " " -f 1').stdout.strip()
    assert context == 'system_u:object_r:NetworkManager_etc_t:s0'
    content = dhcp_conf.content_string
    parser = configparser.ConfigParser()
    parser.read_string(content)
    assert parser.getint('connection', 'ipv4.dhcp-timeout') == 300


def test_eth0_dhcp_timeout(host):
    """NetworkManager should use 300 seconds default DHCP timeout for eth0."""
    cmd = host.run(r'journalctl -x -u NetworkManager | '
                   r'grep -P "dhcp4.*?eth0.*?timeout\s+in\s+300\s+seconds"')
    assert cmd.rc == 0


@pytest.mark.parametrize('file_path',
                         ['/etc/cloud/cloud.cfg.d/91-azure_datasource.cfg',
                          '/etc/cloud/cloud.cfg.d/10-azure-kvp.cfg'])
def test_cloud_init_permissions(host, file_path):
    """Verify cloud-init configuration files permissions."""
    f = host.file(file_path)
    assert f.user == 'root'
    assert f.group == 'root'
    assert f.mode == 0o644
    context = host.run(f'ls -Z {file_path} | cut -d " " -f 1').stdout.strip()
    assert context == 'system_u:object_r:etc_t:s0'


def test_cloud_init_azure_datasource(host):
    """Verify Azure datasource configuration for cloud-init."""
    ds_file = host.file('/etc/cloud/cloud.cfg.d/91-azure_datasource.cfg')
    y = yaml.safe_load(ds_file.content_string)
    assert y['datasource_list'] == ['Azure']
    assert y['datasource']['Azure']['apply_network_config'] is False


def cloud_init_azure_kvp(host):
    """Verify Azure KVP configuration for cloud-init."""
    kvp_file = host.file('/etc/cloud/cloud.cfg.d/10-azure-kvp.cfg')
    y = yaml.safe_load(kvp_file.content_string)
    assert y['reporting']['logging']['type'] == 'log'
    assert y['reporting']['telemetry']['type'] == 'hyperv'


def test_walinuxagent(host):
    """WALinuxAgent package should be installed and waagent should be running"""
    assert host.package('WALinuxAgent').is_installed
    service = host.service('waagent')
    assert service.is_running
    assert service.is_enabled


def test_walinuxagent_config(host):
    """Verify WALinuxAgent configuration file settings."""
    cfg_file = host.file('/etc/waagent.conf')
    content = cfg_file.content_string
    # resource disk formatting should be enabled
    assert re.search(r'^ResourceDisk\.Format=y$', content,
                     flags=re.MULTILINE) is not None


def test_sshd_config(host):
    """Root login should be disabled and client alive interval set to 180."""
    with host.sudo():
        content = host.file('/etc/ssh/sshd_config').content_string
    assert re.search(r'^ClientAliveInterval\s+180\s*$', content,
                     flags=re.MULTILINE) is not None
    assert re.search(r'^PermitRootLogin\s+no\s*$', content,
                     flags=re.MULTILINE) is not None


def test_dnf_config(host):
    """Packages caching should be enabled in DNF config."""
    content = host.file('/etc/dnf/dnf.conf').content_string
    assert re.search(r'^http_caching=packages$', content,
                     flags=re.MULTILINE) is not None


@pytest.mark.parametrize('kmod', AZURE_KMODS)
def test_azure_dracut_config(kmod, initrd_content, azure_dracut_conf):
    """Check Azure dracut configuration."""
    assert re.search(fr'^add_drivers\+=".*?\s+{kmod}(\s+.*?|)"',
                     azure_dracut_conf, flags=re.MULTILINE) is not None


@pytest.mark.parametrize('kmod', AZURE_KMODS)
def test_azure_initrd_kmods(kmod, initrd_content):
    """Check that initrd contains Hyper-V drivers"""
    assert re.search(fr'/{kmod}\.ko', initrd_content,
                     flags=re.MULTILINE) is not None


def test_sriov_udev_rules(host):
    """Check SRIOV interface udev rules."""
    file_path = '/etc/udev/rules.d/68-azure-sriov-nm-unmanaged.rules'
    f = host.file(file_path)
    assert f.user == 'root'
    assert f.group == 'root'
    assert f.mode == 0o644
    context = host.run(f'ls -Z {file_path} | cut -d " " -f 1').stdout.strip()
    assert context == 'system_u:object_r:udev_rules_t:s0'
    assert re.search(r'SUBSYSTEM=="net",\s+DRIVERS=="hv_pci",\s+ACTION=="add",'
                     r'\s+ENV{NM_UNMANAGED}="1"', f.content_string,
                     flags=re.MULTILINE) is not None


def test_ptp_udev_rules(host):
    """Check PTP clock source udev rules."""
    file_path = '/etc/udev/rules.d/99-azure-hyperv-ptp.rules'
    f = host.file(file_path)
    assert f.user == 'root'
    assert f.group == 'root'
    assert f.mode == 0o644
    context = host.run(f'ls -Z {file_path} | cut -d " " -f 1').stdout.strip()
    assert context == 'system_u:object_r:udev_rules_t:s0'
    assert re.search(r'SUBSYSTEM=="ptp",\s+ATTR{clock_name}=="hyperv",\s+'
                     r'SYMLINK\s+\+=\s+"ptp_hyperv"', f.content_string,
                     flags=re.MULTILINE) is not None


def test_chronyd_enabled(host):
    """Ensure that chrony daemon is running."""
    chronyd = host.service('chronyd')
    assert chronyd.is_running
    assert chronyd.is_enabled


def test_chrony_refclock(chrony_conf_content):
    """Refclock should be configured in chrony.conf."""
    assert re.search(r'^refclock\s+PHC\s+/dev/ptp_hyperv\s+poll\s+3\s+'
                     r'dpoll\s+-2\s+offset\s+0$', chrony_conf_content,
                     flags=re.MULTILINE) is not None


def test_chrony_pools_disabled(chrony_conf_content):
    """NTP pools should be disabled in chrony.conf"""
    assert re.search(r'^\s*pool\s+', chrony_conf_content,
                     flags=re.MULTILINE) is None


def test_chrony_servers_disabled(chrony_conf_content):
    """NTP servers should be disabled in chrony.conf"""
    assert re.search(r'^\s*server\s+', chrony_conf_content,
                     flags=re.MULTILINE) is None


def test_chrony_makestep(chrony_conf_content):
    assert re.search(r'^makestep\s+1\.0\s+-1$', chrony_conf_content,
                     flags=re.MULTILINE) is not None
