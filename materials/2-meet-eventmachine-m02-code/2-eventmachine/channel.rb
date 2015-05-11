#!/usr/bin/env ruby

require 'rubygems'
require 'eventmachine'

EM.run do
  c = EM::Channel.new

  EM.defer do
    c.subscribe { |m| puts "1: #{m}" }
    sleep(3)
    c << "Defer 1"
  end

  EM.defer do
    sid = c.subscribe { |m| puts "2: #{m}" }
    sleep(2)
    c.unsubscribe(sid)
  end

  EM.add_periodic_timer(1) do
    c << "Hello"
  end
end
