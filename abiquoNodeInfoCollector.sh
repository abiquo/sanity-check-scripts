#!/bin/bash
dir=`dirname $0`

java -jar $dir/jruby/jruby-complete-1.5.1.jar $dir/node_info_collector/node_info_collector.rb $@
