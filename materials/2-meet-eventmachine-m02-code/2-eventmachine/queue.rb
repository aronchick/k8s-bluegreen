#!/usr/bin/env ruby

require 'rubygems'
require 'eventmachine'

EM.run do
  q = EM::Queue.new

  q.push(:one, :two, :three)
  3.times { q.pop { |item| puts item } }

  EM.defer do
    q.push(1)
    sleep(1)
    q.push(2)
    sleep(1)
    q.push(3)
  end

  3.times { q.pop { |item| puts item }}
end