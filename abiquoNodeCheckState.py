#!/usr/bin/env python

import ConfigParser
import os

def read_config(config_file):
    config = ConfigParser.ConfigParser()
    config.readfp(open(config_file))
    config.read(config_file)
    return config

def check_file(file_name):
    print file_name + "...",
    if os.path.exists(file_name):
        print "OK"
    else:
        print "MISSING"

def check_vlan(config):
    print "Checking VLAN ..."
    check_file(config.get('vlan', 'ifconfigCmd'))
    check_file(config.get('vlan', 'vconfigCmd'))
    check_file(config.get('vlan', 'brctlCmd'))
    print

if __name__ == '__main__':
    config = read_config('/home/ibarrera/abiquo-aim.ini')
    check_vlan(config)

