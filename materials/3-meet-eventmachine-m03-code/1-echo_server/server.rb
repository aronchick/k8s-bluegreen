#!/usr/bin/env ruby

require 'rubygems'
require 'eventmachine'

class EchoServer < EM::Connection
  def post_init
    puts "client connecting"
  end

  def unbind
    puts "client disconnected"
  end

  def receive_data(data)
    puts "received #{data} from client"
    send_data ">> #{data}"
  end
end

EM.run do
  EM.start_server('0.0.0.0', 9000, EchoServer)
  puts "Server running on port 9000"
end

