#!/usr/bin/env ruby

require 'logger'

class Log

    def self.debug(msg)
      instance.debug msg
      puts msg
    end

    def self.info(msg)
      puts msg
      instance.info msg
    end

    def self.error(msg)
      instance.error msg
      puts msg
    end

    def self.warn(msg)
      instance.warn msg
      puts msg
    end

    def self.instance(file = '/var/log/abiquo-community-installer.log')
      begin
        @@logger ||= Logger.new file
      rescue Exception
        @@logger ||= Logger.new $stderr
      end
    end

end

def check_dist(dist)
    if dist != "ubuntu" and dist != "centos"
        raise Exception.new("Only supports 'ubuntu' and 'centos'")
    end
    dists = { "ubuntu" => `cat /etc/issue`.include?("Ubuntu"), "centos" => `cat /etc/issue`.include?("CentOS") }
    return dists[dist]
end

def enable_services
    Log.info 'Enabling services...'
    
    ["rabbitmq-server","redis","mysqld"].each do |s|
        out = `chkconfig #{s} on 2>&1`
        if $?.exitstatus != 0
            Log.error "An error ocurred when enabling services!"
            raise Exception.new(out)
        end
    end
    
    Log.info "All services enabled correctly"
end


def start_services
    Log.info 'Starting services...'
    
    ["rabbitmq-server","redis","mysqld"].each do |s|
        out = `service #{s} restart 2>&1`
        if $?.exitstatus != 0
            Log.error "An error ocurred when starting services!"
            raise Exception.new(out)
        end
    end
    
    Log.info "All services started correctly"
end


def test_mysql_con(host="127.0.0.1", user="root", password="")
    cmd = ""

    if password.strip.chomp.empty? 
        cmd = "mysql -u #{user} "
    else
        cmd = "mysql -u #{user} -p#{password} "
    end

    `#{cmd} -e 'show databases' 2>&1 >/dev/null`
    if $?.exitstatus == 0 
      return true
    else
      return false
    end

end


def create_schemas(user = 'root', password = '')
    cmd = ''

    if password.strip.chomp.empty? 
        cmd = "mysql -u #{user} "
    else
        cmd = "mysql -u #{user} -p#{password} "
    end

    if `#{cmd} -e 'show databases'|grep kinton`.strip.chomp.empty?
        out = `#{cmd} < /usr/share/doc/abiquo-server-community/database/kinton-schema.sql 2>&1` if check_dist("centos")
        out = `zcat /usr/share/doc/abiquo-server/database/kinton-schema.sql.gz | #{cmd} 2>&1` if check_dist("ubuntu")
        if $?.exitstatus == 0
            Log.info 'kinton-schema imported succesfully.'
        else
            Log.error "Error importing kinton-schema"
            raise Exception.new(out)
        end
    else
        Log.warn 'kinton schema found. Skipping schema creation.'
    end
end


def disable_iptables
    Log.info 'Disabling iptables...'
    
    out = `chkconfig iptables off 2>&1` if check_dist("centos")
    out = `iptables -F & iptables-save 2>&1` if check_dist("ubuntu")

    if $?.exitstatus == 0
        Log.info 'Disabled correctly'
    else
        Log.error "An error ocurred when disabling iptables"
        raise Exception.new(out)
    end
end


def disable_selinux
    Log.info 'Disabling SELinux...'
    
    out = `sed s/SELINUX=enabled/SELINUX=disabled/ /etc/sysconfig/selinux 2>&1`

    if $?.exitstatus == 0
        Log.info 'Disabled correctly'
    else
        Log.error "An error ocurred when disabling SELinux"
        raise Exception.new(out)
    end
end


def export_nfs
    Log.info 'Create /etc/exports'

    out = `mkdir -p /opt/vm_repository 2>&1`

    if $?.exitstatus == 0
        Log.info '/opt/vm_repository created'
    else
        Log.error "An error ocurred when creating /opt/vm_repository!"
        raise Exception.new(out)
    end
    
    File.open('/etc/exports','w') do |file|
        file.puts '/opt/vm_repository    *(rw,no_root_squash,subtree_check,insecure)'
        Log.info "/etc/exports updated"
    end
        
