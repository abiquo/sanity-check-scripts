require 'rexml/document'
require 'rexml/xpath'
include REXML

ABIQUO_HOME = ENV['ABIQUO_HOME'] || '/opt/abiquo'
TOMCAT_HOME = ENV['CATALINA_HOME'] || "#{ABIQUO_HOME}/tomcat"
ABIQUO_TOMCAT_CONFIG = "file:/#{TOMCAT_HOME}/lib/abiquo-tomcat.jar!/abiquo.properties"

CONFIG_HOME = ENV['ABIQUO_CONFIG_HOME'] || "#{ABIQUO_HOME}/config"
ABIQUO_PROPERTIES = ENV['ABIQUO_PROPERTIES'] || "#{CONFIG_HOME}/abiquo.properties"
SERVER_CONFIG = "#{CONFIG_HOME}/server.xml"
AM_CONFIG = "#{CONFIG_HOME}/am.xml"
VIRTUAL_FACTORY_CONFIG = "#{CONFIG_HOME}/virtualfactory.xml"

class REXML::Element
  def xpath(path)
    (elem = XPath.first(self, path) and elem.text)
  end

  def attr(path)
    (elem = XPath.first(self, path) and elem.value)
  end
end

puts 'Starting configuration migration'

custom_properties = {}
########################
# server configuration #
########################
if File.exist? SERVER_CONFIG
  puts '-- server.xml found reading its configuration properties'

  xml = Document.new(File.open(SERVER_CONFIG)).root
  custom_properties["abiquo.server.timeout"] = xml.xpath("./timeout")
  custom_properties["abiquo.server.sessionTimeout"] = xml.xpath('./sessionTimeout')
  custom_properties["abiquo.server.virtualCpuPerCore"] = xml.xpath('./virtualCpuForCore')
  custom_properties['abiquo.server.eventSinkAddress'] = xml.xpath('./eventSinkAddress')
  custom_properties['abiquo.server.api.location'] = xml.xpath('./apiLocation')
  custom_properties['abiquo.server.remoteSpace.default'] = xml.xpath('./repositorySpace')
  custom_properties['abiquo.server.mail.server'] = xml.xpath('./mail/server')
  custom_properties['abiquo.server.mail.user'] = xml.xpath('./mail/user')
  custom_properties['abiquo.server.mail.password'] = xml.xpath('./mail/password')
  custom_properties['abiquo.server.networking.vlanPerVdc'] = xml.xpath('./networking/vlanPerVDC')

  %w{cpu ram hd storage repository publicVLAN publicIP}.each do |limit|
    %w{hard soft}.each do |type|
      custom_properties["abiquo.server.resourcelimits.#{limit}.#{type}"] = xml.attr("./resourceAllocationLimit/#{limit}/@#{type}")
    end
  end
end

####################
# am configuration #
####################
if File.exist? AM_CONFIG
  puts '-- am.xml found reading its configuration properties'

  xml = Document.new(File.open(AM_CONFIG)).root
  custom_properties['abiquo.appliancemanager.localRepositoryPath'] = xml.xpath('./repository/path')
  custom_properties['abiquo.appliancemanager.repositoryLocation'] = xml.xpath('./repository/location')
  custom_properties['abiquo.appliancemanager.deploy.timeout'] = xml.xpath('./deploy/timeout')
  custom_properties['abiquo.appliancemanager.upload.progressInterval'] = xml.xpath('./upload/progressInterval')
end

#################################
# virtual factory configuration #
#################################
if File.exist? VIRTUAL_FACTORY_CONFIG
  puts '-- virtualfactory.xml found reading its configuration properties'

  xml = Document.new(File.open(VIRTUAL_FACTORY_CONFIG)).root
  custom_properties['abiquo.virtualfactory.hyperv.destinationRepositoryPath'] = xml.xpath('./hypervisors/hyperv/destinationRepositoryPath')
  custom_properties['abiquo.virtualfactory.xenserver.repositoryLocation'] = xml.xpath('./hypervisors/xenserver/abiquoRepository')
  custom_properties['abiquo.virtualfactory.vmware.sandatastore'] = xml.attr('./hypervisors/vmware/SanDatastore/@name')
  custom_properties['abiquo.virtualfactory.storagelink.address'] = xml.xpath('./storagelink/address')
  custom_properties['abiquo.virtualfactory.storagelink.user'] = xml.xpath('./storagelink/user')
  custom_properties['abiquo.virtualfactory.storagelink.password'] = xml.xpath('./storagelink/password')
end

puts '---'
puts '--- checking modified options with the default ones'

default_properties = {}
File.open(ABIQUO_TOMCAT_CONFIG).each("\n") do |line|
  unless line.chop.empty?
    key, value = line.chop.split('=')
    default_properties[key] = value
  end
end

most_used = %w{
abiquo.server.sessionTimeout
abiquo.server.virtualCpuPerCore
abiquo.server.mail.server
abiquo.server.eventSinkAddress
abiquo.appliancemanager.localRepositoryPath
abiquo.appliancemanager.repositoryLocation
abiquo.virtualfactory.hyperv.destinationRepositoryPath
abiquo.virtualfactory.xenserver.repositoryLocation
abiquo.virtualfactory.storagelink.address
}

modified_properties = {}
default_properties.each do |key, value|
  if custom_properties[key] && custom_properties[key] != default_properties[key] ||
      most_used.include?(key)
    modified_properties[key] = custom_properties[key]
  end
end

unless modified_properties.empty?
  puts '---'
  puts "--- found #{modified_properties.size} modified configuration options, saving them into #{ABIQUO_PROPERTIES}"

  File.open(ABIQUO_PROPERTIES, 'w') do |file|
    modified_properties.each do |key, value|
      file.write("#{key}=#{value}\n")
    end
  end
end

puts 'Done.'
