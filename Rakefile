task :release do
  last_tag = `git tag`.split("\n").map {|t| t[1..-1]}[-1]
  version = "0.0." << (last_tag.split(".")[-1].to_i + 1).to_s

  sh "git tag -a v#{version} -m 'tagged version #{version}'"
  sh "git push origin master"
  sh "git push --tags"
end


task :default => :release
