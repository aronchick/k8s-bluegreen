require 'eventmachine'
require 'em-http-request'
require 'sinatra/base'
require 'sinatra-websocket'
require 'em-websocket'
require 'nokogiri'
require 'json'
require './icons'
require 'byebug'

class Constants
  @_internalConstants =
    {
      :socket => nil,
      :num_of_burst => 20
    }

  def self.get(val)
    @_internalConstants[val]
  end

  def self.isLocal?
    ENV['_system_name'] == 'OSX'
  end

  def self.WS_Code
    'ws://" + location.hostname + ":" + location.port + "/ws'
  end
end

class GrabServer
  include EM::Deferrable

  def genHex
    rand(256).to_s(16).rjust(2, "0")
  end

  def get
    usr_agnt = "Mozilla/5.0 (Windows NT 6.3; Win64; x64)"
    hdrs = {"User-Agent"   => usr_agnt}
    hdrs["Accept-Charset"] = "utf-8"
    hdrs["Accept"]         = "text/html"

    my_html = ""

    req = nil


    if !ENV["HOSTNAME"].nil? and !ENV["HOSTNAME"].match(/aronchick/).nil?
      req = EM::HttpRequest.new("http://www.timeanddate.com/worldclock/usa/seattle").get()
      req.callback do
        doc = Nokogiri.parse(req.response)
        server_id = doc.css('#ct').inner_html.split(':')[2][0..1]
        server_color = "##{genHex}#{genHex}#{genHex}"
        server_icon = AllIcons.getRand
        server_ip = "256.256.256."+server_id

        self.succeed([server_id, server_color, server_icon, server_ip])

        req.errback { }
      end
    elsif !ENV["CLIENTS_PORT_80_TCP_ADDR"].nil?
      req = EM::HttpRequest.new("http://" + ENV["CLIENTS_PORT_80_TCP_ADDR"] + "/json").get()
      req.callback do
        data = JSON.parse(req.response)
        if(data) then
          self.succeed([data['hostname'], data['color'], data['icon'], data['ip']])
        end
      end
      req.errback { }
    else # We're on Kubernetes
      req = EM::HttpRequest.new("http://client/json").get()
      req.callback do
        data = JSON.parse(req.response)
        if(data) then
          self.succeed([data['hostname'], data['color'], data['icon'], data['ip']])
        end
        req.close
      end
      req.errback { self.fail }
    end

  end
end

class TestServer
  include EM::Deferrable

  def isAlive(server_ip)
    usr_agnt = "Mozilla/5.0 (Windows NT 6.3; Win64; x64)"
    hdrs = {"User-Agent"   => usr_agnt}
    hdrs["Accept-Charset"] = "utf-8"
    hdrs["Accept"]         = "text/html"

    my_html = ""

    req = nil
    req_url = "http://" + server_ip + "/"
    req = EM::HttpRequest.new(req_url, { :connect_timeout => 10, :inactivity_timeout => 1 }).head()
    req.callback do
      req.close
    end
    req.errback do
      # Only sweep 20% of the time for local testing
      ' ' if Constants.isLocal? and rand(10) < 8

      succeed(server_ip)
      req.close
    end
  end
end


def run(opts)

  # Start the reactor
  EM.run do



    EM.add_periodic_timer(5) do
      tg = GrabServer.new
      for i in 1..(Constants.get(:num_of_burst).to_i) do
        tg.get()
        tg.callback do | server_hostname, server_color, server_icon, server_ip |
          if (server_ip) then
            @servers << server_ip.to_s
          end
          server_results << { :type => 'update',
                              :server_hostname => server_hostname,
                              :server_color => server_color,
                              :server_icon => server_icon,
                              :server_ip => server_ip.to_s }
        end
      end
    end

    EM.add_periodic_timer(5) do
      @servers.each do | server |
        t = TestServer.new
        t.isAlive(server)
        t.callback do | server_ip |
          server_results << { :type => 'sweep',
                              :server_ip => server_ip }
          @servers.delete (server_ip)
        end
        t.errback { }
      end
    end
  end
end

# Our simple hello-world app
class DashApp < Sinatra::Application
  attr_reader :request_payload
  set :server,'thin'
  set :show_exceptions, true
  set :dump_errors, true
  set :root, File.dirname(__FILE__)

  @socket = nil
  @servers = []
  @server_results = EM::Channel.new

  def initialize
      super()
  end

  get '/' do
    erb :index, :locals => {:num_of_burst => Constants.get(:num_of_burst)}
  end

  WEBSOCKETS_BASE = '/ws'
  set :sockets, []

  get "#{WEBSOCKETS_BASE}" do
    if !request.websocket?
      halt 500, json({message: "This end point must be for ws:// "})
    else
      request.websocket do |ws|
        ws.onopen do
          settings.sockets << ws
          puts "Connected to #{request.path}."
          ws.send "Connected to server at #{request.path}."
        end
        ws.onmessage do |msg|
          puts "Received Message: #{msg}"
          settings.sockets.each do |socket|
            puts "Sending #{msg}"
            socket.send "Server replies: #{msg}"
          end
        end
        ws.onclose do
          warn("websocket closed")
          settings.sockets.delete(ws)
          puts "Client closed"
          ws.send "Closed."
          settings.sockets.delete ws
        end
      end
    end

    EM.defer do
      server_results.subscribe do |m|
        settings.sockets.each do | socket |
          socket.send(JSON.generate(m))
        end
      end
    end

  end

  # get '/ws' do
  #   if !request.websocket?
  #     halt 500, json({message: "This end point must be for ws:// "})
  #   else
  #     byebug
  #     request.websocket do |ws|
  #       ws.onopen do |handshake|
  #         puts "Client connected"
  #         @socket = ws
  #       end
  #
  #       ws.onmessage do |msg|
  #         puts "Received Message: #{msg}"
  #         # @socket.send(msg)
  #       end
  #
  #       ws.onclose do
  #         ws.send "Closed."
  #       end
  #
  #       ws.onerror { |e| puts "err #{e.inspect}" }
  #     end
  #   end
  # end
end

DashApp.run! if $0 == "dash.rb"

# class WebSocketApp < Rack::Websocket::Application
#   def initialize(options = {})
#     super
#
#     @socket_mount_point = '/ws'
#   end
#
#
# 	def on_open(env)
# 		# Protect against connections to invalid mount points.
# 		if env['REQUEST_PATH'] != @socket_mount_point
# 			close_websocket
# 			puts "Closed attempted websocket connection because it's requested a mount point other than #{@socket_mount_point}"
# 		end
#
# 		puts "Client Connected"
#
# 		# Send a welcome message to the user over websockets.
# 		send_data "<span class='server'> @client Hello Client! </span>"
# 		puts "Sent message: @client Hello Client!"
#
#                 # Uncomment below for an example of routinely broadcasting to the client.
#                 #EM.next_tick do
# 		#	# The "1" here specifies interval in seconds.
#                 #        EventMachine::PeriodicTimer.new(1) do
#                 #                send_data "<span class='server'> @client tick tock </span>"
#                 #        end
#                 #end
# 	end
#
# 	def on_close(env)
# 		puts "Client Disconnected"
# 	end
#
# 	def on_message(env, message)
# 		puts "Received message: #{message}"
#
# 		send_data "<span class='server'> @client I received your message: #{message} </span>"
# 	end
#
# 	def on_error(env, error)
# 		puts "Error occured: " + error.message
# 	end
# end
