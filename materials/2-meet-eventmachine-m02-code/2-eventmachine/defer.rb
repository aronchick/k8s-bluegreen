#!/usr/bin/env ruby

require 'rubygems'
require 'eventmachine'

EM.run do
  EM.defer do
    puts "I'm on a thread"
    sleep(2)
    puts "First sleepy"
  end

  EM.defer do
    puts "a cool thread"
    sleep(1)
    puts "second sleepy"
  end

  op = Proc.new { puts "OPERATION"; [1, 2] }
  cb = Proc.new { |first, second| puts "CALLBACK #{first} #{second}"}

  EM.defer(op, cb)
end
