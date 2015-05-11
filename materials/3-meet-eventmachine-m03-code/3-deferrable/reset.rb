#!/usr/bin/env ruby

require 'rubygems'
require 'eventmachine'

class MyDef
  include EM::Deferrable

  def do_work(val)
    callback do
      puts "did work #{val}"
    end
  end

  def connect
    succeed
  end

  def reset
    set_deferred_status(nil)
  end
end

EM.run do
  md = MyDef.new
  md.do_work(1)
  md.do_work(2)

  EM.add_timer(2) do
    md.connect
    md.do_work(3)

    EM.add_timer(1) do
      md.reset
      md.do_work(4)

      EM.add_timer(1) do
        md.connect
        EM.stop
      end
    end
  end
end