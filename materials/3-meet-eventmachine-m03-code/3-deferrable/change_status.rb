#!/usr/bin/env ruby

require 'rubygems'
require 'eventmachine'

EM.run do
  df = EM::DefaultDeferrable.new

  df.callback do
    puts "First callback"
    df.succeed("dan", "screencast")
  end
  df.callback do |name, type|
    puts "#{name} made a PeepCode #{type}"
    df.set_deferred_status :succeeded
  end
  df.callback { EM.stop }

  EM.add_timer(2) do
    df.succeed
  end
end