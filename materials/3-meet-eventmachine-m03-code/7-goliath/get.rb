#!/usr/bin/env ruby

# Requires Ruby 1.9.2
#
# gem install goliath

# Automatically bundle gems locally with Isolate
$: << "./lib/isolate-3.1.0.pre.3/lib"
require 'rubygems'
#require 'rubygems/user_interaction' # Required with some older RubyGems
require 'isolate/now'

require 'goliath'
require 'em-synchrony/em-http'

class Get < Goliath::API
  use Goliath::Rack::Params

  def response(env)
    ret = EM::HttpRequest.new(env.params['url']).get

    [200, {:status => ret.response_header.status.to_s}, ret.response]
  end
end
