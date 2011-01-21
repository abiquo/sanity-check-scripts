#!/usr/bin/env python

import commands
import ConfigParser
import os
from node_check_state.output import *

# AIM configuration file
AIM_CONFIG = '/etc/abiquo-aim.ini'

# Configuration parsing functions

def read_config(config_file):
    config = ConfigParser.ConfigParser()
    config.readfp(open(config_file))
    config.read(config_file)
    return config

# System utility functions

def check_file(file_name):
    label = 'Checking %s ...' % file_name
    test(label, os.path.exists(file_name))

def check_dir(dir_name):
    label = 'Checking %s ...' % dir_name
    test(label, os.path.isdir(dir_name))

def check_process(name):
    label = 'Checking "%s" process ...' % name
    res = commands.getstatusoutput('ps -e | grep ' + name)
    test(label, not res[0], fail_msg = 'STOPPED')

# Check functions

def check_vlan(config):
    title('Checking VLAN binaries')
    check_file(config.get('vlan', 'ifconfigCmd'))
    check_file(config.get('vlan', 'vconfigCmd'))
    check_file(config.get('vlan', 'brctlCmd'))
    print

def check_aim(config):
    title('Checking Abiquo AIM')
    repo = config.get('rimp', 'repository') + '/.abiquo_repository'
    datastore = config.get('rimp', 'datastore')
    check_file(repo)
    check_dir(datastore)
    check_process('abiquo-aim')
    print

def check_libvirt(config):
    title('Checking libvirt configuration')
  
    check_process('libvirtd')
    
    uri = config.get('monitor', 'uri')
    label = 'Connecting to %s ...' % uri
    cmd = 'virsh -c %s exit' % uri
    res = commands.getstatusoutput(cmd)
    test(label, not res[0], fail_msg = 'ERROR')

    print

def check_hypervisor():
    uri = commands.getoutput('virsh uri')
    if uri.startswith('qemu'):
        title('Checking KVM binaries')
        check_file('/usr/bin/qemu-kvm')
    else:
        title('Checking XEN binaries')
        check_file('/usr/lib64/xen/bin/qemu-dm')
        check_file('/usr/lib/xen/boot/hvmloader')

    print

def check_firewall():
    title('Checking firewall')

    # Check firewall configuration at runlevel
    label = 'Checking that firewall is disabled in the current runlevel ...'
    runlevel = commands.getoutput('runlevel').split()[1]
    activation = commands.getoutput('chkconfig --list iptables')
    active = activation.find(runlevel + ':off') >= 0
    test(label, active, fail_msg = "ENABLED", warn = True)

    # Check if there are active rules
    label = 'Checking that there are no active firewall rules ...'
    rules = commands.getstatusoutput('iptables -nL | grep - "--"')
    test(label, rules[0], fail_msg = 'RULES FOUND', warn = True)

    # Check SELinux status
    label = 'Checking if SELinux is disabled ...'
    selinux = os.listdir('/selinux')
    test(label, not selinux, fail_msg = 'ENABLED', warn = True)

    print

if __name__ == '__main__':
    config = read_config(AIM_CONFIG)
    check_vlan(config)
    check_libvirt(config)
    check_aim(config)
    check_firewall()
    check_hypervisor()

