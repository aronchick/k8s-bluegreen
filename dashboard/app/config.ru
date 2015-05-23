# config.ru
require './dashboard'
require 'rubygems'
require 'thin'
require 'sinatra'
# require File.expand_path '../dash.rb', __FILE__

run DashboardApp.new
