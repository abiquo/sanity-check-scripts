#!/bin/bash
dir=`dirname $0`

java -jar $dir/jruby/jruby-complete-1.5.1.jar $dir/server_check_state/server_check_state.rb