end

def config_abiquo
    Log.info "Configuring abiquo..."
    puts "Enter mysql user:"
    mysql_user = gets.strip.chomp
    puts "Enter mysql password:"
    mysql_pwd = gets.strip.chomp
    puts "Enter NFS repository ip (it needs to be visible for hypervisors, so 127.0.0.1 or localhost are not valid):"
    nfs_repo_ip = gets.strip.chomp

    out = test_mysql_con("127.0.0.1", mysql_user.delete('"', '&', '|', '\\'), mysql_pwd.delete('"', '&', '|', '\\'))
    if $?.exitstatus != 0
        Log.error "Mysql credentials are not valid. User: #{mysql_user}, Pass: #{mysql_pwd}"
        raise Exception.new(out)
    end

    if nfs_repo_ip == ("127.0.0.1" or "localhost")
        Log.error "Ip address cannot be #{nfs_repo_ip}"
        raise Exception.new
    end

    out = `ping -c 2 #{nfs_repo_ip} 2>&1 >/dev/null`    
    if $?.exitstatus != 0
        Log.error "Ip is not accessible"
        raise Exception.new(out)
    end

    #Modify api config
    ['/opt/abiquo/tomcat/conf/Catalina/localhost/api.xml', '/opt/abiquo/tomcat/webapps/api/META-INF/context.xml'].each do |file|
        if File.exists? file
            temp = ''
            File.open(file,'r') do |read|
                temp = read.read()
            end
            
            temp = temp.gsub("${server.database.username}","#{mysql_user}").gsub("${server.database.password}","#{mysql_pwd}")
            temp = temp.gsub("username=\"root\"","username=\"#{mysql_user}\"").gsub("password=\"root\"","password=\"#{mysql_pwd}\"")
            
            File.open(file,'w') do |write|
                write.puts temp
            end
        else
            puts "File #{file} does not exist. Ommiting"
        end
    end

    
    #Modify server config
    ['/opt/abiquo/tomcat/conf/Catalina/localhost/server.xml', '/opt/abiquo/tomcat/webapps/server/META-INF/context.xml'].each do |file|
        if File.exists? file
            temp = ''
            File.open(file,'r') do |read|
                temp = read.read()
            end
            
            temp = temp.gsub("username=\"root\"","username=\"#{mysql_user}\"").gsub("password=\"root\"","password=\"#{mysql_pwd}\"")
            
            File.open(file,'w') do |write|
                write.puts temp
            end
        else
            puts "File #{file} does not exist. Ommiting"
        end
    end
    
    
    #Modify abiquo.properties
    File.open('/opt/abiquo/config/abiquo.properties','w') do |parent_file|
        ['/opt/abiquo/config/examples/abiquo.properties.remoteservices','/opt/abiquo/config/examples/abiquo.properties.server'].each do |file|
            File.open(file,'r') do |file_read|
                if File.exists? file_read
                    temp = file_read.read.gsub("127.0.0.1:","#{nfs_repo_ip}:")
                    temp = temp.gsub("//127.0.0.1/","//#{nfs_repo_ip}/")
                    parent_file.puts temp
                else
                    Log.error "File #{file} doesn't exists. Ommiting this configuration."
                end
            end
         end
    end
    
    #Config sql
    create_schemas(mysql_user, mysql_pwd)
end


################ Main ################

if not `whoami`.match("root")
    puts "You need to be root in order to run this script"
    exit
end

Log.info "-" * 50
Log.info "Running Abiquo Community install..."

begin
    if check_dist("centos")
        enable_services()
        start_services()
        disable_selinux()
        `/etc/init.d/abiquo-tomcat stop`
    else
        `/etc/init.d/abiquo-core stop`
    end
    
    config_abiquo()
    disable_iptables()
    export_nfs()
    Log.info "Install finished"
rescue Exception => e
    Log.error "An exception ocurred: #{e.backtrace}"
    exit
end
Log.info "-" * 50
