#!/usr/bin/env ruby

require 'rubygems'
require 'eventmachine'

class UDPHandler < EM::Connection
  def receive_data(data)
    puts "Received #{data}"
  end
end

EM.run do
  EM.open_datagram_socket('0.0.0.0', 9000, UDPHandler)

  s = EM.open_datagram_socket('', nil)
  s.send_datagram("Hi", '0.0.0.0', 9000)
end