#!/usr/bin/env ruby

require 'rubygems'
require 'eventmachine'

class DomainServer < EM::Connection
  def receive_data(data)
    puts data
  end
end

EM.run do
  EM.start_server('/tmp/server', nil, DomainServer)
  EM.start_unix_domain_server('/tmp/server2', nil, DomainServer)

  EM.connect_unix_domain('/tmp/server') do |c|
    c.send_data("Hello")
  end

  EM.connect_unix_domain('/tmp/server2') do |c|
    c.send_data("Hello2")
  end
end