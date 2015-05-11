#!/usr/bin/env ruby

# Requires Ruby 1.9.2
#
# gem install goliath

require 'rubygems'

require 'goliath'
require 'em-synchrony/em-http'

class Get < Goliath::API
  use Goliath::Rack::Params

  def response(env)
    ret = EM::HttpRequest.new(env.params['url']).get

    [200, {:status => ret.response_header.status.to_s}, ret.response]
  end
end
