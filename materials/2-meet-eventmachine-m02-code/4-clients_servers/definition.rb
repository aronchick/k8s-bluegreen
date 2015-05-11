#!/usr/bin/env ruby

require 'rubygems'
require 'eventmachine'

class MyServer < EM::Connection
  attr_accessor :name

  def post_init
    send_data("hello")
  end

  def receive_data(data)
    send_data(name)
  end
end

module MyModServer
  def initialize(name)
    @name = name
  end

  def post_init
    send_data("goodbye #{@name}")
  end
end


EM.run do
  EM.start_server('0.0.0.0', 9000, MyServer) do |c|
    c.name = "dan"
  end

  EM.start_server('0.0.0.0', 9001, MyModServer, "dan")

  EM.start_server('0.0.0.0', 9002) do |conn|
    def conn.receive_data(data)
      send_data('hi again')
    end
  end
end