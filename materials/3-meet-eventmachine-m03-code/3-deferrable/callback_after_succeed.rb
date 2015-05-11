#!/usr/bin/env ruby

require 'rubygems'
require 'eventmachine'

EM.run do
  df = EM::DefaultDeferrable.new
  df.callback { puts "Succeeded" }

  EM.add_timer(2) do
    df.succeed

    EM.add_timer(1) do
      df.callback do
        puts "Done"
        EM.stop
      end
    end
  end
end