task :release do
  last_tag = `git tag`.split("\n").map {|t| t[1..-1].split(".")[-1].to_i}.sort[-1]
  version = "0.0." << (last_tag + 1).to_s

  sh "git tag -a v#{version} -m 'tagged version #{version}'"
  sh "git push origin master"
  sh "git push --tags"
end

task :build_srpm do
  rpmver = ""
  File.readlines("abiquo-server-tools.spec").each do |l|
    if l =~ /Version:/
      rpmver = l.split(":").last.strip
    end
  end
  if not File.directory?("#{ENV['HOME']}/rpmbuild")
    $stderr.puts "~/rpmbuild dir not found. Use rpmdev-setuptree."
    exit
  end
  `mkdir ~/rpmbuild/SOURCES/abiquo-server-tools-#{rpmver}`
  `cp -r * ~/rpmbuild/SOURCES/abiquo-server-tools-#{rpmver}`
  `tar -C ~/rpmbuild/SOURCES/ -czf ~/rpmbuild/SOURCES/abiquo-server-tools-#{rpmver}.tar.gz abiquo-server-tools-#{rpmver}`
  `rpmbuild -bs abiquo-server-tools.spec`
end


task :default => :release
