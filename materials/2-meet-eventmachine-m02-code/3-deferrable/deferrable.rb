#!/usr/bin/env ruby

require 'rubygems'
require 'eventmachine'

class MyDef
  include EM::Deferrable

  def my_function(succeed)
    if succeed
      set_deferred_status :succeeded
    else
      set_deferred_status :failed
    end
    EM.stop
  end
end

EM.run do
  md1 = MyDef.new
  md1.callback { puts "MD1 Succeeded" }
  md1.errback { puts "MD1 Failed" }

  md2 = MyDef.new
  md2.callback { puts "MD2 Succeeded" }
  md2.errback { puts "MD2 Failed" }

  EM.add_timer(2) do
    md1.my_function(true)
    md2.my_function(false)
  end
end