#!/usr/bin/env python

import commands
import ConfigParser
import os
from node_check_state.output import *

# AIM configuration file
AIM_CONFIG = '/home/ibarrera/abiquo-aim.ini'

def read_config(config_file):
    config = ConfigParser.ConfigParser()
    config.readfp(open(config_file))
    config.read(config_file)
    return config

def check_file(file_name):
    label = "Checking %s ..." % file_name
    test(label, os.path.exists(file_name))

def check_dir(dir_name):
    label = "Checking %s ..." % dir_name
    test(label, os.path.isdir(dir_name))

def check_vlan(config):
    title('Checking VLAN ...')
    check_file(config.get('vlan', 'ifconfigCmd'))
    check_file(config.get('vlan', 'vconfigCmd'))
    check_file(config.get('vlan', 'brctlCmd'))
    print

def check_repository(config):
    title('Checking AIM ...')
    repo = config.get('rimp', 'repository') + '/.abiquo_repository'
    datastore = config.get('rimp', 'datastore')
    check_file(repo)
    check_dir(datastore)
    print

def check_libvirt(config):
    title('Checking libvirt ...')

    uri = config.get('monitor', 'uri')
    cmd = 'virsh -c %s exit' % uri

    label ='Connecting to %s ...' % uri
    res = commands.getstatusoutput(cmd)
    test(label, not res[0], fail_msg = 'ERROR')

    print

if __name__ == '__main__':
    config = read_config(AIM_CONFIG)
    check_vlan(config)
    check_repository(config)
    check_libvirt(config)

