#!/usr/bin/env python
#
#  script to check the abiquo's server machine has all dependencies configured
#

import os
import sys
import re
import commands
import ConfigParser
from tempfile import NamedTemporaryFile

TOMCAT_PATH = '/opt/abiquo-server/tomcat'
ABIQUO_SERVER_PATH = '/opt/abiquo-server'


def green(message):
  return '\033[1;32m' + message + '\033[0m'

def red(message):
  return "\033[1;31m" + message + "\033[0m"

if os.path.exists(ABIQUO_SERVER_PATH) == False:
  print red("\nThis host is not an Abiquo Server. Aborting\n")
  sys.exit(0)

#                  #
# check JNDI names #
#                  #

out = 'checking JNDI: '
err = False

bpmContextFile = '%s/conf/Catalina/localhost/bpm-async.xml'
if os.path.exists(bpmContextFile) == False:
  bpmContextFile = '%s/webapps/bpm-async/META-INF/context.xml'
 
jndiFile = open(bpmContextFile % TOMCAT_PATH).read()
try:

  if re.search('name="jdbc/abiquoBpmDB"', jndiFile) == None:
    out += red('\n\tJNDI is not properly configured. Check that `%s` includes the name `jdbc/abiquoBpmDB`' % bpmContextFile)
    err = True

  serverContextFile = '%s/conf/Catalina/localhost/server.xml'
  if os.path.exists(serverContextFile) == False:
    serverContextFile = '%s/webapps/server/META-INF/context.xml'

  jndiFile = open(serverContextFile % TOMCAT_PATH).read()

  if re.search('name="jdbc/abiquoDB"', jndiFile) == None:
    out += red('\n\tJNDI is not properly configured. Check that `%s` includes the name `jdbc/abiquoDB`' % serverContextFile)
    err = True
except IOError,io:
  out += red('File not found: ' + io.filename)
  err = True

if err == False:
  out += green('OK')
print out

#                                           #
# check database connection and credentials #
#                                           #

dbUsername, dbPassword = re.search(r'username="([^"]+)"\s+password="([^"]+)"', jndiFile).groups()

dbSearch = re.search(r'url="[^:]+:[^:]+://(?P<host>[^:]+)(:(?P<port>[^/]+))?/(?P<schema>.+)\?.+"', jndiFile)
dbHost = dbSearch.group('host')
dbPort = dbSearch.group('port')
if dbPort == None:
  dbPort = '3306'
dbSchema = dbSearch.group('schema')

out = 'checking Database: '
err = False

status = commands.getoutput('sudo service mysql status')
if re.search('stopped', status) != None:
  out += red('\n\tMysql service is not running')
  err = True
else:
  dbOut = commands.getoutput('mysql -u%s -p%s -h%s -P%s -e "use %s"' % (dbUsername, dbPassword, dbHost, dbPort, dbSchema))
  if dbOut != None and dbOut != '':
    out += red('\n\t' + dbOut)
    err = True

if err == False:
  out += green('OK')
print out

#           #
# check nfs #
#           #

out = 'checking NFS: '
err = False

status = commands.getoutput('service nfs status')
if re.search('nfsd running', status) == None:
  out += red('\n\tNfs service is not running')
  err = True

exportfs = commands.getoutput('sudo exportfs')
nfsCredentials = False

nfsExported = re.search('.*/opt/vm_repository\s*<world>', exportfs)
for line in open('/etc/exports'):
  if re.search('^/opt/vm_repository.+rw', line):
    nfsCredentials = True
    break

if nfsExported == None:
  out += red('\n\tseems nfs is not exported, check `sudo exportfs` and make sure /opt/vm_repository is exported as <world>')
  err = False
if nfsCredentials == False:
  out += red('\n\tseems nfs is not in the exports file, make sure /etc/exports includes /opt/vm_repository and it has rw access')
  err = False

if err == False:
  out += green('OK')
print out

#             #
# check samba #
#             #

out = 'checking Samba: '
err = False

status = commands.getoutput('service smb status')
if re.search('nfsd running', status) == None:
  out += red('\n\tSamba service is not running')
  err = True

tmp = NamedTemporaryFile(delete = False)
try:
  smbConf = ''
  for line in open('/etc/samba/smb.conf'):
    smbConf += re.sub(r'^\s+', '', line)

  tmp.write(smbConf)
  tmp.close()

  config = ConfigParser.ConfigParser()
  config.readfp(open(tmp.name))

  if config.has_section('vm_repository') == False:
    out += red("\n\tsmb.conf doesn't include the section [vm_repository]")
    err = True
  else:
    if config.has_option('vm_repository', 'path') == False or config.get('vm_repository', 'path') != '/opt/vm_repository':
      out += red('\n\tpath element into [vm_repository] should be `/opt/vm_repository`')
      err = True
    if config.has_option('vm_repository', 'guest ok') == False or config.get('vm_repository', 'guest ok') != 'yes':
      out += red('\n\tguest ok element into [vm_repository] should be `yes`')
      err = True
    if config.has_option('global', 'security') == False or config.get('global', 'security') != 'shared':
      out += red('\n\tsecurity element into [global] should be `shared`')
      err = True
