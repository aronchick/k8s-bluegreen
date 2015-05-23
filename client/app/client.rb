require 'sinatra/base'
require 'thin'
require 'json'
require './icons'

class ButtonColor
  def self.get
    "#6a1d8d" # Purple
    #{}"#172296" # Blue
    # "#397200" # Green
  end
end

class Constants
  def self.hostname
    %x(hostname -s).chomp
  end

  def self.icon
    AllIcons.getRand
  end

  def self.ip
    %x(hostname -I).strip
  end
end

class ClientApp < Sinatra::Base
  get '/' do
    erb :index, :locals => {:hostname => Constants.hostname, :icon => Constants.icon, :ip => Constants.ip }
  end

  get '/json' do
    content_type :json
      { :hostname => Constants.hostname, :icon => Constants.icon, :color => ButtonColor.get, :ip => Constants.ip }.to_json
  end

  get '/_status/healthz' do
    "OK"
  end

end
