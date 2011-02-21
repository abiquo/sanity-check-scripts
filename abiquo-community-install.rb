#!/usr/bin/env ruby

def check_dist(dist)
    if dist != "ubuntu" and dist != "centos"
        raise Exception.new "Only supports 'ubuntu' and 'centos'" if dist != ("ubuntu" and "centos")
    end
    dists = { "ubuntu" => `cat /etc/issue`.include?("Ubuntu"), "centos" => `cat /etc/issue`.include?("CentOS") }
    return dists[dist]
end

def enable_services
    puts 'Enabling services...'
    
    ["rabbitmq-server","redis","mysqld"].each do |s|
        out = `chkconfig #{s} on 2>&1`
        if $?.exitstatus != 0
            puts "An error ocurred when enabling services!"
            raise Exception.new out
        end
    end
    
    puts "All services enabled correctly"
end


def start_services
    puts 'Starting services...'
    
    ["rabbitmq-server","redis","mysqld"].each do |s|
        out = `service #{s} restart 2>&1`
        if $?.exitstatus != 0
            puts "An error ocurred when starting services!"
            raise Exception.new out
        end
    end
    
    puts "All services started correctly"
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
    out = `mysql -u #{user} < /usr/share/doc/abiquo-server-community/database/kinton-schema.sql 2>&1`
    if $?.exitstatus == 0
        puts 'kinton-schema imported succesfully.'
    else
        puts "Error importing kinton-schema"
        raise Exception.new out
    end
  else
    puts 'kinton schema found. Skipping schema creation.'
  end
end


def disable_iptables
    puts 'Disabling iptables...'
    
    out = `chkconfig iptables off 2>&1` if check_dist("centos")
    out = `iptables -F & iptables-save 2>&1` if check_dist("ubuntu")

    if $?.exitstatus == 0
        puts 'Disabled correctly'
    else
        puts "An error ocurred when disabling iptables!"
        raise Exception.new out 
    end
end


def disable_selinux

    return if check_dist("ubuntu")

    puts 'Disabling SELinux...'
    
    out = `sed s/SELINUX=enabled/SELINUX=disabled/ /etc/sysconfig/selinux 2>&1`

    if $?.exitstatus == 0
        puts 'Disabled correctly'
    else
        puts "An error ocurred when disabling SELinux!"
        raise Exception.new out
    end
end


def export_nfs
    puts 'Create /etc/exports'

    out = `mkdir -p /opt/vm_repository 2>&1`

    if $?.exitstatus == 0
        puts '/opt/vm_repository created'
    else
        puts "An error ocurred when creating /opt/vm_repository!"
        raise Exception.new out
    end
    
    begin
        file = File.open('/etc/exports','w')
        file.puts '/opt/vm_repository    *(rw,no_root_squash,subtree_check,insecure)'
        file.close
        puts "/etc/exports updated"
    rescue Exception => e
        puts "An exception ocurred when configuring /etc/exports: #{e}"
        raise e
    end
        
end

def config_abiquo
    puts "Enter mysql user:"
    mysql_user = gets.strip.chomp
    puts "Enter mysql password:"
    mysql_pwd = gets.strip.chomp
    puts "Enter NFS repository ip (it needs to be visible for hypervisors, so 127.0.0.1 or localhost are not valid):"
    nfs_repo_ip = gets.strip.chomp

    if not test_mysql_con("127.0.0.1", mysql_user.delete('"', '&', '|', '\\'), mysql_pwd.delete('"', '&', '|', '\\'))
        puts "Mysql credentials are not valid. User: #{mysql_user}, Pass: #{mysql_pwd}"
        return
    end

    if nfs_repo_ip == ("127.0.0.1" or "localhost")
        puts "Ip address cannot be #{nfs_repo_ip}"
        return
    end

    `ping -c 2 #{nfs_repo_ip} 2>&1 >/dev/null`    
    if $?.exitstatus != 0
        puts "Ip is not accessible"
        return
    end

    #Modify /opt/abiquo/tomcat/webapps/api/WEB-INF/classes/tomcat/META-INF/context.xml or tomcat/conf/... if already deployed
    ['/opt/abiquo/tomcat/conf/Catalina/localhost/api.xml', '/opt/abiquo/tomcat/webapps/api/WEB-INF/classes/tomcat/META-INF/context.xml'].each do |file|
        begin
            read = File.open(file,'r')
            if File.exists? read
                temp = read.read.gsub("${server.database.username}","#{mysql_user}").gsub("${server.database.password}","#{mysql_pwd}")
                temp = temp.gsub("username=\"root\"","username=\"#{mysql_user}\"").gsub("password=\"root\"","password=\"#{mysql_pwd}\"")
                read.close
                write = File.open(file,'w')
                write.truncate(0)
                write.puts temp
                write.close
            else
                puts "File #{file} doesn't exists. Ommiting this configuration."
            end
        rescue Exception => e
            puts "An exception ocurred when manipulating config files: #{e}"
            raise e
        end
    end
    
    #Modify /opt/abiquo/tomcat/webapps/server/WEB-INF/classes/tomcat/META-INF/context.xml or tomcat/conf/... if already deployed
    ['/opt/abiquo/tomcat/conf/Catalina/localhost/server.xml', '/opt/abiquo/tomcat/webapps/server/WEB-INF/classes/tomcat/META-INF/context.xml'].each do |file|
        begin
            read = File.open(file,'r')
            if File.exists? read
                temp = read.read.gsub("username=\"root\"","username=\"#{mysql_user}\"").gsub("password=\"root\"","password=\"#{mysql_pwd}\"")
                read.close
                write = File.open(file,'w')
                write.truncate(0)
                write.puts temp
                write.close
            else
                puts "File #{file} doesn't exists. Ommiting this configuration."
            end
        rescue Exception => e
            puts "An exception ocurred when manipulating config files: #{e}"
            raise e
        end
    end
    
    
    #Modify abiquo.properties
    begin
        parent_file = File.open('/opt/abiquo/config/abiquo.properties','w')
        ['/opt/abiquo/config/examples/abiquo.properties.remoteservices','/opt/abiquo/config/examples/abiquo.properties.server'].each do |file|
            file_read = File.open(file,'r')
            if File.exists? file_read
                temp = file_read.read.gsub("127.0.0.1:","#{nfs_repo_ip}:")
                temp = temp.gsub("//127.0.0.1/","//#{nfs_repo_ip}/")
                file_read.close
                parent_file.puts temp
            else
                puts "File #{file} doesn't exists. Ommiting this configuration."
            end
         end
         parent_file.close
    rescue Exception => e
        puts "An exception ocurred when manipulating abiquo.properties config file: #{e}"
        raise e
    end
    
    
    #Config sql
    create_schemas(mysql_user, mysql_pwd)
end


################ Main ################
puts "Running Abiquo Community install..."



if check_dist("centos")
    enable_services()
    start_services()
end
config_abiquo()
disable_iptables()
disable_selinux()
export_nfs()


puts "Install finished"
