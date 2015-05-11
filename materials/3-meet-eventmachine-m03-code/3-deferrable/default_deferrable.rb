#!/usr/bin/env ruby

require 'rubygems'
require 'eventmachine'

EM.run do
  df = EM::DefaultDeferrable.new
  df.callback do |name|
    puts "Hello #{name}"
    EM.stop
  end
  df.errback { puts "Error" }

  EM.add_timer(2) { df.succeed "Dan" }
end