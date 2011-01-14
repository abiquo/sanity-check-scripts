require 'open-uri'
require 'java'

ABIQUO_SERVER_PATH = ENV['ABIQUO_HOME'] || '/opt/abiquo'
CONFIG_PATH = "#{ABIQUO_SERVER_PATH}/config"
TOMCAT_PATH = "#{ABIQUO_SERVER_PATH}/tomcat"

@err = []

def green(message); "\033[1;32m#{message}\033[0m"; end
def red(message); "\033[1;31m#{message}\033[0m"; end
def yellow(message); "\033[1;33m#{message}\033[0m"; end

def print_check
  if @err.empty?
    print green("OK\n")
  else
    puts "\n" << @err.join("\n")
  end
  @err = []
end

def check_service(name, command = name.downcase, error = true)
  commands = Array[command]
  status = commands.each do |command|
    status = `service #{command} status 2> /dev/null` rescue @err << red("\t#{$!.message}")
    break true if status && status =~ /running/
  end

  error_message = error ? 'red' : 'yellow'
  @err << send(error_message, "\t#{name} is not running") unless status
  !status
end

def tomcat_file(file); file % TOMCAT_PATH; end

unless File.exist? ABIQUO_SERVER_PATH
  puts red("\nCan't find the Abiquo Server's path: #{ABIQUO_SERVER_PATH}. Aborting\n")
  exit 1
end

unless File.exist? TOMCAT_PATH
  puts red("\nCan't find the Tomcat's path: #{TOMCAT_PATH}. Aborting\n")
  exit 1
end

def validate(message)
  print message
  yield
  print_check
end

#                  #
# check JNDI names #
#                  #

def check_jndi(file, replacement, regex)
  file = replacement unless File.exist?(file)
  io = File.read(file)
  unless %r{#{regex}} =~ io
    @err << red("\tJNDI is not properly configured. Check that `#{file}` includes the name `#{regex}`")
  end
  file
rescue
  @err << red("File not found: #{ARGF.filename}. #{$!.message}")
  ARGF.filename
end

def check_database(file)
  if file.nil? || !File.exist?(file)
    @err << red("\tFile not found: #{file}")
    return
  end

  io = File.read(file)
  username, password = %r{username="([^"]+)"\s+password="([^"]*)}.match(io)[1, 2]
  host, port, schema = %r{url="[^:]+:[^:]+://([^:]+)(?::([^/]+))?/([^?]+)(\?.+)?"}.match(io)[1..3]
  port ||= '3306'

  return unless check_service('Mysql', 'mysqld')

  password = "-p#{password}" unless password.empty?
  db_status = `mysql -u#{username} #{password} -h#{host} -P#{port} -e "use #{schema}"`
  @err << ref("\t#{db_status}") unless db_status.empty?
end

server_file = nil
validate 'checking JNDI: ' do
  server_file = check_jndi tomcat_file('%s/conf/Catalina/localhost/server.xml'), tomcat_file('%s/webapps/server/META-INF/context.xml'), 'jdbc/abiquoDB'
end

#                                           #
# check database connection and credentials #
#                                           #

validate 'Checking Server database credentials: ' do
  check_database(server_file)
end

#           #
# check nfs #
#           #

validate 'Checking NFS: ' do
  unless check_service('NFS', %w{nfs nfsd}, false)
    unless File.read('/etc/exports') =~ %r{/opt/vm_repository.+rw}
      @err << red("\tseems nfs is not in the exports file, make sure /etc/exports includes /opt/vm_repository and it has rw access")
    end

    unless `exportfs` =~ %r{^/opt/vm_repository}
      @err << red("\tseems nfs is not exported, check `exportfs` and make sure /opt/vm_repository is exported")
    end
  end
end

validate 'Checking Samba: ' do
  unless check_service('Samba', %w{smb smbd}, false)
    require File.expand_path('config_parser', File.dirname(__FILE__))

    parser = ConfigParser.new('/etc/samba/smb.conf')
    begin
      parser.import_config

      unless parser.groups.include? 'vm_repository'
        @err << red("\tsmb.conf doesn't include the section [vm_repository]")
      else
        unless '/opt/vm_repository' == parser.params["vm_repository"]["path"]
          @err << red("\tpath element into [vm_repository] should be `/opt/vm_repository`")
        end
        unless 'yes' == parser.params['vm_repository']['guest ok']
          @err << red("\tguest ok element into [vm_repository] should be `yes`")
        end
        unless 'share' == parser.params['global']['security']
          @err << red("\tsecurity element into [global] should be `share`")
        end
      end
    rescue
      @err << red("\tFile not found: #{ARGF.filename}. #{$!.message}")
    end
  end
end

#                                 #
# check bpm external dependencies #
#                                 #

validate 'Checking Bpm external dependencies: ' do
  vbox_manage = `VBoxManage -v` rescue @err << yellow("\tVBoxManage is not installed")

  unless vbox_manage.empty?
    if match = %r{(d+)\.(d+)\.(d+)}.match(vbox_manage)
      major, minor, patch = [1..3].map {|v| v.to_i}
      if major < 3 || (major == 3 && minor < 1) || (major == 3 && minor == 1 && patch < 4)
        @err << red("\tVboxManage version must be 3.1.4 or avobe")
      end
    end
  end

  unless `which v2v-diskmanager` =~ /v2v-diskmanager$/
    @err << red("\tv2v-diskmanager script is not installed")
  end

  unless `which mechadora` =~ /mechadora$/
    @err << red("\tmechadora script is not installed")
  else
    show = false
    `mechadora`.split("\n").each do |line|
      if show
        @err << red("\t\t#{line}")
        show = false
      elsif line =~ %r{[!]}
        @err << red("\tMechadora warnings:")
        @err << red("\t\t#{line}")
        show = true
      end
    end
  end
end

#           #
# check MTA #
#           #

validate 'Checking MTA: ' do
  unless `netstat -tnlp | grep ":25"`
    @err << red("\tMTA is not configured in the port 25")
  end
end

#                   #
# check DHCP server #
#                   #

validate 'Checking DHCP: ' do
  unless check_service('DHCP', 'dhcpd', false)
    begin
      unless File.read('/etc/dhcpd.conf') =~ /omapi-port\s+7911/
        @err << red("\tOmapi port is not configured in `/etc/dhcpd.conf`. Check this file contains `omapi-port 7911`")
      end
    rescue
      @err << red("\tFile not found: #{ARGF.filename}. #{$!.message}")
    end
  end
end

#               #
# check SELinux #
#               #

validate 'Checking SELinux: ' do
  @err << red("\tSELinux is ENABLED. It must be DISABLED") unless `ls -A /selinux`.empty?
end
