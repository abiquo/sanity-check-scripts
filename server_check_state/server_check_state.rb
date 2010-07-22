ABIQUO_SERVER_PATH = '/opt/abiquo-server'
TOMCAT_PATH = "#{ABIQUO_SERVER_PATH}/tomcat"

@err = []

def green(message); "\033[1;32m#{message}\033[0m"; end
def red(message); "\033[1;31m#{message}\033[0m"; end

def print_check
  if @err.empty? 
    print green("OK\n")
  else 
    puts "\n" << @err.join("\n")
  end
  @err = []
end

def check_service(name, command = name.downcase)
  status = `service #{command} status 2> /dev/null` rescue @err << red("\t#{$!.message}")
  @err << red("\t#{name} is not running") unless status.nil? || status =~ /running/
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
end

def check_database(file)
  if file.nil? || !File.exist?(file)
    @err << red("\tFile not found: #{file}")
    return
  end

  io = File.read(file)
  username, password = %r{username="([^"]+)"\s+password="([^"]*)}.match(io)[1, 2]
  host, port, schema = %r{url="[^:]+:[^:]+://([^:]+)(?::([^/]+))?/(.+)(\?.+)?"}.match(io)[1..3]
  port ||= '3306'

  return unless check_service('Mysql')

  password = "-p#{password}" unless password.empty?
  db_status = `mysql -u#{username} #{password} -h#{host} -P#{port} -e "use #{schema}"`
  @err << ref("\t#{db_status}") unless db_status.empty?
end

bpm_file = nil
server_file = nil
validate 'checking JNDI: ' do
  bpm_file = check_jndi tomcat_file('%s/conf/Catalina/localhost/bpm-async.xml'), tomcat_file('%s/webapps/bpm-async/META-INF/context.xml'), 'jdbc/abiquoBpmDB'
  server_file = check_jndi tomcat_file('%s/conf/Catalina/localhost/server.xml'), tomcat_file('%s/webapps/server/META-INF/context.xml'), 'jdbc/abiquoDB'
end

#                                           #
# check database connection and credentials #
#                                           #


validate 'Checking Bpm database credentials: ' do
  check_database(bpm_file)
end

validate 'Checking Server database credentials: ' do
  check_database(server_file)
end

#           #
# check nfs #
#           #

validate 'Checking NFS: ' do
  unless check_service('NFS', 'nfsd')
    unless File.read('/etc/exports') =~ %r{/opt/vm_repository.+rw}
      @err << red("\tseems nfs is not in the exports file, make sure /etc/exports includes /opt/vm_repository and it has rw access")
    end

    unless `exportfs` =~ %r{^/opt/vm_repository}
      @err << red("\tseems nfs is not exported, check `exportfs` and make sure /opt/vm_repository is exported")
    end
  end
end

validate 'Checking Samba: ' do
  unless check_service('Samba', 'smbd')
    require File.expand_path('config_parser', file.dirname(__FILE__))
  
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
  vbox_manage = `VBoxManage -v` rescue @err << red("\tVBoxManage is not installed")

  unless vbox_manage.empty?
    match = %r{(d+)\.(d+)\.(d+)}.match(vbox_manage)
    unless match
      @err << red("\tVBoxManage is not properly configured, the kernel module is not loaded")
    else
      major, minor, patch = [1..3].map {|v| v.to_i}
      if major < 3 || (major == 3 && minor < 1) || (major == 3 && minor == 1 && patch < 4)
        @err << red("\tVboxManage version must be 3.1.4 or avobe")
      end
    end
  end

  unless `which v2v-diskmanager` =~ /v2v-diskmanager$/
    @err << "\tv2v-diskmanager script is not installed"
  end

  unless `which mechadora` =~ /mechadora$/
    @err << "\tmechadora script is not installed"
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
  unless check_service('DHCP', 'dhcpd')
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

#                          #
# check event sync address #
#                          #

validate 'checking Event sync address: ' do
  begin
    server_config = File.read(tomcat_file('%s/webapps/server/WEB-INF/classes/conf/config.xml'))
    addr = %r{<(eventSinkAddress)>http://([^:/]+).*</\1>}
    if addr == 'localhost'
      @err << red("\tEvent sync address can not be `localhost`")
    else
      if `ifconfig | grep "inet addr:"`.split("\n").map {|line| line == "addr:#{addr}"}.empty?
        @err << red("\tEvent sync address not found. Ensure `#{addr}` is configured as a host address.")
      end
    end
  rescue
    @err << red("\tFile not found: #{ARGF.filename}. #{$!.message}")
  end
end