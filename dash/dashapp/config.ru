# config.ru
require './dash'
require 'rubygems'
require 'thin'
require 'sinatra'
require File.expand_path '../dash.rb', __FILE__

run DashApp.new

# # Set service point for the websockets. This way we can run both web sockets and sinatra on the same server and port number.
# map '/ws' do
# 	run WebSocketApp
# end
#
# # This delegates everything other route not defined above to the Sinatra app.
# map '/' do
# 	run DashApp
# end
