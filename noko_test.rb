#
# noko_cut_attach.rb
# 

require "rubygems"
require "open-uri"
require "nokogiri"

usr_agnt = "Mozilla/5.0 (Windows NT 6.3; Win64; x64)"
hdrs = {"User-Agent"   => usr_agnt}
hdrs["Accept-Charset"] = "utf-8"
hdrs["Accept"]         = "text/html"

my_html = ""

open("http://www.timeanddate.com/worldclock/usa/seattle", hdrs).each {|s| my_html << s}

doc = Nokogiri::HTML(my_html)
noko_enum = doc.css("#ct")