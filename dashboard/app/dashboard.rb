require 'sinatra/base'
require 'sinatra-websocket'
require 'celluloid'
require 'celluloid/autostart'
require 'celluloid/io'
require 'http'
require 'json'
require './icons'
require 'byebug'
require 'set'

module Errors
  class NoWebResponse < StandardError; end
end

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
    if (Constants.isLocal?)
      'ws://" + location.hostname + ":" + location.port + "/ws'
    else
      'ws://" + location.hostname + "/ws'
    end
  end

  def self.genHex
      rand(256).to_s(16).rjust(2, "0")
  end
end

class HttpFetcher
  include Celluloid::IO

  def self.getPool
    Celluloid::Actor[:fetcher_pool] ||= HttpFetcher.pool(size: 50)
  end

  def scan(type, url, postProcessMethod, publishMethod, options = {} )
    # puts "Request -> http://#{url}"
    begin
      response = HTTP.get("http://" + url)
      send(postProcessMethod, {:type => type, :data => response}, publishMethod)
    rescue HTTP::TimeoutError,Errno::ECONNREFUSED, Errno::EHOSTUNREACH, Timeout::Error, Timeout::ExitException => e
      puts "Rescuing => #{e}"
      send(postProcessMethod, {:type => type, :data => nil}, publishMethod)
    rescue Exception => e
      puts e
    end
  end

  def test(server_ip, publishMethod)
    s = nil
    begin
        Timeout::timeout(1) do
          s = TCPSocket.new(server_ip, 80)
        end
    rescue
      publishMethod.call({
                            :type => "sweep",
                            :server_ip => server_ip
                           })
    ensure
      s.close if !s.nil?
    end
  end

  def processMockResponse (response, publishMethod)
    # puts "Processing Mock => #{response}"
    return if response.nil? or response[:data].nil?
    data = JSON.parse(response[:data])
    return if data.nil?
    publishMethod.call({
                          :type => "update",
                          :server_hostname => rand(25),
                          :server_color => "##{Constants.genHex}#{Constants.genHex}#{Constants.genHex}",
                          :server_icon => AllIcons.getRand,
                          :server_ip => "127.0.0.1"
                        })
  end

  def processContainerResponse (response, publishMethod)
    return if response[:data].nil?
    data = JSON.parse(response[:data])
    return if data.nil?
    publishMethod.call({
                          :type => "update",
                          :server_hostname => data['hostname'],
                          :server_color => data['color'],
                          :server_icon => data['icon'],
                          :server_ip => data['ip']
                         })
  end
end

class GrabServer
  include Celluloid
  include Celluloid::Notifications

  def scan

    url = '127.0.0.1:3100/json'
    url ||= ENV["CLIENTS_PORT_80_TCP_ADDR"]
    url = "client/json" if File.exist?("/etc/container_environment/KUBE_DNS_PORT_53_UDP_ADDR")

    postProcessMethod = Constants.isLocal? ?
                            :processMockResponse :
                            :processContainerResponse
    for i in 1..2 do
      HttpFetcher.getPool.async.scan(:update, url, postProcessMethod, method(:publishMethod))
    end
  end

  def publishMethod(update_message)
    publish "update_server", update_message
  end

end

class SweepServer
  include Celluloid
  include Celluloid::Notifications

  def sweep(servers)
   servers.each do | server_ip |
      req_url = "http://" + server_ip + "/"

      HttpFetcher.getPool.async.test(server_ip, method(:publishMethod))
    end
  end

  def publishMethod(sweep_message)
    publish "sweep_server", sweep_message
  end

end

# Our simple hello-world app
class DashboardApp < Sinatra::Application
  include Celluloid
  include Celluloid::Notifications
  include Celluloid::Logger

  attr_reader :request_payload
  set :server,'thin'
  set :show_exceptions, true
  set :dump_errors, true
  set :root, File.dirname(__FILE__)
  set :threaded, false

  def initialize
    super()
    info "Subscribing to topics."
    subscribe 'update_server', :update_server
    subscribe 'sweep_server', :sweep_server
    Celluloid::Actor[:grab_server] = GrabServer.new
    Celluloid::Actor[:sweep_server] = SweepServer.new
    @updates_to_push = []
    @socket = nil
  end

  def update_server(topic,data)
    # puts "Received Data => #{data}"
    @updates_to_push.push(data)
    # puts "Updates: " + @updates_to_push.to_json
  end

  def sweep_server(topic,data)
    @updates_to_push.push(data)
  end

  def push_data
    # byebug if (@updates_to_push.length > 10)
    if(@socket) then
      @socket.send(@updates_to_push.to_json)
      @updates_to_push.clear
    end
  end

  get '/' do
    erb :index, :locals => {:num_of_burst => Constants.get(:num_of_burst)}
  end

  get '/_status/healthz' do
    "OK"
  end

  WEBSOCKETS_BASE = '/ws'

  get "#{WEBSOCKETS_BASE}" do
    if !request.websocket?
      halt 500, json({message: "This end point must be for ws:// "})
    else
      request.websocket do |ws|
        ws.onopen do
          @socket = ws
          puts "Connected to #{request.path}."
          ws.send "Connected to server at #{request.path}."
          every(0.1) { Celluloid::Actor[:grab_server].scan }
          every(1) { push_data }
        end
        ws.onmessage do |msg|
          # puts "Received Message: #{msg}"
          servers = Set.new
          msg.split(/,/).each { | server_ip | servers.add(server_ip) }
          # puts "sweeping #{servers.length} servers"
          Celluloid::Actor[:sweep_server].sweep(servers)
          # @socket.send "Server replies: #{msg}"
        end
        ws.onclose do
          warn("websocket closed")
          @socket = nil
          puts "Client closed"
          ws.send "Closed."
        end
      end
    end
  end
end