except ConfigParser.ParsingError,ex:
  err = True
  out += red('can not parse /etc/samba/smb.conf')
  print ex
except IOError,io:
  out += red('File not found: ' + io.filename)
  err = True
os.unlink(tmp.name)
if err == False:
  out += gree('OK')
print out

#                        #
# check bpm dependencies #
#                        #

out = 'checking Bpm dependencies: '
err = False

vboxManage = commands.getoutput('VBoxManage -v')
if re.search(r'not found', vboxManage) != None:
  out += red("\n\tVBoxManage is not installed")
  err = True

if err == False:
  vboxVersion = re.search(r'3\.1\.(\d+)', vboxManage)
  if vboxVersion == None or int(vboxVersion.groups()[0]) < 4:
    out += red("\n\tVboxManage version must be 3.1.4 or avobe")
    err = True

diskManager = commands.getoutput('v2v-diskmanager')
if re.search(r'not found', diskManager) != None:
  out += red('\n\tv2v-diskmanager script is not installed')
  err = True

mechadora = commands.getoutput('mechadora')
if re.search('mechadora: command not found', mechadora) != None:
  out += red('\n\tmechadora script not found')
  err = True
else:
  show = False
  for line in mechadora.split("\n"):
    if show == True:
      out += red('\n\t\t' + line)
      show = False
    if re.search('\[!\]', line):
      out += red('\n\tMechadora warnings:')
      out += red('\n\t\t' + line)
      show = True
      err = True

qemu = commands.getoutput('qemu-img --version')
if re.search('not found', qemu) != None:
  out += red('\n\tqemu-img: command not found')
  err = True
else:
  version = re.search('qemu-img version (\d+)\.(\d+)\.(\d+)', qemu).groups()
  if int(version[0]) == 0 and int(version[1]) < 10:
    out += red("\n\tqemu-img version must be 0.10 or avove")
    err = True
  
if err == False:
  out += green('OK')
print out

#           #
# check MTA #
#           #

out = 'checking MTA: '
err = False

status = commands.getoutput('netstat -tnlp | grep ":25"')
if status == None or status == '':
  out += red('\n\tMTA is not configured in the port 25')
  err = True

if err == False:
  out += green('OK')
print out

#                   #
# check DHCP server #
#                   #

out = 'cheching DHCP: '
err = False

try:
  status = commands.getoutput('service dhcpd status')
  if re.search('stopped', status) != None:
    out += red('\n\tDHCP service is not running')
    err = True
  else:
    dhcpd = open('/etc/dhcpd.conf').read()
    if re.search(r'omapi\-port\s+7911', dhcpd) == None:
      out += red('\n\tOmapi port is not configured in `/etc/dhcpd.conf`. Check this file contains `omapi-port 7911`')
      err = True
except IOError,io:
  out += red('\n\tfile not found: ' + io.filename)
  err = True

if err == False:
  out += green('OK')
print out

#               #
# check SELinux #
#               #

out = 'checking SELinux: '
err = False

status = commands.getoutput('ls -A /selinux')
if status != None and status != '':
  out += red('SELinux is ENABLED. It must be DISABLED')
  err = True

if err == False:
  out += green('OK')
print out

#                          #
# check event sync address #
#                          #

out = 'checking Event sync address: '
err = False

try:
  serverConfig = open('%s/webapps/server/WEB-INF/classes/conf/config.xml' % TOMCAT_PATH).read()
  addr = re.search(r'<(eventSinkAddress)>(.+)</\1>', serverConfig).groups()[1]
  addr = re.search(r'http://([^:/]+)', addr).group(1)

  if addr == 'localhost':
    out += red('\n\tEvent sync address can not be `localhost`')
    err = True
  else:
    ifconfig = commands.getoutput("ifconfig |grep 'inet addr:'").split("\n")
    addrFound = False
    for line in ifconfig:
      if re.search('addr:%s' % addr, line) != None:
        addrFound = True
        break

    if addrFound == False:
      out += red('\n\tEvent sync address not found. Ensure `%s` is configured as a host address.' % addr)
      err = True
except IOError,io:
  out += red('File not found: ' + io.filename)
  err = True

if err == False:
  out += green('OK')
print out

