#!/bin/bash
dir=`dirname $0`

java -jar $dir/jruby/jruby-complete-1.5.1.jar $dir/configuration_properties_update/configuration_properties_update.rb $@
