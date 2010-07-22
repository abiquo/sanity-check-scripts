class ConfigParser
  attr_reader :params, :groups

  def initialize(file)
    @file = file
    @params = {}
    @groups = []
  end

  def import_config
    group = nil
    open(@file).each do |line| 
      line.strip!
      unless (/^\#/.match(line))
        if(/\s*=\s*/.match(line))
          param, value = line.split(/\s*=\s*/, 2)  
          var_name = "#{param}".chomp.strip
          value = value.chomp.strip
          new_value = ''
          if (value)
            if value =~ /^['"](.*)['"]$/
              new_value = $1
            else
              new_value = value
            end
          else
            new_value = ''
          end 

          if group
            add_to_group(group, var_name, new_value)
          else
            add(var_name, new_value)
          end
          
        elsif(/^\[(.+)\]$/.match(line).to_a != [])
          group = /^\[(.+)\]$/.match(line).to_a[1]
          add(group, {})
          
        end
      end
    end   
  end

  def add(param_name, value)
    if value.class == Hash
      if @params.has_key?(param_name)
        if @params[param_name].class == Hash
          @params[param_name].merge!(value)
        elsif @params.has_key?(param_name)
          if @params[param_name].class != value.class
            raise ArgumentError, "#{param_name} already exists, and is of different type!"
          end
        end
      else
        @params[param_name] = value
      end
      if ! @groups.include?(param_name)
        @groups.push(param_name)
      end
    else
      @params[param_name] = value
    end
  end

  def add_to_group(group, param_name, value)
    if ! @groups.include?(group)
      add(group, {})
    end
    @params[group][param_name] = value
  end
end

if $0 == __FILE__
  c = ConfigParser.new(ARGV[0])
  c.import_config

  p "PARAMS", c.params
  p "GROUPS", c.groups
end
