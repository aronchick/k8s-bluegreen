#!/usr/bin/env ruby

require 'rubygems'
require 'eventmachine'

EM.run do
  EM.add_timer(5) do
    puts "BOOM"
    EM.stop
  end

  EM.add_periodic_timer(1) do
    puts "Tick"
  end
end