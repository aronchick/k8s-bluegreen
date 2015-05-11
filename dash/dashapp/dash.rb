require 'eventmachine'
require 'sinatra/base'
require 'thin'
require 'em-http-request'
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
    if Constants.isLocal?
      'ws://localhost:8080'
    else
      'ws://" + location.hostname + "/ws'
    end
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

    @socket = nil

    def start_websockets(this_port)
      EM::WebSocket.start(:host => '0.0.0.0', :port => this_port) do |websocket|
        websocket.onopen do |handshake|
          puts "Client connected"
          @socket = websocket
        end

        websocket.onmessage do |msg|
          puts "Received Message: #{msg}"
          # @socket.send(msg)
        end

        websocket.onclose do
          websocket.send "Closed."
        end

        websocket.onerror { |e| puts "err #{e.inspect}" }
      end
    end

    @servers = []
    server_results = EM::Channel.new

    # define some defaults for our app
    server  = opts[:server] || 'thin'
    host    = opts[:host]   || '0.0.0.0'
    port    = opts[:port]   || '8181'
    web_app = opts[:app]

    dispatch = Rack::Builder.app do
      map '/' do
        run web_app
      end
    end

    # Start the web server. Note that you are free to run other tasks
    # within your EM instance.
    thin_continue = true
    port = 8181
    i = 0
    while (thin_continue)
      begin
        Rack::Server.start({
          app:    dispatch,
          server: server,
          Host:   host,
          Port:   (port + i),
          signals: false,
          })
      rescue Exception => ex
        if (ex.message == "no acceptor (port is in use or requires root privileges)") and (i < 5)
          i = i + 1
        elsif (i >= 5)
          thin_continue = false
        else
          raise ex
        end
      end
    end


    EM.defer do
      server_results.subscribe do |m|
        if (@socket) then
          @socket.send(JSON.generate(m))
        end
      end
    end

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

    puts "Server started on 0.0.0.0:8080 (drag index.html to your browser)"

    continue = true
    port = 8080
    i = 0
    while (continue)
      begin
        start_websockets(port + i)
      rescue Exception => ex
        if (ex.message == "no acceptor (port is in use or requires root privileges)") and (i < 5)
          i += 1
        elsif (i >= 5)
          continue = false
        else
          raise ex
        end
      end
    end
  end
end

# Our simple hello-world app
class DashApp < Sinatra::Base
  # threaded - False: Will take requests on the reactor thread
  #            True:  Will queue request for background thread
  configure do
    set :threaded, false
  end

  get '/' do
    erb :index, :locals => {:num_of_burst => Constants.get(:num_of_burst)}
  end

  # start the server if ruby file executed directly
  run! if app_file == $0
end

# run app: DashApp.new
