#!/usr/bin/env python

import ConfigParser
import os
from node_check_state.output import *

def read_config(config_file):
    config = ConfigParser.ConfigParser()
    config.readfp(open(config_file))
    config.read(config_file)
    return config

def check_file(file_name):
    print "Checking " + file_name + "...",
    test(os.path.exists(file_name))

def check_vlan(config):
    bold('Checking VLAN ...')
    check_file(config.get('vlan', 'ifconfigCmd'))
    check_file(config.get('vlan', 'vconfigCmd'))
    check_file(config.get('vlan', 'brctlCmd'))
    print

def check_repository(config):
    pass

if __name__ == '__main__':
    config = read_config('/home/ibarrera/abiquo-aim.ini')
    check_vlan(config)

