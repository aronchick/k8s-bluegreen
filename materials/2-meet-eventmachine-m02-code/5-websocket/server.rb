#!/usr/bin/env ruby

# Automatically bundle gems locally with Isolate
$: << "./lib/isolate-3.1.0.pre.3/lib"
require 'rubygems'
#require 'rubygems/user_interaction' # Required with some older RubyGems
require 'isolate/now'

require 'eventmachine'
require 'em-websocket'
require 'em-http'
require 'nokogiri'
require 'json'
require 'pp'

class GeoCode
  include EM::Deferrable

  def query(postal_code)
    query = {
      :postal => postal_code,
      :geoit => :xml
    }
    req = EM::HttpRequest.new('http://geocoder.ca/').get(:query => query)
    req.callback do
      doc = Nokogiri.parse(req.response)
      lat = doc.search('latt').inner_text
      long = doc.search('longt').inner_text

      succeed(lat, long)
    end
    req.errback { fail }
  end
end

# http://gowalla.com/api/explorer#/spots?lat=30.2697&lng=-97.7494&radius=50
class Gowalla
  include EM::Deferrable

  def query(lat, long)
    gowalla_query = {
      :lat => lat,
      :lng => long,
      :radius => 10000
    }
    gowalla = EM::HttpRequest.new('http://api.gowalla.com/spots').get(:query => gowalla_query,
                                                                      :timeout => 20,
                                                                      :head => {:accept => 'application/json'})
    gowalla.callback do
      long_operation = Proc.new do
        locations = []

        data = JSON.parse(gowalla.response)
        data['spots'].each do |spot|
          locations << {:type => 'gowalla',
                        :name => spot['name'],
                        :lat => spot['lat'],
                        :lng => spot['lng']}
        end
        locations
      end

      parse_callback = Proc.new { |locations| succeed(locations) }

      EM.defer(long_operation, parse_callback)
    end

    gowalla.errback do
      puts "Gowalla Query Failed"
      fail('Gowalla')
    end
  end
end

# http://developer.foursquare.com/docs/venues/search.html
class FourSquare
  include EM::Deferrable

  def query(lat, long)
    four_sq_query = {
      :ll => "#{lat},#{long}",
      :limit => 50,
      :intent => :checkin,
      :client_id => 'UKPXGFNLVLSH2HDXBCJ5TZQY0PNTNTZARBWGVO4XZM3Q3WA0',
      :client_secret => 'JP3Q2OIMBILSOHU0VANN3FA5K1RP1UJFEPPR2O4PAWHC401G'
    }
    four_sq = EM::HttpRequest.new('https://api.foursquare.com/v2/venues/search').get(
                      :query => four_sq_query)
    four_sq.callback do
      locations = []

      data = JSON.parse(four_sq.response)['response']['groups'].first
      data['items'].each do |item|
        locations << {:type => 'foursquare',
                      :name => item['name'],
                      :lat => item['location']['lat'],
                      :lng => item['location']['lng']}
      end
      succeed(locations)
    end

    four_sq.errback do
      puts "Foursquare Query Failed"
      fail('FourSquare')
    end
  end
end

# http://developers.facebook.com/docs/reference/api/checkin/
class FaceBook
  include EM::Deferrable

  def query(lat, long)
    facebook_access_query = {
      :client_id => 156713821042399,
      :client_secret => 'acf0a9dd669e3c4f42cc8f12221a0163',
      :grant_type => 'client_credentials'
    }
    faq = EM::HttpRequest.new('https://graph.facebook.com/oauth/access_token').get(
                  :query => facebook_access_query)
    faq.callback do
      token = faq.response.match(/access_token=(.*)$/)[1]

      facebook_query = {
        :type => :place,
        :center => "#{lat},#{long}",
        :distance => 10000,
        :access_token => token
      }
      facebook = EM::HttpRequest.new('https://graph.facebook.com/search').get(:query => facebook_query)
      facebook.callback do
        locations = []

        data = JSON.parse(facebook.response)['data']
        data.each do |item|
          locations << {:type => 'facebook',
                        :name => item['name'],
                        :lat => item['location']['latitude'],
                        :lng => item['location']['longitude']}
        end
        succeed(locations)
      end

      facebook.errback do
        puts "Facebook Query Failed"
        fail("FaceBook")
      end
    end

    faq.errback do
      puts "Facebook access token request failed."
      fail("FaceBook")
    end
  end
end

EM.run do
  puts "Server started on 0.0.0.0:8080 (drag index.html to your browser)"
  EM::WebSocket.start(:host => '0.0.0.0', :port => 8080) do |websocket|
    websocket.onopen { puts "Client connected" }

    websocket.onmessage do |msg|
      geocode = GeoCode.new
      geocode.query(msg)
      geocode.callback do |lat, long|
        websocket.send({:type => 'location', :lat => lat, :lng => long}.to_json)

        query_callback = Proc.new { |locations| locations.each { |location| websocket.send(location.to_json) } }
        error_callback = Proc.new { |type| websocket.send({:error => "#{type} call failed."}.to_json) }

        [Gowalla, FourSquare, FaceBook].each do |klass|
          g = klass.new
          g.query(lat, long)
          g.callback &query_callback
          g.errback &error_callback
        end
      end

      geocode.errback do
        puts "Failed on geocode"
        websocket.send({:error => "Geocode call failed."}.to_json)
      end
    end

    websocket.onclose { puts "closed" }
    websocket.onerror { |e| puts "err #{e.inspect}" }
  end
end
