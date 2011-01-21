#!/usr/bin/env python

"""Copyright (c) 2010 Abiquo Holdings

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
"""

__license__ = "MIT http://www.opensource.org/licenses/mit-license.php"
__author__ = "Ignasi Barrera (ignasi.barrera@abiquo.com)"
__version__ = "0.1"


import commands
import os

import ConfigParser

from node_check_state.output import *


# AIM configuration file
AIM_CONFIG = '/etc/abiquo-aim.ini'


# Configuration support functions

def read_config(config_file):
    """Reads the configuration file"""
    config = ConfigParser.ConfigParser()
    config.readfp(open(config_file))
    config.read(config_file)
    return config


# System utility functions

def check_file(file_name):
    """Checks if the given file exists"""
    label = 'Checking %s ...' % file_name
    test(label, os.path.exists(file_name))

def check_dir(dir_name):
    """Checks if the given directory exists"""
    label = 'Checking %s ...' % dir_name
    test(label, os.path.isdir(dir_name))

def check_process(name):
    """Checks if the given process is running"""
    label = 'Checking "%s" process ...' % name
    res = commands.getstatusoutput('ps -e | grep ' + name)
    test(label, not res[0], fail_msg='STOPPED')


# Check functions

def check_vlan(config):
    """Checks that all VLAN binaries exist"""
    title('Checking VLAN binaries')
    check_file(config.get('vlan', 'ifconfigCmd'))
    check_file(config.get('vlan', 'vconfigCmd'))
    check_file(config.get('vlan', 'brctlCmd'))
    print

def check_repository(config):
    """Checks if the Abiquo repository is properly configured"""
    repo = config.get('rimp', 'repository') + '/.abiquo_repository'
    datastore = config.get('rimp', 'datastore')
    check_file(repo)
    check_dir(datastore)

def check_libvirt(config):
    """Checks if libvirt is running and can connect to the hypervisor"""
    title('Checking libvirt configuration')
    check_process('libvirtd')
    
    uri = config.get('monitor', 'uri')
    label = 'Connecting to %s ...' % uri
    cmd = 'virsh -c %s exit' % uri
    res = commands.getstatusoutput(cmd)
    test(label, not res[0], fail_msg='ERROR')

    print

def check_hypervisor():
    """Check if the hypervisor binaries exist"""
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
    """Check if the firewall is active and has filtering rules"""
    title('Checking firewall')

    # Check firewall configuration at runlevel
    label = 'Checking that firewall is disabled in the current runlevel ...'
    runlevel = commands.getoutput('runlevel').split()[1]
    activation = commands.getoutput('chkconfig --list iptables')
    active = activation.find(runlevel + ':off') >= 0
    test(label, active, fail_msg="ENABLED", warn=True)

    # Check if there are active rules
    label = 'Checking that there are no active firewall rules ...'
    rules = commands.getstatusoutput('iptables -nL | grep - "--"')
    test(label, rules[0], fail_msg='RULES FOUND', warn=True)

    # Check SELinux status
    label = 'Checking if SELinux is disabled ...'
    selinux = os.listdir('/selinux')
    test(label, not selinux, fail_msg='ENABLED', warn = True)

    print

def check_aim(config_file):
    """Checks the configuration values in the system"""
    title('Checking Abiquo AIM')
    check_file(config_file)

    if os.path.exists(config_file):
        config = read_config(config_file)
        check_repository(config)
        check_process('abiquo-aim')
        print

        check_vlan(config)
        check_libvirt(config)
    else:
        print
       
if __name__ == '__main__':
    check_aim(AIM_CONFIG)
    check_firewall()
    check_hypervisor()

